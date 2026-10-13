#!/usr/bin/env bash
# Copy every secret in a flow vault into another secret store, and make the destination a flow
# vault holding the same names, so executables keep working by switching the current vault.
#
# Values never touch argv or a shell variable: each one streams from `flow secret get` into the
# target, and is checked by comparing SHA-256 hashes of the old and new reads through flow.
#
# Env (set by the flow executable):
#   TARGET     op | aws-ssm | flow
#   FROM       source flow vault (default: main)
#   TO         destination flow vault name to create or reuse
#   OP_VAULT   1Password vault for op (default: flow)
#   OP_ACCOUNT 1Password account shorthand or sign-in address for op (optional)
#   SSM_PREFIX parameter path prefix for aws-ssm (default: /flow)
#   ONLY       comma-separated names to migrate (default: all)
#   APPLY      true to make changes; anything else is a dry run
#   SWITCH     true to make TO the current vault once every secret verifies
set -euo pipefail

TARGET="${TARGET:?TARGET is required: op, aws-ssm, or flow}"
FROM="${FROM:-main}"
TO="${TO:?TO is required: the destination vault name}"
OP_VAULT="${OP_VAULT:-flow}"
SSM_PREFIX="${SSM_PREFIX:-/flow}"
APPLY="${APPLY:-false}"
SWITCH="${SWITCH:-false}"

log() { printf '%s\n' "$*" >&2; }
die() { log "error: $*"; exit 1; }
need() { command -v "$1" > /dev/null || die "$1 is required for this target"; }
dry() { [ "$APPLY" != "true" ]; }

need flow
need jq
case "$TARGET" in
  op) need op ;;
  aws-ssm) need aws ;;
  flow) ;;
  *) die "unknown TARGET '$TARGET' (op, aws-ssm, flow)" ;;
esac
[ "$FROM" != "$TO" ] || die "FROM and TO must differ"

STAGE_DIR="$(mktemp -d)"
chmod 700 "$STAGE_DIR"
trap 'rm -rf "$STAGE_DIR"' EXIT

hash_cmd() { if command -v sha256sum > /dev/null; then sha256sum; else shasum -a 256; fi; }

# Stream a secret's exact value to stdout. jq -j writes no trailing newline of its own.
read_value() { flow secret get "$1" --vault "$2" --plaintext --output json | jq -j '.result.data.value'; }
value_hash() { read_value "$1" "$2" | hash_cmd | cut -d' ' -f1; }

vault_exists() { flow vault get "$1" > /dev/null 2>&1; }

reference_for() {
  case "$TARGET" in
    op) printf 'op://%s/%s/credential' "$OP_VAULT" "$1" ;;
    aws-ssm) printf '%s/%s' "$SSM_PREFIX" "$1" ;;
    flow) printf '%s' "$1" ;;
  esac
}

target_has() {
  case "$TARGET" in
    op) op item get "$1" --vault "$OP_VAULT" > /dev/null 2>&1 ;;
    aws-ssm) aws ssm get-parameter --name "$(reference_for "$1")" > /dev/null 2>&1 ;;
    flow) flow secret get "$1" --vault "$TO" > /dev/null 2>&1 ;;
  esac
}

write_secret() {
  local name="$1"
  case "$TARGET" in
    op)
      read_value "$name" "$FROM" \
        | jq -Rs --arg t "$name" \
          '{title: $t, category: "API_CREDENTIAL",
            fields: [{id: "credential", type: "CONCEALED", label: "credential", value: .}]}' \
        | op item create --vault "$OP_VAULT" - > /dev/null
      ;;
    aws-ssm)
      read_value "$name" "$FROM" \
        | jq -Rs --arg n "$(reference_for "$name")" \
          '{Name: $n, Value: ., Type: "SecureString", Overwrite: false}' \
        | AWS_PAGER="" aws ssm put-parameter --cli-input-json file:///dev/stdin > /dev/null
      ;;
    flow)
      # flow rejects /dev/stdin as a --file path, so stage the value in a private temp file
      local tmp rc=0
      tmp="$(mktemp "$STAGE_DIR/value.XXXXXX")"
      read_value "$name" "$FROM" > "$tmp" && flow secret set "$name" --file "$tmp" --vault "$TO" > /dev/null || rc=$?
      rm -f "$tmp"
      return "$rc"
      ;;
  esac
}

# External vault config that reads back through the provider's CLI (matches flowexec/vault examples)
external_config() {
  case "$TARGET" in
    op)
      jq -n --arg id "$TO" --arg acct "${OP_ACCOUNT:-}" '{
        id: $id, type: "external",
        external: {
          get: {cmd: "op read --no-newline '\''{{ref}}'\''"},
          metadata: {cmd: "op account list"},
          reference_pattern: "^op://[^/]+/[^/]+/[^/]+(/[^/]+)?$",
          not_found_pattern: "isn'\''t an item",
          timeout: "120s"
        }
      } | if $acct != "" then .external.environment = {OP_ACCOUNT: $acct} else . end'
      ;;
    aws-ssm)
      jq -n --arg id "$TO" '{
        id: $id, type: "external",
        external: {
          get: {cmd: "aws ssm get-parameter --name '\''{{ref}}'\'' --with-decryption --query Parameter.Value --output text"},
          metadata: {cmd: "aws sts get-caller-identity --output json"},
          reference_pattern: "^/[A-Za-z0-9._/-]+$",
          not_found_pattern: "ParameterNotFound",
          environment: {AWS_PAGER: ""},
          timeout: "60s"
        }
      }'
      ;;
  esac
}

ensure_destination_vault() {
  if vault_exists "$TO"; then
    log "destination vault '$TO' exists; reusing it"
    return
  fi
  if dry; then
    log "[dry-run] would create vault '$TO' ($TARGET)"
    return
  fi
  if [ "$TARGET" = "flow" ]; then
    die "TARGET=flow needs an existing vault '$TO' (create it with: flow vault create $TO)"
  fi
  local cfg
  cfg="$(mktemp)"
  external_config > "$cfg"
  flow vault create "$TO" --type external --config "$cfg" > /dev/null
  rm -f "$cfg"
  log "created external vault '$TO'"
}

names() {
  if [ -n "${ONLY:-}" ]; then
    tr ',' '\n' <<< "$ONLY" | sed '/^$/d'
  else
    flow secret list --vault "$FROM" --output json | jq -r '(.secrets // .)[].key'
  fi
}

case "$TARGET" in
  op) log "target: 1Password vault '$OP_VAULT'${OP_ACCOUNT:+ (account $OP_ACCOUNT)}" ;;
  aws-ssm) log "target: AWS SSM under $SSM_PREFIX ($(aws configure get region 2>/dev/null || echo default region))" ;;
  flow) log "target: flow vault '$TO'" ;;
esac
dry && log "dry run: nothing will be written (rerun with apply=true)"

ensure_destination_vault

total=0 migrated=0 skipped=0 verified=0 failed=0
failures=()
while IFS= read -r name; do
  total=$((total + 1))
  ref="$(reference_for "$name")"

  if dry; then
    if target_has "$name" 2> /dev/null; then
      log "  $name -> $ref (already in target; would link and verify)"
    else
      log "  $name -> $ref"
    fi
    continue
  fi

  if target_has "$name"; then
    skipped=$((skipped + 1))
  elif write_secret "$name"; then
    migrated=$((migrated + 1))
  else
    failed=$((failed + 1)); failures+=("$name (write)"); log "  ✗ $name: write failed"; continue
  fi

  if [ "$TARGET" != "flow" ]; then
    flow secret unlink "$name" --vault "$TO" > /dev/null 2>&1 || true
    if ! flow secret link "$name" "$ref" --vault "$TO" > /dev/null; then
      failed=$((failed + 1)); failures+=("$name (link)"); log "  ✗ $name: link failed"; continue
    fi
  fi

  if [ "$(value_hash "$name" "$FROM")" = "$(value_hash "$name" "$TO")" ]; then
    verified=$((verified + 1)); log "  ✓ $name"
  else
    failed=$((failed + 1)); failures+=("$name (verify)"); log "  ✗ $name: value in '$TO' does not match '$FROM'"
  fi
done < <(names)

log ""
if dry; then
  log "$total secret(s) would be migrated from '$FROM' to '$TO'"
  exit 0
fi
log "$total total: $migrated written, $skipped already present, $verified verified, $failed failed"
if [ "$failed" -gt 0 ]; then
  printf '  %s\n' "${failures[@]}" >&2
  log "'$FROM' is unchanged and is still the source of truth; fix the failures and rerun"
  exit 1
fi

if [ "$SWITCH" = "true" ]; then
  flow vault switch "$TO" > /dev/null
  log "current vault is now '$TO'. Executables using bare secret names now read from it."
else
  log "all secrets verified. Switch when ready: flow vault switch $TO"
fi

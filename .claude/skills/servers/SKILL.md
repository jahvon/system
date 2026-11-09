---
name: servers
description: Connect to and operate Jahvon's remote machines (devbox, also called server01, and workbox) and the home network through the `system` flow workspace — SSH access, shells, remote commands, health checks, Tailscale, and network drift. Use whenever the user mentions a server, node, devbox, workbox, server01, SSH, Tailscale, or home network state, or asks to run something on a remote machine, even if they don't mention flow or the registry.
allowed-tools: mcp__flow__execute, mcp__flow__get_executable, mcp__flow__list_executables, mcp__flow__get_execution_logs, Bash(flow:*), Read
---

# Servers

`tools/servers/inventory.yaml` in the `system` workspace is the source of truth for machines,
clusters, and the network. Change facts there, then run `flow apply server:ssh-config`.

Outside the system repo, qualify refs as `system/…` (`flow show system/server:list`).

| Goal | Run |
|------|-----|
| See every machine | `flow show server:list`, or `show server:inventory` for JSON |
| Check a server's health | `flow check server:status devbox` |
| Run a command on a server | `flow run server:command devbox 'uname -a'` |
| Open a shell (humans) | `flow connect server:shell devbox` |
| One-click equivalents | `flow check devbox:status`, `flow connect devbox:shell`, same for `workbox` |
| Pull the latest repos and workspaces | `flow update server:repos devbox`; see the `fresh-repos` skill |
| Open the Ubuntu desktop | `flow open devbox:desktop` |
| Persistent Claude on a server | `flow start devbox:claude`, `flow show devbox:claude`, `flow connect devbox:claude`; `install`/`stop server:claude <server>` |
| Compare registry with reality | `flow check network:drift` |
| Pi-hole stats, pause, blocklists | `flow get pihole:summary`, `flow pause pihole:blocking 60`, `flow update pihole:gravity` |
| Update Pi-hole or its settings | Edit `tools/pihole/docker-compose.yml`, then `flow apply pihole:config` |

Use `k3s:` executables in the `kube` workspace for k3s node work, not `run server:command`.

## Steps only the user can do

These need a password or browser, so running them as an agent prints the command instead of
opening a window. Hand it to the user:

- `flow install server:ssh-access <server>`: key login, using a key held in 1Password.
- `flow install server:sudoers <server>`: passwordless sudo for routine k3s commands only.
- `flow install network:tailscale <server>`: install Tailscale and apply registry settings.
- `flow install server:ssh-hardening <server>`: SSH keys only, with an automatic rollback if the test fails.
- `flow install server:desktop <server>`: Desktop Sharing and the RDP login.
- Creating a 1Password service account token for `flow install server:secrets <server>`. It only reaches the server if creation succeeds, and never appears in a terminal or transcript: `T=$(op service-account create "<server>" --vault flow:read_items --account my.1password.com --raw) && printf '%s' "$T" | ssh <server> 'umask 077; cat > ~/.config/op/service-account-token'; unset T`. Never print or read that token.

## Things to know

- Pi-hole runs in Docker on devbox, outside k3s, and must stay in `ALL` listening mode to answer tailnet clients. Tailscale runs on the hosts, so remote access
  survives a k3s failure.
- SSH prompts through the 1Password agent. If a run fails with `Permission denied`, 1Password may
  be locked or waiting for approval.
- Never accept a changed host key on the user's behalf.
- `ufw` is off on the k3s nodes. Don't enable it casually: its default-deny can break k3s networking, and rules left over from earlier setup would take effect. The home router has no port forwarding, so services are reachable from the LAN and tailnet, not the internet.
- The desktop is GNOME Desktop Sharing in `extend` mode, because devbox has no monitor. Use FreeRDP, not Windows App, which hangs after login against libfreerdp 3.32.1 (FreeRDP#13845). Keep Remote Login off.
- Never put a password in a `sudo` command's arguments, because sudo logs full command lines. Pass it over stdin to `sudo sh -c 'IFS= read -r p; ...'`, as `bin/desktop-setup.sh` does for `grdctl`.
- In Mochi, or through MCP on flow without the `fix/mcp-agent-ergonomics` changes, arguments split
  on spaces. Pass flag args after `--`, and run multi-word remote commands from the CLI. Failed runs
  may also report `isError: false`, so confirm with `get_execution_logs`.
- Claude sessions are systemd user services (`claude-<workspace>.service`) running tmux with Remote Control on, in the `checkout` the registry names. They start at boot, and Claude restarts if it exits. `flow install server:claude` also pre-trusts every repo under `~/workspaces`, approves the flow MCP server (on servers without mochi; with mochi, agent-framework uses mochi's server instead), and updates agent-framework. Remote Control needs a full `/login`. Never answer a session's trust or permission prompts on the user's behalf. To drive one non-interactively, run `claude -p -c` in its checkout. These sessions deny `run_command`, `run_python`, and `run_executable` from both flow and mochi; use `execute` with a defined executable.
- `flow check server:status` saves its result to flow's data store as `server.<name>.status`.

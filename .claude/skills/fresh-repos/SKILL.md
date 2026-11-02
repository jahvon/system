---
name: fresh-repos
description: Pull the latest repos and flow workspaces before working on a server. Use at the start of any task on devbox, server01, or workbox, including long-running or Remote Control sessions, before reading, running, editing, or deploying from a repo there, and whenever a checkout might be out of date or a change made on another machine is missing.
---

# Start from fresh repos

Sessions on servers run for days, while commits usually land from other machines. A stale checkout
means deploying old config or editing code that has already changed. Sync first:

```sh
flow update system/server:repos
```

From the Mac, target a server with `flow update server:repos devbox`.

It fast-forwards every repo under `~/workspaces` and refreshes flow's git workspaces.

## Reading the result

- `[OK]`: current, or pulled.
- `[SKIP]`: local changes, or not on the default branch. It leaves these alone. If that repo is the
  one you need, look at what's there and tell the user before working from it.
- `[FAIL]`: a fetch failed or the repo has diverged. Report it. Don't reset, stash, or discard
  anything to get past it, because those changes may be someone's unfinished work.

## Things to know

- `kube` and `agent-framework` are registered with flow from its cache
  (`~/.cache/flow/git-workspaces/`), so `flow` executables run from there. Plain clones under
  `~/workspaces` are separate copies, and sessions often run in those. The sync updates both.
- A pull doesn't change a running session's loaded skills or settings. If those changed, say a
  restart is needed: `flow start devbox:claude`.
- Sync again before a deploy if the session has been open for a while.

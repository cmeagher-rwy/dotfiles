# opendesign

## Known issue: `git fetch` / `git pull` is very slow

`~/.opendesign` has a huge git history (the repo tracks large binary assets, so the clone and `.git` directory reach multiple GB). A `git fetch` downloads and indexes ~80k objects and can take several minutes — far longer than the other git repos this setup touches (e.g. superpowers).

Symptoms:

- `./update.sh --dry-run` appeared to hang at the "Updating OpenDesign..." step. Cause: `update.sh` ran `git fetch origin` inside its `is_repo_behind` check even in `--dry-run` mode, and that fetch is slow on this repo.
- A normal `git pull` takes minutes to start doing anything visible.

### Fixes applied (in `update.sh` / `install.sh`)

- `is_repo_behind` is now gated on `DRY_RUN` — `--dry-run` previews the update commands without touching the network.
- `update_opendesign` uses `git pull --ff-only` instead of `git pull` to avoid accidental merge commits.

## Prune the git repo

Interrupted or repeated pulls leave stale "garbage" packs behind (at one point `~/.opendesign/.git` held ~2.3 GiB of garbage). To reclaim the space:

```bash
git -C ~/.opendesign gc --prune=now
```

Before: `.git` was 4.1 GiB. After: ~1.7 GiB.

Run this after a few slow or interrupted updates, or whenever `.git` looks unusually large:

```bash
du -sh ~/.opendesign/.git
```

`git pull` can also run maintenance automatically — `git maintenance start` in the repo enables incremental gc, but the manual `git gc --prune=now` above is the safe one-off.

## Installation and updates

Full setup and manual update steps live in `linux/README.md`:

- Install: the `OpenDesign` section of `linux/README.md`
- Automated install/update: `./install.sh` and `./update.sh`
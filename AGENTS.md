# Agent instructions

## Generating patches for upstream sources

Patches in `sources/<name>/patches/` are applied via `patch -p1` to a clean upstream checkout. Use plain unified diff (`diff -u`), not `git diff`.

### Why not git diff

`git diff` embeds `index <sha>..<sha>` lines and requires a git repository context. Plain `diff -u` produces portable patches that apply with standard `patch(1)` regardless of git history.

### Workflow

For each new patch N:

- Clone (or reuse) the upstream repo at the pinned tag into `/tmp/upstream`.

- Build the **original** tree (state before patch N) using a worktree so no
  full copy is needed:

  ```bash
  git -C /tmp/upstream worktree add /tmp/orig HEAD
  for patch in sources/<name>/patches/0001-*.patch … 000$((N-1))-*.patch; do
    patch -d /tmp/orig -p1 < "$patch"
  done
  ```

- Build the **modified** tree (state after patch N) as another worktree, then
  edit the files directly — no git involved:

  ```bash
  git -C /tmp/upstream worktree add /tmp/mod HEAD
  for patch in sources/<name>/patches/0001-*.patch … 000$((N-1))-*.patch; do
    patch -d /tmp/mod -p1 < "$patch"
  done
  # edit files in /tmp/mod
  ```

- Generate the patch for each changed file:

  ```bash
  diff -u --label "a/path/to/file" --label "b/path/to/file" \
    /tmp/orig/path/to/file /tmp/mod/path/to/file
  ```

  Collect output for all changed files into `sources/<name>/patches/000N-description.patch`.

- Verify the patch applies using yet another worktree:

  ```bash
  git -C /tmp/upstream worktree add /tmp/verify HEAD
  for patch in sources/<name>/patches/0001-*.patch … 000$((N-1))-*.patch; do
    patch -d /tmp/verify -p1 < "$patch"
  done
  patch -d /tmp/verify -p1 < sources/<name>/patches/000N-description.patch
  ```

- Clean up worktrees when done:

  ```bash
  git -C /tmp/upstream worktree remove --force /tmp/orig
  git -C /tmp/upstream worktree remove --force /tmp/mod
  git -C /tmp/upstream worktree remove --force /tmp/verify
  ```

### Rules

- Each patch must apply on top of all previous patches in order.
- A patch must contain **only** its own changes — never re-include hunks already present in earlier patches.
- Do not use `git stash`, `git diff`, `git apply` or any other git commands for patch generation.
- Paths inside the patch must be `a/<relative-path>` / `b/<relative-path>` so that `patch -p1` strips exactly one path component and lands in the right place.
- Test the patched tree after applying all patches to confirm nothing is broken.

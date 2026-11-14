# Workflow Orchestration — OmnisTools overrides

These rules refine the general workflow-orchestration guidance for the
OmnisTools repositories. Where they conflict with generic guidance, these win.

## Integration branch is `main`, never `mainline`

The OmnisTools repos (frontend-omnis, backend-omnis, infra-omnis, and the
others under this workspace) use `main` as their default/integration branch.
There is no branch named `mainline` in any of them.

When a workflow runs work in a git worktree:

- Create the worktree from the repository's default branch, which is `main`:
  `git worktree add .worktrees/<name> -b <branch> main`
- Do NOT assume or reference a branch named `mainline`. If a brief or
  convention says `mainline`, substitute the repository's actual default
  branch (`main`).
- Before basing a worktree on any ref, confirm the ref exists
  (`git show-ref --verify refs/heads/<ref>` or `git rev-parse <ref>`). If the
  named base does not exist, fall back to the repository default branch and
  say so, rather than failing.

## Never auto-advance the trunk — open a PR

`main` is the protected trunk in every OmnisTools repo. The final step of a
worktree workflow must NOT fast-forward, merge, or otherwise advance `main`
directly.

Instead, the final step:

1. Rebases the feature branch onto the latest `origin/main` (resolving
   conflicts if any).
2. Pushes the feature branch to origin with tracking
   (`git push -u origin <branch>`). Never force-push.
3. Leaves `main` and every lane branch untouched. The orchestrator (or a human)
   opens a pull request into the dev-lane branch (`devtest`; legacy `dev` in
   repos not yet renamed) for review. Merges happen through the PR, not from
   inside the workflow. `main` only changes through the final
   `production` → `main` reconcile PR (see aws-environments.md).

Changes across related tickets (e.g. a multi-repo upgrade tracked under one
epic) should land as a reviewed set of PRs so they can be coordinated, not
auto-merged one at a time.

## Worktree cleanup

The orchestrator removes a worktree and its local branch only after the
corresponding PR has merged, since an in-worktree step cannot safely delete
the directory it is running in.

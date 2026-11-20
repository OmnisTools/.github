---
inclusion: always
---
# Git commit signing: verify first, never work around

Commits in OmnisTools repos are SSH-signed through 1Password (`op-ssh-sign`,
configured in `~/.gitconfig`; the key is inline in `~/.gitconfig-omnis`). The
signer can fail at any time: 1Password locked, restarted or updated, key not
available, or a bad `user.signingkey` override in a repo. An unsigned or
unverifiable commit is a policy failure, not a nuisance.

## Preflight (do this before the first commit of any task)

From inside the repo or worktree you will commit in:

```bash
~/OmnisTools/org-github/scripts/git-signing-check.sh
```

(The path must be a checkout of `OmnisTools/.github` on `main`.) It signs a
throwaway message with the exact config git would use, then checks the key is a
registered GitHub signing key. It creates no commit and prints no key material.

| Exit | Meaning | Action |
| ---- | ------- | ------ |
| 0 | Signer works, key registered | Proceed |
| 2 | Signing disabled/unsupported here | Stop, report |
| 3 | Key config wrong (missing key, private key file, bad override) | Stop. Fix is usually `git config --local --unset user.signingkey` |
| 4 | Signer failed or timed out (1Password locked/unavailable) | Stop, ask the user to unlock 1Password, re-run |
| 5 | Signs, but key not registered on GitHub (commits show Unverified) | Stop, report |

Workflow steps that commit run the preflight as their first action. Re-run it
immediately if any commit fails.

## When it fails: stop and report, do not route around it

- Do NOT use `--no-gpg-sign`, `-c commit.gpgsign=false`, or edit `commit.gpgsign`.
- Do NOT point `user.signingkey` at a key file on disk, switch `gpg.ssh.program`
  to `ssh-keygen`, or generate a new key. An unencrypted on-disk key is exactly
  what this rule replaces, and such commits are Unverified on GitHub.
- Do NOT set a repo-local `user.signingkey`; the global/omnis config is correct.
- Do NOT paste raw signer or `git commit` error output into messages, logs or
  PR text: older `op-ssh-sign` versions printed private key contents on error.
  Quote the check script's own output, which is filtered.
- In a workflow, report with `send_message` severity `warning` (the run pauses
  for the user to unlock 1Password) and resume only after a passing re-check.
  In a plain session, tell the user what failed and wait.
- Never leave the work uncommitted silently. Say which changes are staged and
  where, so they can be committed once signing works.

## Verifying afterwards

```bash
git log -1 --format='%h %G? %GK'   # expect G and the registered key
```

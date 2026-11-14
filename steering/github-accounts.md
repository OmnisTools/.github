---
inclusion: always
---

# GitHub accounts: which identity to use for `gh`

This machine has **two** GitHub accounts authenticated in the `gh` CLI:

| Account      | Use it for                                                        |
| ------------ | ----------------------------------------------------------------- |
| `robomnis`   | **Any repo in an `Omnis*` org** (e.g. `OmnisTools/*`). Default for all work in this workspace. |
| `roboweaver` | Everything else (personal / non-Omnis repos). The machine default. |

All repos under this workspace (`backend-omnis`, `frontend-omnis`, `infra-*`,
`OmnisSkills`, …) belong to the **`OmnisTools`** org, so **use `robomnis`** for
every `gh` / GitHub API operation here.

## Per-identity tokens (the reliable mechanism)

Each identity's token lives in its **own** environment variable, populated from
the gh keyring at shell startup by `~/.gh-omnis.bash` (sourced from `~/.bashrc`
after `~/.gh-token.bash`):

| Env var               | Identity     |
| --------------------- | ------------ |
| `GH_TOKEN_ROBOMNIS`   | `robomnis`   |
| `GH_TOKEN_ROBOWEAVER` | `roboweaver` |

An org-aware `gh` wrapper selects the right token per repo and hands it to that
one invocation as `GH_TOKEN`, with any ambient `GITHUB_TOKEN` stripped. Nothing
globally overrides gh for the wrong org.

Helpers provided by `~/.gh-omnis.bash`:

- `gh <args>` — wrapper that auto-selects the identity from the repo org of `$PWD`
- `ghomnis <args>` — force the `robomnis` identity
- `ghme <args>` — force the `roboweaver` identity
- `gh-whoami-here` — show which identity the wrapper uses in the current dir
- `ghtokens-refresh` — re-read both tokens from the gh keyring

## Rules for the agent

1. **For Omnis-org repos, run gh with the robomnis token explicitly.** The most
   robust, non-interactive form (works regardless of any ambient token and
   never mutates gh's active account):

   ```bash
   env -u GITHUB_TOKEN GH_TOKEN="$GH_TOKEN_ROBOMNIS" gh <args...>
   ```

   If `GH_TOKEN_ROBOMNIS` is not set in the current shell (e.g. a minimal
   non-login shell that didn't source `~/.gh-omnis.bash`), read it from the
   keyring first:

   ```bash
   GH_TOKEN_ROBOMNIS="$(env -u GITHUB_TOKEN -u GH_TOKEN gh auth token --user robomnis)"
   env -u GITHUB_TOKEN GH_TOKEN="$GH_TOKEN_ROBOMNIS" gh <args...>
   ```

   (If the `gh` function wrapper from `~/.gh-omnis.bash` is active, a bare
   `gh ...` inside an Omnis repo already does the right thing.)

2. **Verify identity before acting — STOP if it prints `roboweaver`.** Always
   confirm the effective identity first; it must print `robomnis`:

   ```bash
   env -u GITHUB_TOKEN GH_TOKEN="$GH_TOKEN_ROBOMNIS" gh api user --jq .login  # expect: robomnis
   ```

   If it prints anything else, STOP — do not create or modify PRs/issues/repos
   until the token selection is corrected.

3. **The trap — a 404 is almost always wrong-account, not a missing repo.** A
   bare exported `GITHUB_TOKEN` can resolve to `roboweaver`, which cannot see
   `OmnisTools/*`. The symptom:

   > Could not resolve to a Repository with the name 'OmnisTools/<repo>'. (NOT_FOUND / HTTP 404)

   while `git push` (SSH) works fine. Before believing a not-found result,
   confirm the identity:

   ```bash
   env -u GITHUB_TOKEN GH_TOKEN="$GH_TOKEN_ROBOMNIS" gh api user --jq .login  # must print robomnis
   ```

   If it prints `roboweaver`, that is the bug — re-run with the robomnis token,
   not with a different resource name.

4. **Do not print, echo, or log token values.** Reference accounts by name
   (`robomnis` / `roboweaver`), never by their `gho_...` token. If a token value
   appears in output, do not repeat it.

5. **git over SSH is already correct** and account-aware (the `robomnis-github`
   SSH host alias / `insteadOf` rules route Omnis repos through the `robomnis`
   key). Do **not** "fix" git auth to work around a gh-API 404 — only the gh
   API token selection is the problem.

## Scope and safety

- This applies to all `gh` actions on Omnis-org repos: PRs, issues, reviews,
  releases, labels, comments, and API reads.
- Do NOT modify global git config, the `GITHUB_TOKEN` value itself, or the gh
  keyring. Clearing `GITHUB_TOKEN` **for a single command** via `env -u` changes
  nothing persistently and is the sanctioned approach.
- Do not print, echo, or log token values. Reference accounts by name
  (`robomnis` / `roboweaver`), never by their `gho_...` token.
- `robomnis` already holds the required scopes for `OmnisTools/*`; no new token
  or scope grant is needed.

## Quick reference

```bash
# Omnis repo, explicit identity (robust in any shell):
env -u GITHUB_TOKEN GH_TOKEN="$GH_TOKEN_ROBOMNIS" gh api graphql -f query='…'

# Confirm who gh will act as:
env -u GITHUB_TOKEN GH_TOKEN="$GH_TOKEN_ROBOMNIS" gh api user --jq .login
```

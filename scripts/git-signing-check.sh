#!/usr/bin/env bash
# Preflight for SSH commit signing: prove that a commit made RIGHT NOW in this
# repo would be signed, and that GitHub will show it as Verified.
#
# Why: signing is done by an external program (1Password's op-ssh-sign). When
# 1Password is locked, restarted, updated, or the configured key is wrong, the
# commit fails with an opaque error (e.g. "1Password: invalid ssh public key"),
# often hours into a task. Run this first so the failure is found early and the
# fix is known. It signs a throwaway message with the exact config git would use;
# it never creates a commit and never prints key material.
#
# usage: git-signing-check.sh [--no-github] [--github-user LOGIN] [--quiet]
#   run it from inside the repo (or worktree) you are about to commit in.
#   env: GIT_SIGNING_CHECK_TIMEOUT  seconds to wait for the signer (default 20)
#
# exit codes:
#   0  OK: signer works and key is registered on GitHub (or check skipped)
#   2  signing is not enabled/supported here (commit.gpgsign / gpg.format)
#   3  key configuration is wrong (missing, private key given to op-ssh-sign, ...)
#   4  signer failed or timed out (1Password locked/unavailable, key not in agent)
#   5  signing works but the key is not a registered GitHub signing key
#      (commits would show as Unverified)
set -uo pipefail

check_github=1; gh_user=""; quiet=0
while [ $# -gt 0 ]; do
  case "$1" in
    --no-github) check_github=0 ;;
    --github-user) gh_user="${2:-}"; shift ;;
    --quiet) quiet=1 ;;
    -h|--help) sed -n '2,24p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "unknown option: $1" >&2; exit 2 ;;
  esac
  shift
done

say()  { [ "$quiet" -eq 1 ] || printf '%s\n' "$*"; }
fail() { code="$1"; shift; printf 'FAIL: %s\n' "$1" >&2; shift
         for l in "$@"; do printf '  %s\n' "$l" >&2; done; exit "$code"; }

tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
timeout_s="${GIT_SIGNING_CHECK_TIMEOUT:-20}"

# --- effective config (what a commit here would use) --------------------------
gpgsign="$(git config --type=bool --get commit.gpgsign 2>/dev/null || echo false)"
format="$(git config --get gpg.format 2>/dev/null || echo openpgp)"
prog="$(git config --get gpg.ssh.program 2>/dev/null || echo ssh-keygen)"
key="$(git config --get user.signingkey 2>/dev/null || true)"
email="$(git config --get user.email 2>/dev/null || true)"

[ "$gpgsign" = "true" ] || fail 2 "commit.gpgsign is not enabled; commits here would be UNSIGNED." \
  "fix: git config commit.gpgsign true (normally set in ~/.gitconfig)"
[ "$format" = "ssh" ] || fail 2 "gpg.format is '$format'; this check only supports ssh signing."
[ -n "$key" ] || fail 3 "user.signingkey is empty." \
  "fix: put the public key inline in ~/.gitconfig-omnis (user.signingkey = ssh-ed25519 AAAA...)"

# --- identity: an OmnisTools repo must commit as robomnis ----------------------
# The identity comes from includeIf rules keyed on the remote URL. A remote that
# is spelled differently (e.g. no "git@" prefix) silently falls through to the
# default roboweaver identity: signing still "works", with the wrong person/key.
remote="$(git remote get-url origin 2>/dev/null || true)"
case "$remote" in
  *OmnisTools/*|*robomnis/*)
    case "$email" in
      *+robomnis@users.noreply.github.com) ;;
      *) fail 3 "identity mismatch: remote '$remote' is an OmnisTools repo but commits would use '${email:-<no email>}'." \
           "The includeIf rules in ~/.gitconfig did not match this remote URL (they expect git@robomnis-github:OmnisTools/...)." \
           "fix: git remote set-url origin git@robomnis-github:OmnisTools/<repo>.git" ;;
    esac ;;
esac

# --- resolve the key to a public-key file git/the signer will be handed -------
keyfile=""
case "$key" in
  ssh-*|sk-ssh-*|key::*)
    printf '%s\n' "${key#key::}" > "$tmp/key.pub"; keyfile="$tmp/key.pub"; kind="inline public key" ;;
  *)
    p="${key/#\~/$HOME}"
    [ -f "$p" ] || fail 3 "user.signingkey points at '$key', which does not exist." \
      "fix: remove the repo-local override (git config --local --unset user.signingkey) so the" \
      "     inline key from ~/.gitconfig-omnis applies."
    if grep -q "PRIVATE KEY" "$p" 2>/dev/null; then
      case "$prog" in
        *op-ssh-sign*) fail 3 "user.signingkey '$key' is a PRIVATE key file; op-ssh-sign rejects it" \
          "('1Password: invalid ssh public key') and prints the file's contents." \
          "fix: git config --local --unset user.signingkey  (use the inline key in ~/.gitconfig-omnis)" ;;
      esac
    fi
    keyfile="$p"; kind="key file" ;;
esac
fp="$(ssh-keygen -lf "$keyfile" 2>/dev/null | awk '{print $2}')"
[ -n "$fp" ] || fail 3 "could not read a key from user.signingkey ($kind)." \
  "fix: it must be an ssh public key (inline 'ssh-ed25519 AAAA...' or a .pub path)."

# --- sign a throwaway message with the exact program git would run ------------
printf 'git-signing-check\n' > "$tmp/in"
( "$prog" -Y sign -n git -f "$keyfile" < "$tmp/in" > "$tmp/out" 2> "$tmp/err" ) &
pid=$!
( sleep "$timeout_s"; : > "$tmp/timedout"; kill "$pid" 2>/dev/null ) &
wd=$!
wait "$pid" 2>/dev/null; rc=$?
kill "$wd" 2>/dev/null; wait "$wd" 2>/dev/null

# Never echo raw signer stderr: it can contain key material. Keep only short,
# non-key lines.
safe_err="$(awk '/BEGIN .*PRIVATE KEY/{skip=1} !skip && length($0)<200 && $0 !~ /^[A-Za-z0-9+\/=]{40,}$/ {print} /END .*PRIVATE KEY/{skip=0}' "$tmp/err" | head -3)"

if [ -e "$tmp/timedout" ]; then
  fail 4 "signer '$prog' did not answer within ${timeout_s}s." \
    "Likely 1Password is locked or waiting on an unlock/Touch ID prompt." \
    "fix: unlock 1Password (and approve any prompt), then re-run."
fi
if [ "$rc" -ne 0 ] || ! head -1 "$tmp/out" | grep -q '^-----BEGIN SSH SIGNATURE-----'; then
  fail 4 "signer '$prog' failed (exit $rc) for key $fp." \
    "${safe_err:-(no error output)}" \
    "Likely causes: 1Password locked/not running, key not in the 1Password SSH agent, or the" \
    "key item is not available to this account. Do NOT bypass with --no-gpg-sign or an on-disk key." \
    "fix: unlock/restart 1Password, confirm the key is listed, then re-run."
fi
say "OK: signer '$prog' produced a signature with $fp"

# --- is the key registered on GitHub as a signing key? ------------------------
if [ "$check_github" -eq 1 ]; then
  if [ -z "$gh_user" ]; then
    gh_user="$(printf '%s' "$email" | sed -n 's/^[0-9]*+\([^@]*\)@users\.noreply\.github\.com$/\1/p')"
  fi
  if [ -z "$gh_user" ]; then
    say "SKIP: GitHub registration check (no noreply email; pass --github-user LOGIN)"
  elif ! curl -fsS --max-time 10 "https://api.github.com/users/$gh_user/ssh_signing_keys" -o "$tmp/gh.json" 2>/dev/null; then
    say "WARN: could not query GitHub signing keys for $gh_user (offline or rate-limited); skipped"
  else
    found=0
    while IFS= read -r k; do
      [ -n "$k" ] || continue
      f="$(printf '%s\n' "$k" | ssh-keygen -lf - 2>/dev/null | awk '{print $2}')"
      [ "$f" = "$fp" ] && found=1
    done < <(python3 -c 'import json,sys
for k in json.load(open(sys.argv[1])): print(k["key"])' "$tmp/gh.json" 2>/dev/null)
    [ "$found" -eq 1 ] || fail 5 "key $fp is not a signing key on GitHub for '$gh_user'; commits would show as Unverified." \
      "fix: use the registered key, or add this key at github.com/settings/keys (type: Signing Key)."
    say "OK: $fp is a registered GitHub signing key for $gh_user"
  fi
fi
exit 0

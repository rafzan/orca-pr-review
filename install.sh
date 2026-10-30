#!/usr/bin/env bash
# Installs orca-pr-review for one GitHub repo: the script, its config, the launchd job and the SwiftBar menu.
# Usage: ./install.sh <owner/repo> [interval-seconds]
# Run it again after a git pull to update. It keeps the review message and the check interval.
set -euo pipefail

GH_REPO="${1:?usage: ./install.sh <owner/repo> [interval-seconds]}"
HERE="$(cd "$(dirname "$0")" && pwd)"
ORCA="/Applications/Orca.app/Contents/Resources/bin/orca"
BIN="$HOME/.local/bin"
CONFIG_DIR="$HOME/.config/orca-pr-review"
PLIST="$HOME/Library/LaunchAgents/local.orca-pr-review.plist"
# launchd runs the script with this PATH.
JOB_PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin"

fail() {
  echo "error: $*" >&2
  exit 1
}

[[ -x "$ORCA" ]] || fail "Orca is not installed in /Applications"
command -v claude >/dev/null || fail "claude is not on your PATH"
for cmd in gh jq git; do
  PATH="$JOB_PATH" command -v "$cmd" >/dev/null || fail "$cmd is not in $JOB_PATH"
done
gh auth status >/dev/null 2>&1 || fail "gh is not logged in, run: gh auth login"
gh repo view "$GH_REPO" --json name >/dev/null 2>&1 || fail "gh cannot read $GH_REPO"

repos=$("$ORCA" repo list --json 2>/dev/null) || fail "Orca does not answer, open Orca and run again"
repo_id=""
repo_path=""
while IFS=$'\t' read -r id path; do
  if git -C "$path" remote -v 2>/dev/null | awk '{ print $2 }' |
    sed -E 's#^.*github\.com[:/]##; s#\.git$##' | grep -qixF "$GH_REPO"; then
    repo_id="$id"
    repo_path="$path"
    break
  fi
done < <(jq -r '.result.repos[] | [.id, .path] | @tsv' <<<"$repos")
[[ -n "$repo_id" ]] || fail "no Orca repo has a remote for $GH_REPO, add your clone to Orca and run again"

if [[ -n "${2:-}" ]]; then
  interval="$2"
else
  interval=$(plutil -extract StartInterval raw "$PLIST" 2>/dev/null || echo 300)
fi

mkdir -p "$BIN" "$CONFIG_DIR"
printf 'GH_REPO="%s"\nORCA_REPO="id:%s"\n' "$GH_REPO" "$repo_id" >"$CONFIG_DIR/config"
cp "$HERE/review-settings.json" "$CONFIG_DIR/review-settings.json"
install -m 755 "$HERE/orca-pr-review" "$BIN/orca-pr-review"
echo "installed for $GH_REPO, Orca repo $repo_path"

plugins=$(defaults read com.ameba.SwiftBar PluginDirectory 2>/dev/null || true)
if [[ -n "$plugins" && -d "$plugins" ]]; then
  install -m 755 "$HERE/swiftbar/orca-pr-review.30s.sh" "$plugins/orca-pr-review.30s.sh"
  echo "added the menu bar icon to SwiftBar"
else
  echo "warning: SwiftBar has no plugin folder, so you get no menu bar icon and no notifications"
fi

# GIT_CONFIG_NOSYSTEM removes system helpers only. Helpers in your own or the repo config can still push over HTTPS.
helpers=$(GIT_CONFIG_NOSYSTEM=1 git -C "$repo_path" config --get-regexp '^credential\..*helper$' || true)
if [[ -n "$helpers" ]]; then
  echo "warning: review sessions keep these git credential helpers, so they can push over HTTPS:"
  echo "$helpers"
fi

"$BIN/orca-pr-review" --interval "$interval"

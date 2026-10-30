#!/usr/bin/env bash
# SwiftBar menu for orca-pr-review: status, check now, check interval, review message, log.

LABEL="local.orca-pr-review"
SCRIPT="$HOME/.local/bin/orca-pr-review"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
LAST_RUN="$HOME/.local/state/orca-pr-review/last-run"
LOG="$HOME/Library/Logs/orca-pr-review.log"
DOMAIN="gui/$(id -u)"
PRESETS="60 300 600 1800 3600"

# A notification click reruns this plugin with focus_pr set.
[[ -n "${focus_pr:-}" ]] && "$SCRIPT" --focus "$focus_pr" >/dev/null 2>&1

interval=$(plutil -extract StartInterval raw "$PLIST" 2>/dev/null || echo 0)
if launchctl print "$DOMAIN/$LABEL" >/dev/null 2>&1; then
  echo "| sfimage=eye"
else
  echo "| sfimage=eye.slash"
fi
echo "---"
echo "Last check: $(cat "$LAST_RUN" 2>/dev/null || echo never)"
echo "Check now | bash=/bin/launchctl param0=kickstart param1=$DOMAIN/$LABEL terminal=false refresh=true"
echo "Check every"
for secs in $PRESETS; do
  checked=""
  [[ "$secs" == "$interval" ]] && checked=" checked=true"
  if ((secs < 3600)); then label="$((secs / 60)) min"; else label="$((secs / 3600)) h"; fi
  echo "--$label | bash=$SCRIPT param0=--interval param1=$secs terminal=false refresh=true$checked"
done
if ((interval > 0)) && ! grep -qw "$interval" <<<"$PRESETS"; then
  echo "--Custom ($((interval / 60)) min)... | bash=$SCRIPT param0=--ask-interval terminal=false refresh=true checked=true"
else
  echo "--Custom... | bash=$SCRIPT param0=--ask-interval terminal=false refresh=true"
fi
echo "Edit review message... | bash=$SCRIPT param0=--edit-message terminal=false"
echo "Open log | bash=/usr/bin/open param0=$LOG terminal=false"

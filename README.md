# orca-pr-review

When a pull request (PR) asks for your review, this tool opens an Orca workspace for it. The workspace starts Claude Code with a review message. Claude reviews the PR and waits for you. It does not post anything to GitHub.

## What it does

- A launchd job reads your GitHub notifications for one repo. The default interval is 5 minutes. When nothing changed, GitHub answers 304, and that answer does not count against the rate limit.
- A new review request opens a workspace named `review-pr-<number>` and a Claude session in it.
- A re-request goes to the same workspace, so Claude keeps its context. If the Claude session is open, the tool sends the message to it. If not, the tool resumes the last session with `claude --continue`.
- The tool re-reviews only when the PR author re-requests your review. It skips your own PRs, draft PRs and closed PRs.
- On the first run, the tool marks all open requests as handled and opens nothing.

## Requirements

- macOS with Orca in `/Applications`, and your clone of the repo added to Orca
- [Claude Code](https://claude.com/claude-code) (`claude`)
- `gh` logged in (`gh auth login`), `jq` and `git`, in Homebrew or in `/usr/bin`
- [SwiftBar](https://github.com/swiftbar/SwiftBar) for the menu bar icon and the notifications (optional)

## Install

Open Orca first. Then run:

```bash
git clone git@github.com:rafzan/orca-pr-review.git
cd orca-pr-review
./install.sh <owner/repo>
```

To set the interval in seconds, add it as a second argument. The minimum is 60. To update, run `git pull` and `./install.sh <owner/repo>` again. The installer keeps your review message and your interval.

## Menu bar

The SwiftBar icon shows the last check. The menu has:

- Check now
- Check every (1 min, 5 min, 10 min, 30 min, 1 h, or a custom number of minutes)
- Edit review message (`{pr}` becomes the PR number)
- Open log

A notification appears when a review opens or a re-request arrives. Click it to go to the Claude session in Orca.

## Safety

The review session runs Claude with `--dangerously-skip-permissions`, so Claude does not stop to ask for permission. These layers block writes:

- `review-settings.json` denies every `gh` command that writes to GitHub, and `git push`.
- An SSH wrapper refuses every push over SSH.
- The session drops the git credential helpers of the system config. Your own git config and the repo config can still have a helper, for example from `gh auth setup-git`. If so, Claude can push over HTTPS. The installer prints these helpers.

The deny list matches command text, so it is not a hard block. Read the review before you act on it.

## Command line

```bash
orca-pr-review --dry-run      # show what the next check does, change nothing
orca-pr-review --pr 1234      # check one PR now
orca-pr-review --interval 600 # check every 10 minutes
```

## Files

- `~/.local/bin/orca-pr-review`: the script
- `~/.config/orca-pr-review/`: `config`, `message.txt`, `review-settings.json`
- `~/.local/state/orca-pr-review/`: the handled requests and the last check
- `~/Library/Logs/orca-pr-review.log`: the log
- `~/Library/LaunchAgents/local.orca-pr-review.plist`: the launchd job

## Uninstall

```bash
launchctl bootout gui/$(id -u)/local.orca-pr-review
rm ~/Library/LaunchAgents/local.orca-pr-review.plist ~/.local/bin/orca-pr-review
rm -r ~/.config/orca-pr-review ~/.local/state/orca-pr-review
```

Then delete `orca-pr-review.30s.sh` from the SwiftBar plugin folder.

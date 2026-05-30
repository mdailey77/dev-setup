# Mac Homebrew Weekly Updater

This folder contains a small macOS `launchd` setup for automatically updating Homebrew formulae and cask applications on a weekly schedule.

It is intended to update applications installed through Homebrew, including tools and apps such as:

- `git`
- iTerm2
- Visual Studio Code
- Spotify
- Todoist
- Other Homebrew cask applications

## What it does

The scheduled job runs this flow once per week:

```bash
brew update
brew upgrade
brew upgrade --cask --greedy-auto-updates
brew cleanup
brew doctor
```

Logs are written to:

```text
~/Library/Logs/homebrew-weekly/
```

The default schedule is:

```text
Every Monday at 9:00 AM local time
```

## Folder contents

```text
mac-homebrew-weekly-updater/
├── README.md
├── launchagents/
│   └── com.local.weekly-homebrew-update.plist.template
├── logs/
│   └── .gitkeep
└── scripts/
    ├── install-launchagent.sh
    ├── uninstall-launchagent.sh
    └── weekly-brew-update.sh
```

## Prerequisites

Install Homebrew first if it is not already installed:

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

Verify Homebrew works:

```bash
brew --version
brew doctor
```

## Install common apps through Homebrew

Install the apps you want Homebrew to manage:

```bash
brew install git
brew install --cask iterm2
brew install --cask docker
brew install --cask visual-studio-code
brew install --cask spotify
brew install --cask todoist
```

Optional additional apps:

```bash
brew install --cask google-chrome
brew install --cask firefox
brew install --cask slack
brew install --cask zoom
brew install --cask obsidian
brew install --cask rectangle
```

To see all cask apps managed by Homebrew:

```bash
brew list --cask
```

## Install the weekly updater

From this folder, run:

```bash
./scripts/install-launchagent.sh
```

The installer will:

1. Copy `weekly-brew-update.sh` to `~/bin/weekly-brew-update.sh`.
2. Generate a user LaunchAgent at `~/Library/LaunchAgents/com.local.weekly-homebrew-update.plist`.
3. Load the LaunchAgent with `launchctl`.
4. Schedule the job for Monday at 9:00 AM.

## Test the scheduled job manually

Run:

```bash
launchctl kickstart -k gui/$(id -u)/com.local.weekly-homebrew-update
```

Then check logs:

```bash
tail -n 100 ~/Library/Logs/homebrew-weekly/launchd.out.log
tail -n 100 ~/Library/Logs/homebrew-weekly/launchd.err.log
```

Individual timestamped run logs are also created here:

```bash
ls -lt ~/Library/Logs/homebrew-weekly/
```

## Change the schedule

Edit the generated LaunchAgent:

```bash
nano ~/Library/LaunchAgents/com.local.weekly-homebrew-update.plist
```

The default schedule block is:

```xml
<key>StartCalendarInterval</key>
<dict>
  <key>Weekday</key>
  <integer>1</integer>
  <key>Hour</key>
  <integer>9</integer>
  <key>Minute</key>
  <integer>0</integer>
</dict>
```

`Weekday` values:

```text
1 = Sunday
2 = Monday
3 = Tuesday
4 = Wednesday
5 = Thursday
6 = Friday
7 = Saturday
```

After changing the plist, reload it:

```bash
launchctl bootout gui/$(id -u) ~/Library/LaunchAgents/com.local.weekly-homebrew-update.plist 2>/dev/null || true
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.local.weekly-homebrew-update.plist
launchctl enable gui/$(id -u)/com.local.weekly-homebrew-update
```

## Uninstall

From this folder, run:

```bash
./scripts/uninstall-launchagent.sh
```

This removes the LaunchAgent and optionally removes the copied updater script from `~/bin`.

## Notes and caveats

### Homebrew-managed apps only

This updates apps installed through Homebrew. It does not update apps installed manually from `.dmg` files unless those apps are also installed and managed as Homebrew casks.

### Mac App Store apps are separate

Homebrew does not update Mac App Store apps. Use macOS App Store automatic updates or the `mas` CLI if you want to automate App Store updates.

### Some apps self-update

Apps such as Spotify, Todoist, VS Code, Chrome, Slack, and Docker Desktop may have their own built-in update systems. The script uses:

```bash
brew upgrade --cask --greedy-auto-updates
```

This tells Homebrew to attempt upgrades for casks that normally self-update when Homebrew can detect a newer version.

### Apps may need to be closed

Some GUI applications may fail to upgrade if they are running. If you see failures for Docker Desktop, VS Code, iTerm2, Spotify, or Todoist, quit the app and run the job manually again.

### Docker Desktop note

Docker Desktop upgrades can be more disruptive than normal app upgrades. If you prefer to update Docker Desktop manually, edit `scripts/weekly-brew-update.sh` and replace:

```bash
"${BREW}" upgrade --cask --greedy-auto-updates
```

with:

```bash
"${BREW}" upgrade --cask --greedy-auto-updates --greedy-latest
```

or remove Docker Desktop from Homebrew management and use its built-in updater. To update Docker Desktop you need to be in privileged mode which `launchd` lacks.

## Useful commands

Preview outdated formulae and casks:

```bash
brew outdated
brew outdated --cask
brew outdated --cask --greedy
```

Run updates manually:

```bash
~/bin/weekly-brew-update.sh
```

Check whether the LaunchAgent is loaded:

```bash
launchctl print gui/$(id -u)/com.local.weekly-homebrew-update
```

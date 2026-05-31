# DevOps VS Code Profile

Portable global VS Code profile and global Git pre-commit linting setup for DevOps workstations.

This setup intentionally avoids repo-local configuration and Dev Containers.
It is designed for a single user profile that can be transferred to another
computer and used across every Git repository on the machine.

## What this installs

- VS Code extensions from `vscode/extensions.txt`
- VS Code global user settings from `vscode/settings.json`
- VS Code global keybindings from `vscode/keybindings.json`, if present
- A global Git hooks path at `~/.config/git/hooks`
- A global `pre-commit` hook that runs on every commit in every Git repository
- A portable lint script at `~/.config/devops-vscode-profile/lint/lint-staged-devops.sh`
- Global linting configs for YAML, Markdown, and GitLeaks
- Common DevOps CLI tools on macOS through Homebrew

## Design

```text
Global VS Code Profile
├── extensions
├── settings
├── keybindings
├── snippets/profile export, optional
└── user-level editor behavior

Global Git Hook Policy
├── git config --global core.hooksPath ~/.config/git/hooks
├── ~/.config/git/hooks/pre-commit
└── ~/.config/devops-vscode-profile/lint/lint-staged-devops.sh

Global Linting Tools
├── yamllint
├── shellcheck
├── terraform
├── tflint
├── gitleaks
├── trivy
├── kubeconform
├── hadolint
├── ansible-lint
└── markdownlint-cli2
```

## Important behavior

After installation, every `git commit` on the machine runs the global pre-commit hook.

The hook checks staged files where possible and runs broader checks when needed. A failed lint or security check blocks the commit.

Emergency bypass:

```bash
git commit --no-verify
```

Use bypass only when you have a clear reason, such as a tool outage or a known false positive.

## Install on macOS

Prerequisites:

- VS Code installed
- VS Code `code` CLI installed
- Homebrew installed
- Git installed

Install:

```bash
git clone git@github.com:YOUR_USER/devops-vscode-profile.git
cd devops-vscode-profile
./install.sh
```

If the `code` command is not available, open VS Code and run:

```text
Command Palette → Shell Command: Install 'code' command in PATH
```

Then rerun:

```bash
./install.sh
```

## Install on Linux

Linux package managers vary by distribution. The Linux installer copies the VS Code and Git hook
configuration but does not try to install every tool automatically.

```bash
./scripts/install-linux.sh
```

Then install the required tools with your preferred package manager, `mise`, `asdf`, `brew`, or distro packages.

## Verify installation

```bash
./scripts/doctor.sh
```

Manual checks:

```bash
git config --global --get core.hooksPath
ls -l ~/.config/git/hooks/pre-commit
ls -l ~/.config/devops-vscode-profile/lint/lint-staged-devops.sh
```

Expected hooks path:

```text
~/.config/git/hooks
```

## Test the global hook

In any Git repository:

```bash
git status
```

Stage a file:

```bash
git add README.md
```

Commit:

```bash
git commit -m "test global lint hook"
```

If a supported file type is staged, the hook runs relevant checks.

## Supported checks

| File type / area | Tool |
| --- | --- |
| Secrets | `gitleaks protect --staged` |
| YAML | `yamllint` |
| Bash | `shellcheck` |
| Terraform | `terraform fmt -recursive -check`, `tflint` |
| Markdown | `markdownlint-cli2` or `markdownlint` |
| Dockerfile | `hadolint` |
| Ansible | `ansible-lint` |
| Kubernetes manifests | `kubeconform` |
| IaC/security config | `trivy config` |

## Export your current VS Code setup

Run:

```bash
./backup.sh
```

This captures:

- Installed VS Code extensions
- VS Code user settings
- VS Code keybindings, if present
- Existing global pre-commit hook, if configured

Review changes before committing:

```bash
git diff
```

## Export VS Code Profile manually

In VS Code:

```text
Command Palette → Profiles: Export Profile
```

Save the exported file as:

```text
vscode/profile.code-profile
```

On a new computer:

```text
Command Palette → Profiles: Import Profile
```

Select:

```text
vscode/profile.code-profile
```

## Updating extension list

```bash
code --list-extensions > vscode/extensions.txt
```

Then commit the updated file.

## Updating global lint policy

Edit:

```text
lint/lint-staged-devops.sh
```

Then reinstall:

```bash
./install.sh
```

The installer copies the repo to:

```text
~/.config/devops-vscode-profile
```

## Uninstall

```bash
./scripts/uninstall.sh
```

This removes the global hooks path and deletes the installed global hook/config directory.
It does not uninstall VS Code extensions or CLI tools.

## Notes and tradeoffs

This setup is workstation policy, not team policy. It protects your commits on your machine.
It does not enforce the same policy for other developers unless they install the same setup.

For shared enforcement, run the same or stricter checks in CI.

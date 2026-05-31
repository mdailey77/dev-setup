#!/usr/bin/env bash

set -u
set -o pipefail

ROOT_DIR="${1:-$(pwd)}"
DRY_RUN=false
DELETE_REMOTE_MERGED=false

usage() {
  cat <<EOF
Usage:
  update-workspace-repos.sh [workspace-root] [options]

Options:
  --dry-run                 Show what would happen without making changes
  --delete-remote-merged    Also delete remote branches merged into the default branch
  -h, --help                Show this help

Behavior:
  - Finds all Git repositories under the workspace root
  - Fetches and prunes remotes
  - Detects the default branch from origin/HEAD
  - Switches to the default branch
  - Pulls latest changes
  - Deletes local branches already merged into the default branch
  - Skips repositories with uncommitted changes
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    --delete-remote-merged)
      DELETE_REMOTE_MERGED=true
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      if [[ -d "$1" ]]; then
        ROOT_DIR="$1"
        shift
      else
        echo "ERROR: Unknown argument: $1" >&2
        usage
        exit 1
      fi
      ;;
  esac
done

run() {
  if [[ "$DRY_RUN" == true ]]; then
    echo "DRY RUN: $*"
  else
    "$@"
  fi
}

print_header() {
  echo
  echo "============================================================"
  echo "$1"
  echo "============================================================"
}

find_git_repos() {
  find "$ROOT_DIR" \
    -type d \
    -name ".git" \
    -prune \
    -print |
    sed 's|/.git$||' |
    sort
}

has_uncommitted_changes() {
  [[ -n "$(git status --porcelain)" ]]
}

get_default_branch() {
  local default_ref

  default_ref="$(git symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null || true)"

  if [[ -z "$default_ref" ]]; then
    git remote set-head origin --auto >/dev/null 2>&1 || true
    default_ref="$(git symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null || true)"
  fi

  if [[ -n "$default_ref" ]]; then
    echo "${default_ref#origin/}"
    return 0
  fi

  if git show-ref --verify --quiet refs/remotes/origin/main; then
    echo "main"
    return 0
  fi

  if git show-ref --verify --quiet refs/remotes/origin/master; then
    echo "master"
    return 0
  fi

  return 1
}

delete_merged_local_branches() {
  local default_branch="$1"

  git branch --merged "$default_branch" |
    sed 's/^[* ]*//' |
    grep -vE "^(${default_branch}|main|master|develop|dev|stage|staging|test|prod|production)$" |
    while IFS= read -r branch; do
      [[ -z "$branch" ]] && continue

      echo "Deleting merged local branch: $branch"
      run git branch -d "$branch"
    done
}

delete_merged_remote_branches() {
  local default_branch="$1"

  git branch -r --merged "origin/$default_branch" |
    sed 's/^[* ]*//' |
    grep '^origin/' |
    grep -vE "^origin/(${default_branch}|HEAD|main|master|develop|dev|stage|staging|test|prod|production)$" |
    sed 's|^origin/||' |
    while IFS= read -r branch; do
      [[ -z "$branch" ]] && continue

      echo "Deleting merged remote branch: origin/$branch"
      run git push origin --delete "$branch"
    done
}

process_repo() {
  local repo="$1"
  local default_branch

  print_header "Repository: $repo"

  cd "$repo" || {
    echo "ERROR: Could not enter repo: $repo" >&2
    return 1
  }

  if ! git remote get-url origin >/dev/null 2>&1; then
    echo "Skipping: no origin remote."
    return 0
  fi

  if has_uncommitted_changes; then
    echo "Skipping: repository has uncommitted changes."
    git status --short
    return 0
  fi

  echo "Fetching and pruning..."
  run git fetch origin --prune --tags

  default_branch="$(get_default_branch || true)"

  if [[ -z "${default_branch:-}" ]]; then
    echo "Skipping: could not determine default branch."
    return 0
  fi

  echo "Default branch: $default_branch"

  if ! git show-ref --verify --quiet "refs/heads/$default_branch"; then
    echo "Creating local tracking branch: $default_branch"
    run git checkout -B "$default_branch" "origin/$default_branch"
  else
    echo "Switching to: $default_branch"
    run git switch "$default_branch"
  fi

  echo "Pulling latest changes..."
  run git pull --ff-only origin "$default_branch"

  echo "Deleting merged local branches..."
  delete_merged_local_branches "$default_branch"

  if [[ "$DELETE_REMOTE_MERGED" == true ]]; then
    echo "Deleting merged remote branches..."
    delete_merged_remote_branches "$default_branch"
  fi

  echo "Done: $repo"
}

main() {
  local repo
  local repo_count=0
  local failed_count=0

  if [[ ! -d "$ROOT_DIR" ]]; then
    echo "ERROR: Workspace root does not exist: $ROOT_DIR" >&2
    exit 1
  fi

  print_header "Scanning workspace: $ROOT_DIR"

  while IFS= read -r repo; do
    repo_count=$((repo_count + 1))

    if ! process_repo "$repo"; then
      failed_count=$((failed_count + 1))
    fi
  done < <(find_git_repos)

  if [[ "$repo_count" -eq 0 ]]; then
    echo "No Git repositories found."
    exit 0
  fi

  print_header "Workspace update complete"

  echo "Repositories found: $repo_count"
  echo "Repositories failed: $failed_count"

  if [[ "$failed_count" -gt 0 ]]; then
    exit 1
  fi
}

main "$@"

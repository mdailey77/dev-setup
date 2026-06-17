#!/usr/bin/env bash
set -euo pipefail

SCRIPT_NAME="$(basename "$0")"

TARGET_BRANCH="${TARGET_BRANCH:-}"
REMOTE_NAME="${REMOTE_NAME:-origin}"
DRAFT="${DRAFT:-false}"
ASSIGN_SELF="${ASSIGN_SELF:-true}"
REMOVE_SOURCE_BRANCH="${REMOVE_SOURCE_BRANCH:-true}"
SQUASH_BEFORE_MERGE="${SQUASH_BEFORE_MERGE:-}"
OPEN_BROWSER="${OPEN_BROWSER:-true}"
PUSH_BRANCH="${PUSH_BRANCH:-true}"

usage() {
  cat <<EOF
Usage:
  ${SCRIPT_NAME} [options]

Creates a GitLab merge request from the current Git branch using glab.

Environment variables:
  TARGET_BRANCH              Target branch. Default: detected repo default branch
  REMOTE_NAME                Git remote name. Default: origin
  DRAFT                      Create a draft MR. Default: false
  ASSIGN_SELF                Assign MR to yourself. Default: true
  REMOVE_SOURCE_BRANCH       Remove source branch after merge. Default: true
  SQUASH_BEFORE_MERGE        Set squash behavior: true or false. Default: unset
  OPEN_BROWSER               Open MR in browser after creation. Default: true
  PUSH_BRANCH                Push current branch before MR creation. Default: true

Examples:
  ${SCRIPT_NAME}

  TARGET_BRANCH=develop ${SCRIPT_NAME}

  DRAFT=true ${SCRIPT_NAME}

  ASSIGN_SELF=false REMOVE_SOURCE_BRANCH=false ${SCRIPT_NAME}
EOF
}

log() {
  printf '%s\n' "$*"
}

error() {
  printf 'ERROR: %s\n' "$*" >&2
}

require_command() {
  local cmd="$1"

  if ! command -v "${cmd}" >/dev/null 2>&1; then
    error "'${cmd}' is required but not installed."
    return 1
  fi
}

get_current_branch() {
  git rev-parse --abbrev-ref HEAD
}

get_repo_root() {
  git rev-parse --show-toplevel
}

get_default_branch() {
  local default_branch=""

  default_branch="$(
    git remote show "${REMOTE_NAME}" 2>/dev/null \
      | awk -F': ' '/HEAD branch/ {print $2}' \
      | tr -d '[:space:]'
  )"

  if [[ -n "${default_branch}" ]]; then
    printf '%s\n' "${default_branch}"
    return 0
  fi

  if git show-ref --verify --quiet refs/remotes/"${REMOTE_NAME}"/main; then
    printf '%s\n' "main"
    return 0
  fi

  if git show-ref --verify --quiet refs/remotes/"${REMOTE_NAME}"/master; then
    printf '%s\n' "master"
    return 0
  fi

  error "Could not detect default branch from remote '${REMOTE_NAME}'."
  error "Set TARGET_BRANCH manually, for example:"
  error "  TARGET_BRANCH=main ${SCRIPT_NAME}"
  return 1
}

ensure_clean_git_repo() {
  if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    error "This command must be run inside a Git repository."
    exit 1
  fi
}

ensure_glab_auth() {
  if ! glab auth status >/dev/null 2>&1; then
    error "glab is not authenticated."
    error "Run:"
    error "  glab auth login"
    exit 1
  fi
}

main() {
  if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    usage
    exit 0
  fi

  require_command git
  require_command glab

  ensure_clean_git_repo
  ensure_glab_auth

  local repo_root
  local current_branch
  local target_branch

  repo_root="$(get_repo_root)"
  cd "${repo_root}"

  current_branch="$(get_current_branch)"

  if [[ "${current_branch}" == "HEAD" ]]; then
    error "You are in a detached HEAD state."
    exit 1
  fi

  log "Repository: ${repo_root}"
  log "Current branch: ${current_branch}"

  log "Fetching latest refs from '${REMOTE_NAME}'..."
  git fetch "${REMOTE_NAME}" --prune

  if [[ -n "${TARGET_BRANCH}" ]]; then
    target_branch="${TARGET_BRANCH}"
  else
    target_branch="$(get_default_branch)"
  fi

  log "Target branch: ${target_branch}"

  if [[ "${current_branch}" == "${target_branch}" ]]; then
    error "You are currently on the target branch '${target_branch}'."
    error "Create or switch to a feature branch before creating a merge request."
    exit 1
  fi

  if [[ "${PUSH_BRANCH}" == "true" ]]; then
    log "Pushing '${current_branch}' to '${REMOTE_NAME}'..."
    git push -u "${REMOTE_NAME}" "${current_branch}"
  fi

  local args=(
    mr
    create
    --fill
    --target-branch "${target_branch}"
  )

  if [[ "${DRAFT}" == "true" ]]; then
    args+=(--draft)
  fi

  if [[ "${ASSIGN_SELF}" == "true" ]]; then
    args+=(--assignee "@me")
  fi

  if [[ "${REMOVE_SOURCE_BRANCH}" == "true" ]]; then
    args+=(--remove-source-branch)
  fi

  if [[ -n "${SQUASH_BEFORE_MERGE}" ]]; then
    args+=(--squash-before-merge "${SQUASH_BEFORE_MERGE}")
  fi

  log "Creating GitLab merge request..."
  glab "${args[@]}"

  if [[ "${OPEN_BROWSER}" == "true" ]]; then
    log "Opening merge request in browser..."
    glab mr view --web
  fi
}

main "$@"
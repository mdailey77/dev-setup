#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT"

CONFIG_DIR="$HOME/.config/devops-vscode-profile/lint"
failures=0

command_exists() {
	command -v "$1" >/dev/null 2>&1
}

run_or_fail() {
	local description="$1"
	shift

	echo "==> $description"

	if ! "$@"; then
		echo "FAILED: $description"
		failures=$((failures + 1))
	fi

	echo
}

get_staged_files() {
	git diff --cached --name-only --diff-filter=ACMR
}

filter_by_regex() {
	local regex="$1"
	shift

	local file
	for file in "$@"; do
		if [[ "$file" =~ $regex && -f "$file" ]]; then
			printf '%s\n' "$file"
		fi
	done
}

unique_dirs() {
	local file
	for file in "$@"; do
		dirname "$file"
	done | sort -u
}

staged_files=()
while IFS= read -r file; do
	staged_files+=("$file")
done < <(get_staged_files)

if [[ "${#staged_files[@]}" -eq 0 ]]; then
	exit 0
fi

yaml_files=()
while IFS= read -r file; do
	yaml_files+=("$file")
done < <(filter_by_regex '\.(yaml|yml)$' "${staged_files[@]}")

json_files=()
while IFS= read -r file; do
	json_files+=("$file")
done < <(filter_by_regex '\.(json)$' "${staged_files[@]}")

shell_files=()
while IFS= read -r file; do
	shell_files+=("$file")
done < <(filter_by_regex '\.(sh|bash)$|(^|/)(bashrc|zshrc|profile)$' "${staged_files[@]}")

terraform_files=()
while IFS= read -r file; do
	terraform_files+=("$file")
done < <(filter_by_regex '\.(tf|tfvars)$' "${staged_files[@]}")

markdown_files=()
while IFS= read -r file; do
	markdown_files+=("$file")
done < <(filter_by_regex '\.(md|markdown)$' "${staged_files[@]}")

dockerfiles=()
while IFS= read -r file; do
	dockerfiles+=("$file")
done < <(filter_by_regex '(^|/)Dockerfile$|(^|/)Dockerfile\..+$' "${staged_files[@]}")

ansible_files=()
while IFS= read -r file; do
	ansible_files+=("$file")
done < <(filter_by_regex '(^|/)playbook.*\.(yaml|yml)$|(^|/)roles/.*\.(yaml|yml)$|(^|/)ansible/.*\.(yaml|yml)$' "${staged_files[@]}")

k8s_files=()
while IFS= read -r file; do
	k8s_files+=("$file")
done < <(filter_by_regex '(^|/)(k8s|kubernetes|manifests)/.*\.(yaml|yml)$' "${staged_files[@]}")

contains_file_named() {
	local wanted="$1"
	shift

	local file
	for file in "$@"; do
		if [[ "$(basename "$file")" == "$wanted" ]]; then
			return 0
		fi
	done

	return 1
}

echo "Running global DevOps pre-commit checks..."
echo

if command_exists gitleaks; then
	gitleaks_args=(protect --staged --verbose)
	if [[ -f "$CONFIG_DIR/gitleaks.toml" ]]; then
		gitleaks_args+=(--config "$CONFIG_DIR/gitleaks.toml")
	fi
	run_or_fail "GitLeaks staged secret scan" gitleaks "${gitleaks_args[@]}"
else
	echo "SKIP: gitleaks not installed"
	echo
fi

if [[ "${#yaml_files[@]}" -gt 0 ]]; then
	if command_exists yamllint; then
		if [[ -f "$CONFIG_DIR/yamllint.yml" ]]; then
			run_or_fail "YAML lint" yamllint -c "$CONFIG_DIR/yamllint.yml" "${yaml_files[@]}"
		else
			run_or_fail "YAML lint" yamllint "${yaml_files[@]}"
		fi
	else
		echo "SKIP: yamllint not installed"
		echo
	fi
fi

if [[ "${#json_files[@]}" -gt 0 ]]; then
	if command_exists jsonlint; then
		run_or_fail "JSON lint" jsonlint -q "${json_files[@]}"
	else
		echo "SKIP: jsonlint not installed"
		echo
	fi
fi

if [[ "${#shell_files[@]}" -gt 0 ]]; then
	if command_exists shellcheck; then
		run_or_fail "ShellCheck" shellcheck "${shell_files[@]}"
	else
		echo "SKIP: shellcheck not installed"
		echo
	fi
fi

if [[ "${#terraform_files[@]}" -gt 0 ]]; then
	if command_exists terraform; then
		run_or_fail "Terraform format check" terraform fmt -recursive -check
	else
		echo "SKIP: terraform not installed"
		echo
	fi

	if command_exists tflint; then
		tf_dirs=()
		while IFS= read -r dir; do
			tf_dirs+=("$dir")
		done < <(unique_dirs "${terraform_files[@]}")

		for dir in "${tf_dirs[@]}"; do
			if [[ -d "$dir" ]]; then
				run_or_fail "TFLint: $dir" tflint --chdir="$dir"
			fi
		done
	else
		echo "SKIP: tflint not installed"
		echo
	fi
fi

if [[ "${#markdown_files[@]}" -gt 0 ]]; then
	if command_exists markdownlint-cli2; then
		run_or_fail "Markdown lint" markdownlint-cli2 "${markdown_files[@]}"
	elif command_exists markdownlint; then
		run_or_fail "Markdown lint" markdownlint "${markdown_files[@]}"
	else
		echo "SKIP: markdownlint-cli2 or markdownlint not installed"
		echo
	fi
fi

if [[ "${#dockerfiles[@]}" -gt 0 ]]; then
	if command_exists hadolint; then
		run_or_fail "Hadolint Dockerfile lint" hadolint "${dockerfiles[@]}"
	else
		echo "SKIP: hadolint not installed"
		echo
	fi
fi

if [[ "${#ansible_files[@]}" -gt 0 ]]; then
	if command_exists ansible-lint; then
		run_or_fail "Ansible lint" ansible-lint "${ansible_files[@]}"
	else
		echo "SKIP: ansible-lint not installed"
		echo
	fi
fi

if [[ "${#k8s_files[@]}" -gt 0 ]]; then
	if command_exists kubeconform; then
		run_or_fail "Kubernetes schema validation" kubeconform -strict -summary "${k8s_files[@]}"
	else
		echo "SKIP: kubeconform not installed"
		echo
	fi
fi

if contains_file_named ".gitlab-ci.yml" "${staged_files[@]}"; then
	echo "INFO: .gitlab-ci.yml staged. Local YAML checks ran; GitLab CI Lint API validation is not run globally because it requires project-specific auth and URL configuration."
	echo
fi

if [[ "$failures" -gt 0 ]]; then
	echo "Commit blocked: $failures check(s) failed."
	echo
	echo "Emergency bypass:"
	echo "  git commit --no-verify"
	exit 1
fi

echo "All global DevOps pre-commit checks passed."
exit 0

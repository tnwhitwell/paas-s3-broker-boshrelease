#!/usr/bin/env bash

packaged_release_template=$(cat <<-EOF
---
packaged_release:
    name: bosh-package-golang-release
    repo: https://github.com/cloudfoundry/bosh-package-golang-release.git
    package: golang-1.20-linux
    tag: v0.134.0
EOF
)

function generate_packaged_release_file() {
    filename="${1:-template-vendor-packaging.yml}"
    echo "$packaged_release_template" > "$filename"
}

function do_vendor_packaging() {
    return_value=0
    packaged_release_file="${1:-vendor-packaging.yml}"
    if ! [ -f "$packaged_release_file" ]; then
        generate_packaged_release_file "$packaged_release_file"
        return_value=1
    fi

    VENDOR_REPO="$(yq ".packaged_release.repo" < "$packaged_release_file")"
    VENDOR_TAG="$(yq ".packaged_release.tag" < "$packaged_release_file")"
    export VENDOR_REPO VENDOR_TAG
    LATEST_VENDOR_TAG=$(git -c 'versionsort.suffix=-' ls-remote --exit-code --refs --sort='version:refname' --tags "$VENDOR_REPO" | tail --lines=1 | sed 's:.*refs/tags/::g')
    export LATEST_VENDOR_TAG

    if [[ "$VENDOR_TAG" != "$LATEST_VENDOR_TAG" ]]; then
        yq e -i '.packaged_release.tag = env(LATEST_VENDOR_TAG)' "$packaged_release_file"
        return_value=1
    fi
    echo $return_value
}

function commit_and_push() {
    export GIT_COMMITTER_EMAIL="${1:-github-actions@github.com}"
    export GIT_COMMITTER_NAME="${2:-github-actions}"
    unpriv_username="${3}"
    package_name="${4}"
    repository_name="${5}"
    packaged_release_file="${6:-vendor-packaging.yml}"

    new_branch_name="auto-bump-${package_name}-$(date -u '+%Y%m%dT%H%M')"

    git remote add unpriv-fork "https://github.com/${unpriv_username}/${repository_name}.git"

    git checkout -b "$new_branch_name"

    git add "$packaged_release_file"
    git commit -m "bump ${package_name} version"
    git push unpriv-fork "$new_branch_name"
    echo "$new_branch_name"
}

function create_pr() {
    pr_body_template="${1:-./.github/workflows/automatic_golang_bump_pr_body.md}"
    unpriv_username="${2}"
    new_branch_name="${3}"
    package_name="${4}"

    echo "Creating a PR for branch '${new_branch_name}' with package '${package_name}'"

    FINAL_BODY=$(mktemp)
    envsubst < "$pr_body_template" > "$FINAL_BODY"

    gh pr create \
        --base main \
        --head "${unpriv_username}:${new_branch_name}" \
        --title "${package_name} upgrades, $(date -u '+%B %Y')" \
        --body-file "$FINAL_BODY"
}

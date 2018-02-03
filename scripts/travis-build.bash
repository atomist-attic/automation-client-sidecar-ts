#!/bin/bash
# build and test a node module

set -o pipefail

declare Pkg=travis-build-node-docker
declare Version=0.2.0

# write message to standard out (stdout)
# usage: msg MESSAGE
function msg() {
    echo "$Pkg: $*"
}

# write message to standard error (stderr)
# usage: err MESSAGE
function err() {
    msg "$*" 1>&2
}

# git tag and push
# usage: git-tag TAG[...]
function git-tag () {
    if [[ ! $1 ]]; then
        err "git-tag: missing required argument: TAG"
        return 10
    fi

    if ! git config --global user.email "travis-ci@atomist.com"; then
        err "failed to set git user email"
        return 1
    fi
    if ! git config --global user.name "Travis CI"; then
        err "failed to set git user name"
        return 1
    fi
    local tag
    for tag in "$@"; do
        if ! git tag "$tag" -m "Generated tag from Travis CI build $TRAVIS_BUILD_NUMBER"; then
            err "failed to create git tag: '$tag'"
            return 1
        fi
    done
    local remote=origin
    if [[ $GITHUB_TOKEN ]]; then
        remote=https://$GITHUB_TOKEN:x-oauth-basic@github.com/$TRAVIS_REPO_SLUG.git
    fi
    if ! git push --quiet "$remote" "$@" > /dev/null 2>&1; then
        err "failed to push git tag(s): $*"
        return 1
    fi
}

# create and set a prerelease timestamped, and optionally branched, version
# usage: set-timestamp-version [BRANCH]
function set-timestamp-version () {
    local branch=$1 prerelease
    if [[ $branch && $branch != master ]]; then
        shift
        local safe_branch
        safe_branch=$(echo -n "$branch" | tr -C -s '[:alnum:]-' . | sed -e 's/^[-.]*//' -e 's/[-.]*$//')
        if [[ $? -ne 0 || ! $safe_branch ]]; then
            err "failed to create safe branch name from '$branch': $safe_branch"
            return 1
        fi
        prerelease=$safe_branch.
    fi

    local pkg_version pkg_json=package.json
    pkg_version=$(jq -e --raw-output .version "$pkg_json")
    if [[ $? -ne 0 || ! $pkg_version ]]; then
        err "failed to parse version from $pkg_json"
        return 1
    fi
    local timestamp
    timestamp=$(date -u +%Y%m%d%H%M%S)
    if [[ $? -ne 0 || ! $timestamp ]]; then
        err "failed to generate timestamp"
        return 1
    fi
    local project_version=$pkg_version-$prerelease$timestamp
    if ! npm version --git-tag-version false "$project_version"; then
        err "failed to set package version: $project_version"
        return 1
    fi
}

# npm publish
# usage: npm-publish [NPM_PUBLISH_ARGS]...
function npm-publish () {
    msg "packaging module"
    if ! cp -r build/src/* .; then
        err "packaging module failed"
        return 1
    fi

    # npm honors this
    rm -f .gitignore

    if ! npm publish "$@"; then
        err "failed to publish node module"
        cat "$(ls -t "$HOME"/.npm/_logs/*-debug.log | head -n 1)"
        return 1
    fi

    if ! git checkout -- .gitignore; then
        err "removed .gitignore and was unable to check out original"
        return 1
    fi

    local pub_file pub_base
    for pub_file in build/src/*; do
        pub_base=${pub_file#build/src/}
        rm -rf "$pub_base"
    done
}

# publish a public prerelease version to non-standard registry
# usage: npm-publish-prerelease [BRANCH]
function npm-publish-prerelease () {
    local package_version=$1
    if [[ ! $package_version ]]; then
        err "npm-publish-prerelease: missing required argument: PACKAGE_VERSION"
        return 10
    fi
    shift

    if [[ ! $NPM_REGISTRY ]]; then
        msg "no team NPM registry set"
        return 0
    fi

    msg "publishing NPM module version $package_version"
    if ! npm-publish --registry "$NPM_REGISTRY" --access public; then
        err "failed to publish to Artifactory NPM registry"
        return 1
    fi

    local sha
    if [[ $TRAVIS_PULL_REQUEST_SHA ]]; then
        sha=$TRAVIS_PULL_REQUEST_SHA
    else
        sha=$TRAVIS_COMMIT
    fi

    local module_name pkg_json=package.json
    module_name=$(jq -er .name "$pkg_json")
    if [[ $? -ne 0 || ! $module_name ]]; then
        err "failed to parse NPM module name from $pkg_json"
        return 1
    fi
    local module_url=https://atomist.jfrog.io/atomist/npm-dev/$module_name/-/$module_name-$package_version.tgz
    local status_url=https://api.github.com/repos/$TRAVIS_REPO_SLUG/statuses/$sha
    local post_data
    printf -v post_data '{"state":"success","target_url":"%s","description":"Pre-release NPM module publication","context":"npm/atomist/prerelease"}' "$module_url"
    if ! curl -s -H 'Accept: application/vnd.github.v3+json' \
            -H 'Content-Type: application/json' \
            -H "Authorization: token $GITHUB_TOKEN" \
            -X POST -d "$post_data" "$status_url" > /dev/null
    then
        err "failed to post status on commit: $sha"
        return 1
    fi
    msg "posted module URL $module_url to commit status $status_url"
}

# create and push a Docker image
# usage: docker-push VERSION
function docker-push () {
    local image_version=$1
    if [[ ! $image_version ]]; then
        err "docker-push: missing required argument: VERSION"
        return 10
    fi

    local repo_name=${TRAVIS_REPO_SLUG##*/}

    local registry=sforzando-dockerv2-local.jfrog.io
    if ! docker login -u "$DOCKER_USER" -p "$DOCKER_PASSWORD" "$registry"; then
        err "failed to login to docker registry: $registry"
        return 1
    fi

    local tag=$registry/$repo_name:$image_version
    if ! docker build . -t "$tag"; then
        err "failed to build docker image: '$tag'"
        return 1
    fi

    if ! docker push "$tag"; then
        err "failed to push docker image: '$tag'"
        return 1
    fi

    msg "built and pushed docker image"
}

# usage: main "$@"
function main () {
    local arg ignore_lint
    for arg in "$@"; do
        case "$arg" in
            --ignore-lint | --ignore-lin | --ignore-li | --ignore-l)
                ignore_lint=1
                ;;
            -*)
                err "unknown option: $arg"
                return 2
                ;;
        esac
    done

    msg "running lint"
    local lint_status
    npm run lint
    lint_status=$?
    if [[ $lint_status -eq 0 ]]; then
        :
    elif [[ $lint_status -eq 2 ]]; then
        err "TypeScript failed to pass linting"
        if [[ $ignore_lint ]]; then
            err "ignoring linting failure"
        else
            return 1
        fi
    else
        err "tslint errored"
        return 1
    fi

    msg "compiling TypeScript"
    if ! npm run compile; then
        err "compilation failed"
        return 1
    fi

    msg "running tests"
    if ! npm test; then
        err "test failed"
        return 1
    fi

    [[ $TRAVIS_PULL_REQUEST == false ]] || return 0

    if [[ $TRAVIS_TAG =~ ^[0-9]+\.[0-9]+\.[0-9]+(-(m|rc)\.[0-9]+)?$ ]]; then
        #if ! npm-publish --access public; then
        #    err "failed to publish tag build: '$TRAVIS_TAG'"
        #    return 1
        #fi
        if ! git-tag "$TRAVIS_TAG+travis.$TRAVIS_BUILD_NUMBER"; then
            return 1
        fi
    else
        if ! set-timestamp-version "$TRAVIS_BRANCH"; then
            err "failed to set timestamp version"
            return 1
        fi
        local prerelease_version pkg_json=package.json
        prerelease_version=$(jq -e --raw-output .version "$pkg_json")
        if [[ $? -ne 0 || ! $prerelease_version ]]; then
            err "failed to parse version from $pkg_json: $prerelease_version"
            return 1
        fi
        #if ! npm-publish-prerelease "$prerelease_version"; then
        #    err "failed to publish version '$prerelease_version'"
        #    return 1
        #fi

        if [[ $TRAVIS_BRANCH == master ]]; then
            if ! docker-push "$prerelease_version"; then
                err "failed to build and push docker image"
                return 1
            fi
        fi

        if ! git-tag "$prerelease_version" "$prerelease_version+travis.$TRAVIS_BUILD_NUMBER"; then
            return 1
        fi
    fi
}

main "$@" || exit 1
exit 0

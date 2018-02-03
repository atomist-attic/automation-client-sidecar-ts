#!/bin/bash
# Push the application to Cloud Foundry

set -o pipefail
declare Pkg=cf-push
declare Version=0.1.0

# print message to stdout
# usage: msg MESSAGE
function msg() {
    echo "$Pkg: $*"
}

# print message to stderr
# usage: err MESSAGE
function err() {
    msg "$*" 1>&2
}

# push app to Cloud Foundry
# usage: push [APP_NAME ORG]
function push() {
    local app_name=$1
    if [[ ! $app_name ]]; then
        err "missing required argument: APP_NAME"
        return 10
    fi
    shift
    local org=$1
    if [[ ! $org ]]; then
        err "missing required argument: ORG"
        return 10
    fi
    shift

    msg "pushing '$app_name' to Cloud Foundry space '$org'"

    if ! cf login -u "$CLOUDFOUNDRY_USER" -p "$CLOUDFOUNDRY_PASSWORD" -s "$org" -a https://api.run.pivotal.io; then
        err "failed to login to Cloud Foundry"
        return 1
    fi

    if ! cf delete "$app_name-old" -f; then
        err "failed to delete old application"
        return 1
    fi

    if ! cf push -f "manifest-$org.yml" "$app_name-new"; then
        err "failed to push new application"
        return 1
    fi

    if ! cf rename "$app_name" "$app_name-old"; then
        err "failed to rename current application"
        return 1
    fi

    if ! cf rename "$app_name-new" "$app_name"; then
        err "failed to rename new application"
        return 1
    fi

    if ! cf unmap-route "$app_name" cfapps.io --hostname "$app_name-new"; then
        err "failed to unmap route"
        return 1
    fi

    if ! cf map-route "$app_name" cfapps.io --hostname "$app_name"; then
        err "failed to map route"
        return 1
    fi

    sleep 10

    if ! cf stop "$app_name-old"; then
        err "failed to stop old application"
        return 1
    fi

    cf apps

    return 0
}

# push app to Cloud Foundry
# usage: main [APP_NAME]
function main() {
    local app_name=$1
    if [[ ! $app_name ]]; then
        app_name=${TRAVIS_REPO_SLUG##*/}
    fi

    if [[ $TRAVIS_PULL_REQUEST != false ]] ; then
        return 0
    elif [[ $TRAVIS_TAG =~ ^[0-9]+\.[0-9]+\.[0-9]+(-(m|rc)\.[0-9]+)?$ ]]; then
        if ! push "$app_name" production; then
            err "failed to cf push tag build"
            return 1
        fi
    elif [[ $TRAVIS_BRANCH == master ]]; then
        if ! push "$app_name-staging" development; then
            err "failed to cf push master build"
            return 1
        fi
    fi
}

main "$@" || exit 1
exit 0

#!/usr/bin/env bash

set -e
cd $(dirname "$(realpath "$0")")/../../

USE_SSH_URLS=1

read_github_username() {
    read -p "Please enter your github username (default: rapidsai) " GITHUB_USER </dev/tty
    if [ "$GITHUB_USER" = "" ]; then
        GITHUB_USER="rapidsai";
    fi
}

read_git_remote_url_ssh_preference() {
    while true; do
        read -p "Use SSH in Github remote URLs (y/n)? " SSH_CHOICE </dev/tty
        case $SSH_CHOICE in
            [Yy]* ) USE_SSH_URLS=1; break;;
            [Nn]* ) USE_SSH_URLS=0; break;;
            * ) echo "Please answer 'y' or 'n'";;
        esac
    done
}

ensure_github_cli_is_installed() {
    # Install github cli if it isn't installed
    if [ -z `which hub` ]; then
        GITHUB_VERSION=$(curl -s https://api.github.com/repos/github/hub/releases/latest | jq -r ".tag_name" | tr -d 'v')
        echo "Installing github-cli v$GITHUB_VERSION (https://github.com/github/hub)"
        curl -o ./hub-linux-amd64-${GITHUB_VERSION}.tgz \
            -L https://github.com/github/hub/releases/download/v${GITHUB_VERSION}/hub-linux-amd64-${GITHUB_VERSION}.tgz
        tar -xvzf hub-linux-amd64-${GITHUB_VERSION}.tgz
        sudo ./hub-linux-amd64-${GITHUB_VERSION}/install
        sudo mv ./hub-linux-amd64-${GITHUB_VERSION}/etc/hub.bash_completion.sh /etc/bash_completion.d/hub
        rm -rf ./hub-linux-amd64-${GITHUB_VERSION} hub-linux-amd64-${GITHUB_VERSION}.tgz
    fi
}

clone_or_fork_repo() {
    REPO="$1"
    REPO_RESPONSE_CODE="$(curl -I https://api.github.com/repos/$GITHUB_USER/$REPO 2>/dev/null | head -n 1 | cut -d$' ' -f2)"
    if [ "$REPO_RESPONSE_CODE" = "200" ]; then
        git clone --recurse-submodules https://github.com/$GITHUB_USER/$REPO.git
    else
        git clone --recurse-submodules https://github.com/rapidsai/$REPO.git
        # Fork remote repo if the user doesn't have a fork and if the user isn't "rapidsai"
        if [ "$GITHUB_USER" != "rapidsai" ]; then
            ensure_github_cli_is_installed
            echo "Forking rapidsai/$REPO to $GITHUB_USER/$REPO"
            cd $REPO
            hub fork --remote-name=origin
            cd -
        fi
    fi
    # Fixup remote URLs if user isn't "rapidsai"
    if [ "$GITHUB_USER" != "rapidsai" ]; then
        cd $REPO
        if [ -z "$(git remote show | grep upstream)" ]; then
            git remote add -f upstream https://github.com/rapidsai/$REPO.git
        fi
        if [ "$USE_SSH_URLS" = "1" ]; then
            git remote set-url origin git@github.com:$GITHUB_USER/$REPO.git
            git remote set-url upstream git@github.com:rapidsai/$REPO.git
        fi
        cd -
    fi
}

for REPO in $ALL_REPOS; do
    # Clone if doesn't exist
    if [ ! -d "$PWD/$REPO" ]; then
        if [ "$GITHUB_USER" = "" ]; then
            read_github_username;
            read_git_remote_url_ssh_preference;
        fi
        clone_or_fork_repo $REPO
    fi
done
#!/bin/bash

REPOS=$*

function _find_repo_id()
{
local repo=$1

    smt repos -o -v | grep -i -A 3 $repo | grep ID | cut -d: -f2
}

function _find_mirrorable_repos_by_name()
{
local repo=$1

    smt repos -m | grep -i $repo | cut -d'|' -f5 | sort -u
}

function _enable_repos()
{
local repo=$1

    repos_names=$(_find_mirrorable_repos_by_name $repo)

    for r in $repos_names;
    do
        read -e -p "Enable repo? (y/N) $r: " ANSWER
        [ -z $ANSWER ] && continue
        [ $ANSWER != 'y' ] && continue

        smt repos -e -v $r
    done
}


function mirror_repos()
{
    for repo in $REPOS;
    do
        IDS=$(_find_repo_id $repo)
        # If repo is not found, enable it
        [ -z "$IDS" ] && _enable_repos $repo && IDS=$(_find_repo_id $repo)

        for id in $IDS;
        do
            smt mirror --repository $id
        done
    done
}

if [ -z $REPOS ];
then
    echo "Usage:"
    echo "  $0 [REPOSITORY_NAME]"
    echo "Examples:"
    echo "  $0 SLES12-SP2-Updates SLE-HA12-SP2-Updates"
    echo "  $0 SUSE-Manager-Server-3.0"
    exit 0
fi

mirror_repos


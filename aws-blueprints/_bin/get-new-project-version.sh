#!/usr/bin/env bash
#
# get-new-project-version.sh
#
# Script to calculate and print the new project version.
#
# Examples of possible outputs:
#
# Repo version | Script output
# -------------|--------------
# 20.12.0      | 21.01.0
# 20.12.3      | 21.01.0
# 21.01.0      | 21.01.1
# 21.01.9      | 21.01.10
# 21.01.17     | 21.02.0
#
# Usage:
#
#   ./get-new-project-version.sh 0.39.0
#   DEBUG=1 ./get-new-project-version.sh 21.01.0
#
# Example:
#
#   $ ./get-new-project-version.sh 21.01.0
#   21.01.1
#
##

set -e
set -o pipefail

# Initialize variable
: "${DEBUG:=""}"


debug()
{
    if [[ -n "$DEBUG" ]] ; then
        echo -e "[DEBUG] $*" >&2
    fi
}

print_new_version()
{
    local -r current_version="$1"

    local -r current_major="$( cut -d '.' -f 1 <<< "$current_version" )"
    local -r current_minor="$( cut -d '.' -f 2 <<< "$current_version" )"
    local -r current_patch="$( cut -d '.' -f 3 <<< "$current_version" )"

    # The new major.minor is always the current year.month
    local -r new_major="$( date +'%y' )"
    local -r new_minor="$( date +'%m' )"
    local new_patch

    local new_version

    debug "current_version = $current_version"
    debug "current_major = $current_major"
    debug "current_minor = $current_minor"
    debug "current_patch = $current_patch"

    if [[ "$new_major" == "$current_major" && "$new_minor" == "$current_minor" ]] ; then
        # We're in the same year *and* month of the current version, just bump the patch release
        new_patch="$(( current_patch + 1 ))"
    else
        # Different year and/or month, reset the patch release
        new_patch="0"
    fi

    new_version="${new_major}.${new_minor}.${new_patch}"

    debug "new_version = $new_version"

    # This function returns just the new version
    echo "$new_version"
}

main()
{
    local -r current_version="$1"

    if [[ -z "$1" ]] ; then
        echo "Usage: $0 <current_version>" >&2
        exit 2
    fi

    # Must be set after argument processing
    set -u

    print_new_version "$current_version"
}

main "$@"

#!/usr/bin/env bash
# Finds the revision the pull request merges into and makes sure the history
# between it and HEAD is here, since a default checkout is one commit deep.
#
# In:  BASE         the base input: a commit, or a branch on origin; may be empty
#      PR_BASE_SHA  the pull request's base commit
#      DEPTH        commits of history to fetch when they are missing
# Out: base=<revision> in GITHUB_OUTPUT
set -euo pipefail

base=${BASE:-${PR_BASE_SHA:-}}
if [ -z "$base" ]; then
    echo "::error::There is no base revision: this run is not for a pull request, so set the base input."
    exit 1
fi
depth=${DEPTH:-100}
head=$(git rev-parse HEAD)

if ! git merge-base "$base" "$head" >/dev/null 2>&1; then
    echo "Fetching $depth commits of history to find where $base and this pull request meet."
    # A commit is fetched by its id; a branch by its name on origin.
    git fetch --no-tags --depth="$depth" origin "$base" 2>/dev/null ||
        git fetch --no-tags --depth="$depth" origin "${base#origin/}"
    base=$(git rev-parse --verify --quiet 'FETCH_HEAD^{commit}')
    # The pull request's own side is as shallow as the checkout left it.
    git fetch --no-tags --depth="$depth" origin "$head" 2>/dev/null || true
    if ! git merge-base "$base" "$head" >/dev/null 2>&1; then
        echo "::error::$base and this pull request share no commit within $depth commits. Raise fetch-depth, or check out with fetch-depth: 0."
        exit 1
    fi
fi

echo "base=$base" >>"${GITHUB_OUTPUT:-/dev/null}"

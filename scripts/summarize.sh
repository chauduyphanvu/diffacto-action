#!/usr/bin/env bash
# Compares the pull request with its base: the summary as JSON and the HTML
# report go in one folder, ready to upload, and the comment's text goes to the
# job's summary page.
#
# In:  BASE  the revision the pull request merges into
#      OUT   the folder to write
#      COMMENT_LANG  the language to write in; English if unset
# Out: dir=<OUT> in GITHUB_OUTPUT
set -euo pipefail

out=${OUT:?}
mkdir -p "$out"
lang=(--lang "${COMMENT_LANG:-en}")
diffacto "${lang[@]}" ci --base "${BASE:?}" --head HEAD --format json -o "$out/summary.json" --report "$out/report"
diffacto "${lang[@]}" ci --from "$out/summary.json" >>"${GITHUB_STEP_SUMMARY:-/dev/null}"
echo "dir=$out" >>"${GITHUB_OUTPUT:-/dev/null}"

#!/usr/bin/env bash
# Compares a folder of screenshots with its baseline: the Markdown goes to the
# job's summary page, and the HTML report goes in the folder summarize.sh
# wrote, to be uploaded with the pull request's own.
#
# Screenshots that differ are the finding, not a failure of the step; the
# output says whether there were any.
#
# In:  BASELINE  the folder of approved screenshots
#      CURRENT   the folder of screenshots to check
#      OUT       the folder summarize.sh wrote
#      COMMENT_LANG  the language to write in; English if unset
# Out: changed=true|false in GITHUB_OUTPUT
set -euo pipefail

out=${OUT:?}
mkdir -p "$out"
status=0
diffacto --lang "${COMMENT_LANG:-en}" visual "${BASELINE:?}" "${CURRENT:?}" --format markdown --report "$out/visual-report" >>"${GITHUB_STEP_SUMMARY:-/dev/null}" || status=$?
if [ "$status" -gt 1 ]; then
    exit "$status"
fi
if [ "$status" -eq 1 ]; then
    echo "changed=true" >>"${GITHUB_OUTPUT:-/dev/null}"
else
    echo "changed=false" >>"${GITHUB_OUTPUT:-/dev/null}"
fi

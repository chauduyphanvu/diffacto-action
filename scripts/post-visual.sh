#!/usr/bin/env bash
# Puts the screenshot check on the pull request as a comment of its own, which
# later runs edit. The folders are compared again; that is quick, and the
# comment then links the report that was uploaded.
#
# In:  BASELINE      the folder of approved screenshots
#      CURRENT       the folder of screenshots to check
#      ARTIFACT_URL  where the uploaded report can be opened; may be empty
#      GITHUB_TOKEN  with pull-requests: write
#      COMMENT_LANG  the language to write in; English if unset
set -euo pipefail

args=(--lang "${COMMENT_LANG:-en}" visual "${BASELINE:?}" "${CURRENT:?}" --post github --format markdown -o "${RUNNER_TEMP:-${TMPDIR:-/tmp}}/diffacto-visual-comment.md")
if [ -n "${ARTIFACT_URL:-}" ]; then
    args+=(--artifact-url "$ARTIFACT_URL")
fi
status=0
diffacto "${args[@]}" || status=$?
# Screenshots that differ are what the comment says, not a failed step.
if [ "$status" -gt 1 ]; then
    exit "$status"
fi

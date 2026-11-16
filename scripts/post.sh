#!/usr/bin/env bash
# Puts the summary on the pull request as one comment that later runs edit.
#
# In:  SUMMARY       the summary.json that summarize.sh wrote
#      ARTIFACT_URL  where the uploaded report can be opened; may be empty
#      GITHUB_TOKEN  with pull-requests: write
#      COMMENT_LANG  the language to write in; English if unset
#      FAIL_ON       the rules that put the files they block first in the
#                    comment; may be empty. Failing the job is policy.sh's.
set -euo pipefail

args=(--lang "${COMMENT_LANG:-en}" ci --post github --from "${SUMMARY:?}" -o "${RUNNER_TEMP:-${TMPDIR:-/tmp}}/diffacto-comment.md")
if [ -n "${ARTIFACT_URL:-}" ]; then
    args+=(--artifact-url "$ARTIFACT_URL")
fi
if [ -n "${FAIL_ON:-}" ]; then
    args+=(--fail-on "$FAIL_ON")
fi
status=0
diffacto "${args[@]}" || status=$?
# 1 is a blocked file: the comment is posted, and policy.sh fails the job.
[ "$status" -le 1 ] || exit "$status"

#!/usr/bin/env bash
# Fails the job when the pull request changes what the rules block, after the
# comments are posted. The files it blocks are listed on stderr.
#
# In:  SUMMARY       the summary.json that summarize.sh wrote
#      FAIL_ON       the rules: comma-separated KIND or KIND:WHAT
#      COMMENT_LANG  the language to write in; English if unset
set -euo pipefail

diffacto --lang "${COMMENT_LANG:-en}" ci --from "${SUMMARY:?}" --fail-on "${FAIL_ON:?}" -o /dev/null

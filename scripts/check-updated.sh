#!/bin/bash

# Copyright 2017 Google Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

set -euo pipefail

THIS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
cd "${THIS_DIR}/.."

# Ignore standalone generated header comments (protoc/plugin versions and
# source path) and unified-diff framing lines. Using POSIX ERE (grep -E) with
# LC_ALL=C avoids requiring GNU grep -P (ggrep on macOS), and anchoring comment
# matches to ^[+-]// with token boundaries ensures neither code lines with
# trailing comments nor top-level '// protocol...' comments are ignored.
IGNORE_RE='^([+-]//[[:space:]]+((- )?protoc(-gen-[^[:space:]]+)?([[:space:]]|$)|versions:[[:space:]]*$|source:[[:space:]])|(@@ |diff --git |index [0-9a-f]+\.\.[0-9a-f]+|\+\+\+ (b/|/dev/null)|--- (a/|/dev/null))|$)'

DIFF="$(git --no-pager diff --no-color --no-ext-diff --src-prefix=a/ --dst-prefix=b/ -U0)"

TDIFF=""
if [ -n "${DIFF}" ]; then
  rc=0
  TDIFF="$(LC_ALL=C printf '%s\n' "${DIFF}" | LC_ALL=C grep -v -E -e "${IGNORE_RE}")" || rc=$?
  # grep exits 0 when lines remain (drift detected), 1 when all lines matched
  # IGNORE_RE (clean), and >=2 on regex/invocation error (fail closed).
  if [ "${rc}" -gt 1 ]; then
    printf 'ERROR: grep failed while filtering diff (exit %d)\n' "${rc}" >&2
    exit "${rc}"
  fi
fi

UNTRACKED="$(git ls-files --others --exclude-standard -- v1/proto)"

if [ -n "${TDIFF}" ]; then
  LDIFF="$(LC_ALL=C printf '%s\n' "${TDIFF}" | LC_ALL=C wc -l | LC_ALL=C tr -d '[:space:]')"
else
  LDIFF="0"
fi

printf 'DEBUG(trimmed-diff):  _%s_\n' "${TDIFF}"
printf 'DEBUG(git-diff):      %s\n' "${DIFF}"
printf 'DEBUG(size-of-diff):  %s\n' "${LDIFF}"
if [ -n "${UNTRACKED}" ]; then
  printf 'DEBUG(untracked):     %s\n' "${UNTRACKED}"
fi

if [ "${LDIFF}" != "0" ] || [ -n "${UNTRACKED}" ]; then
  exit 1
fi
exit 0

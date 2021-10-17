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

# Hack to ensure that if we are running on OS X with a homebrew installed
# GNU grep then we can still run sed.
rungrep() {
  if hash ggrep 2>/dev/null; then
    ggrep "$@"
  else
    grep "$@"
  fi
}

LDIFF=`git diff -U0 | rungrep -v -P -e "(//(\s)+protoc|^(@@|diff|index|\+\+\+|\-\-\-)|^$)" | wc -l | tr -d "[:space:]"`
DIFF=`git diff -U0`

echo "DEBUG(git-diff):  $DIFF"
echo "DEBUG(size-of-diff):  $LDIFF"

if [ "$LDIFF" != "0" ]; then
	exit 1
fi
exit 0

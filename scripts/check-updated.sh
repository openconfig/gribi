#!/bin/bash

LDIFF=`git diff -U0 | ggrep -v -P -e "(//(\s)+protoc|^(@@|diff|index|\+\+\+|\-\-\-)|^$)" | wc -l | tr -d "[:space:]"`
DIFF=`git diff -U0`

echo "DEBUG(git-diff):  $DIFF"
echo "DEBUG(size-of-diff):  $LDIFF"

if [ "$LDIFF" != "0" ]; then
	exit 1
fi
exit 0

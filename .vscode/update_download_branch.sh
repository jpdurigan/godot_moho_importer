#!/bin/bash

ORIGIN_BRANCH=main
TARGET_BRANCH=download

git rev-parse --is-inside-work-tree || exit 1

CURRENT_BRANCH=$(git symbolic-ref --short HEAD 2>/dev/null)

git fetch

git checkout $TARGET_BRANCH

git pull

git merge origin/$ORIGIN_BRANCH -m "auto merging branch origin/$ORIGIN_BRANCH"

git rm --cached $(git ls-files -i --exclude-standard -c)

git commit -m "removing unnecessary files"

git push origin $TARGET_BRANCH

git checkout $CURRENT_BRANCH
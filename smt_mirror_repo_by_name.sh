#!/bin/bash

REPOS=$*

for repo in $REPOS;
do
    smt mirror --repository $(smt repos -o -v | grep -A 3 $repo | grep ID | cut -d: -f2)
done


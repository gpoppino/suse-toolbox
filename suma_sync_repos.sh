#!/bin/bash

for repo in $(spacewalk-repo-sync --list | cut -d'|' -f1 | awk 'NR > 3'); 
do  
    spacewalk-repo-sync -c $repo
done

#!/bin/bash

for p in $(zypper lp | cut -d'|' -f2 | grep SUSE); 
do  
    zypper patch-info $p
done | less


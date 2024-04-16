#!/usr/bin/bash

git fetch
git pull
move unresolvable.txt unresolvable.diff
sort -u unresolvable.ipv{4,6} unresolvable.diff -o unresolvable.txt
rm -f unresolvable.{diff,ipv4,ipv6}

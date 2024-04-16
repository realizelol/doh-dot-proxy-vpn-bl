#!/usr/bin/bash

sort -u unresolvable.ipv{4,6} -o unresolvable.txt
rm -f unresolvable.ipv{4,6}

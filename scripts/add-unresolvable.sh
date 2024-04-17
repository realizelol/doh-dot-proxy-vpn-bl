#!/usr/bin/bash

# re-pull current state
git fetch
git pull
if [ ! -f unresolvable.ipv4 ] || [ ! -f unresolvable.ipv6 ]; then
  exit 0 # exit script if not both resolvable version exists
fi
# convert ipv4 + ipv6 to one file: unresolvable.txt
mv unresolvable.txt unresolvable.diff # move -> i/o error
diff -y unresolvable.ipv4 unresolvable.ipv6 | \
  sed -n "/<\|>\||/! s/^\(.*#[1-3]\).*[[:space:]]*.*#[1-3]$/\1/p" \
  > unresolvable.ipv46 # combine ipv4 + ipv6 [ only same lines are valid ]
# sort them uniq with the actual unresolvable.txt
sort -u unresolvable.ipv46 unresolvable.diff -o unresolvable.txt
rm -f unresolvable.{diff,ipv4,ipv6,ipv46}

#!/usr/bin/bash
if [ -z "${1}" ]; then
  param_cnt=1
else
  param_cnt="${1}"
fi
param_delim="50000"
param_end="$(( param_delim - 1 ))"
# split content to domain and counter and check every line
if [ -s unresolvable_perm.txt ]; then
  content_lines="$(grep -cFvxf unresolvable_perm.txt unresolvable.txt)"
else
  content_lines="$(wc -l <unresolvable.txt)"
fi
get_last="$(awk 'BEGIN{for (i=1; i<='"${content_lines}"'; i=i+50000) print i}' | tail -n1)"
get_end="$(( get_last + param_end ))"

# check last 25 commits if unresolvable has changed.
prev_git_commit_no=""
git_cnt=1
while [ -z "${prev_git_commit_no}" ] && [ "${git_cnt}" -ne 25 ]; do
  if git diff --name-status "HEAD~${git_cnt}..HEAD" | grep -q "^M.*unresolvable\.txt$"; then
    prev_git_commit_no="${git_cnt}"
  fi
  git_cnt="$(( git_cnt + 1 ))"
done
# reset if lines < 50000 [ via prev queue ]
changed_lines="$(git diff "HEAD~${prev_git_commit_no}..HEAD" -- unresolvable.txt | grep -c '^-[^--]')"
if [ "${changed_lines}" -ge 1 ]; then
  param_cnt="$(( param_cnt - changed_lines ))"
elif [ "${content_lines}" -le 50000 ]; then
  param_cnt=1
fi

# if param_cnt is <= the last determined line
if [ "${param_cnt}" -le "${get_end}" ]; then

  # if unresolvable_perm.txt+unresolvable.txt is not empty compare the files and output diffrence.
  # elif unresolvable.txt is not empty just output the file content.
  # else exit 0 -> nothing to do.
  { if [ -s unresolvable_perm.txt ] && [ -s unresolvable.txt ]; then
    grep -Fvxf unresolvable_perm.txt unresolvable.txt | sed -n "s/^\(.*\)#\([1-3]\)$/\1\t\2/p";
  elif [ -s unresolvable.txt ]; then
    sed -n "s/^\(.*\)#\([1-3]\)$/\1\t\2/p" unresolvable.txt;
  else exit 0; fi; } | sed -n "${param_cnt},$(( param_cnt + param_end ))p" | while read -r domain cnt; do
    unset dig_cmd cnt_sed
    if [ "${cnt}" -eq 3 ]; then
      # if there's no output on dig then delete line
      dig_cmd="$(dig @9.9.9.10 "${domain}" +short +ignore +notcp +timeout=2 2>/dev/null)"
      if [ -z "${dig_cmd}" ] || echo "${dig_cmd}" | grep -q "^\(0.0.0.0\|127.0.0.1\|::1\|::\)$"; then
        sed -i "/^${domain}#[1-3]$/d" unresolvable.txt
        # and add domain to permanent unresolvable
        if ! grep -q "^${domain}$" unresolvable_perm.txt; then
          echo "${domain}" >> unresolvable_perm.txt
        fi
      else
        # if it was reachable delete from unresolvable
        sed -i "/^${domain}#[1-3]$/d" unresolvable.txt
      fi
    elif [ "${cnt}" -eq 2 ] || [ "${cnt}" -eq 1 ]; then
      # if there's no output on dig then increase(+1) counter of domain
      dig_cmd="$(dig @9.9.9.10 "${domain}" +short +ignore +notcp +timeout=2 2>/dev/null)"
      if [ -z "${dig_cmd}" ] || echo "${dig_cmd}" | grep -q "^\(0.0.0.0\|127.0.0.1\|::1\|::\)$"; then
        cnt_sed="$(( cnt + 1 ))"
        sed -i "s/^\(${domain}#\)[1-3]$/\1${cnt_sed}/g" unresolvable.txt
      else
        # if it was reachable delete from unresolvable
        sed -i "/^${domain}#[1-3]$/d" unresolvable.txt
      fi
    fi
  done

fi

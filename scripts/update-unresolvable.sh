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
  content_lines="$(grep -cvE "$(while read -r line; do echo "^${line}#[1-3]$"; done < unresolvable_perm.txt)" unresolvable.txt)"
else
  content_lines="$(wc -l <unresolvable.txt)"
fi
get_last="$(awk 'BEGIN{for (i=1; i<='"${content_lines}"'; i=i+50000) print i}' | tail -n1)"
get_end="$(( get_last + param_end ))"

if [ "${param_cnt}" -le "${get_end}" ]; then

  { if [ -s "unresolvable_perm.txt" ]; then
    sed -n "s/^\(.*\)#\([1-3]\)$/\1\t\2/p" "unresolvable.txt" | \
      grep -vE "$(while read -r line; do echo -e "^${line}\t[1-3]$"; done < "unresolvable_perm.txt")";
  else
    sed -n "s/^\(.*\)#\([1-3]\)$/\1\t\2/p" "unresolvable.txt";
  fi; } | sed -n "${param_cnt},$(( param_cnt + param_end ))p" | while read -r domain cnt; do
    unset dig_cmd cnt_sed
    if [ "${cnt}" -eq 3 ]; then
      # if there's no output on dig then delete line
      dig_cmd="$(dig @9.9.9.10 "${domain}" +short +ignore +notcp +timeout=2 2>/dev/null)"
      if [ -z "${dig_cmd}" ] || echo "${dig_cmd}" | grep -q "^\(0.0.0.0\|127.0.0.1\|::1\|::\)$"; then
        sed -i "/^${domain}#[1-3]$/d" "unresolvable.txt"
        # and add domain to permanent unresolvable
        if ! grep -q "^${domain}$" "unresolvable_perm.txt"; then
          echo "${domain}" >> "unresolvable_perm.txt"
        fi
      else
        # if it was reachable delete from unresolvable
        sed -i "/^${domain}#[1-3]$/d" "unresolvable.txt"
      fi
    elif [ "${cnt}" -eq 2 ] || [ "${cnt}" -eq 1 ]; then
      # if there's no output on dig then increase(+1) counter of domain
      dig_cmd="$(dig @9.9.9.10 "${domain}" +short +ignore +notcp +timeout=2 2>/dev/null)"
      if [ -z "${dig_cmd}" ] || echo "${dig_cmd}" | grep -q "^\(0.0.0.0\|127.0.0.1\|::1\|::\)$"; then
        cnt_sed="$(( cnt + 1 ))"
        sed -i "s/^\(${domain}#\)[1-3]$/\1${cnt_sed}/g" "unresolvable.txt"
      else
        # if it was reachable delete from unresolvable
        sed -i "/^${domain}#[1-3]$/d" "unresolvable.txt"
      fi
    fi
  done

fi

# cleanup
rm -f "unresolvable.txt"
rm -f "unresolvable_perm.txt"

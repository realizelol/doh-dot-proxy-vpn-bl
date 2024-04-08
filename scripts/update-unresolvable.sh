#!/usr/bin/bash
if [ -z "${1}" ]; then
  param_cnt=1
else
  param_cnt="${1}"
fi
param_delim="50000"
param_end="$(( param_delim - 1 ))"
# split content to domain and counter and check every line
content_lines="$(grep -cvE "$(while read -r line; do echo "^${line}#[1-3]$"; done < unresolvable_perm.txt)" unresolvable.txt)"
sed_begin=(); for i in $(seq "${param_cnt}" "${param_delim}" "${content_lines}"); do sed_begin+=( "${i}" ); done
sed_end="$(( "${sed_begin[-1]}" + param_end ))"

cp "unresolvable.txt" "unresolvable_${param_cnt}.txt"
cp "unresolvable_perm.txt" "unresolvable_perm_${param_cnt}.txt"

if [ "${param_cnt}" -le "${sed_end}" ]; then

  { sed -n "s/^\(.*\)#\([1-3]\)$/\1\t\2/p" "unresolvable_${param_cnt}.txt" | \
  grep -vE "$(while read -r line; do echo -e "^${line}\t[1-3]$"; done < "unresolvable_perm_${param_cnt}.txt")"; \
  } | sed -n "${param_cnt},$(( param_cnt + param_delim ))p" | while read -r domain cnt; do
    if [ "${cnt}" -eq 3 ]; then
      # if there's no output on dig then delete line
      if [ -z "$(dig @8.8.8.8 "${domain}" +short +ignore +notcp +tries=3 +timeout=1)" ]; then
        sed -i "/^${domain}#[1-3]$/d" "unresolvable_${param_cnt}.txt"
        # and add domain to permanent unresolvable
        if ! grep -q "^${domain}$" "unresolvable_perm_${param_cnt}.txt"; then
          echo "${domain}" >> "unresolvable_perm_${param_cnt}.txt"
        fi
      else
        # if it was reachable delete from unresolvable
        sed -i "/^${domain}#[1-3]$/d" "unresolvable_${param_cnt}.txt"
      fi
    fi
    if [ "${cnt}" -eq 2 ] || [ "${cnt}" -eq 1 ]; then
      # if there's no output on dig then increase(+1) counter of domain
      if [ -z "$(dig @8.8.8.8 "${domain}" +short +ignore +notcp +tries=3 +timeout=1)" ]; then
        cnt_sed="$(( cnt + 1 ))"
        sed -i "s/^\(${domain}#\)[1-3]$/\1${cnt_sed}/g" "unresolvable_${param_cnt}.txt"
      fi
    else
      # if it was reachable delete from unresolvable
      sed -i "/^${domain}#[1-3]$/d" "unresolvable_${param_cnt}.txt"
    fi
  done

  # check for changes
  git fetch
  git pull
  diff -u "unresolvable.txt" "unresolvable_${param_cnt}.txt" \
    | grep '^-' | sed -e "s/^-*//g" -e "/unresolvable_.*.txt/d" \
    | while read -r change_unresolvable; do
      sed -i "s|^${change_unresolvable//#*}#[1-3]$|${change_unresolvable}|g" \
        "unresolvable.txt"
    done
  diff -u "unresolvable_perm.txt" "unresolvable_perm_${param_cnt}.txt" \
    | grep '^-' | sed -e "s/^-*//g" -e "/unresolvable_.*.txt/d" \
    | while read -r change_unresolvable_perm; do
      sed -i "s|^${change_unresolvable_perm//#*}#[1-3]$|${change_unresolvable_perm}|g" \
        "unresolvable_perm.txt"
    done

fi

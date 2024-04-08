#!/usr/bin/bash
if [ -z "${1}" ]; then
  param_cnt=1
else
  param_cnt="${1}"
fi
# split content to domain and counter and check every line
content_lines="$(wc -l <unresolvable.txt)"
sed_begin="$(seq "${param_cnt}" "50000" "${content_lines}")"
sed_end="$(( $(echo "${sed_begin}" | tail -n1) + "49999" ))"

cp "unresolvable.txt" "unresolvable_${param_cnt}.txt"
cp "unresolvable_perm.txt" "unresolvable_perm_${param_cnt}.txt"

if [ "${param_cnt}" -lt "${sed_end}" ]; then

  echo "${sed_begin}" | while read -r sed_line; do
    sed -n "s/^\(.*\)#\([1-3]\)$/\1\t\2/p" "unresolvable_${param_cnt}.txt" | \
    sed -n "${sed_line},$(( sed_line + 49999 ))p" | while read -r domain cnt; do
      if [ "${cnt}" -eq 3 ]; then
        # if there's no output on dig then delete line
        if [ -z "$(dig @8.8.8.8 "${domain}" +short +ignore +notcp +tries=3 +timeout=1)" ]; then
          sed -i "/^${domain}#[1-3]$/d" "unresolvable_${param_cnt}.txt"
          # and add domain to permanent unresolvable
          if ! grep -q "${domain}" "unresolvable_perm_${param_cnt}.txt"; then
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
  done

  # check for changes
  git fetch
  git pull
  diff -u "unresolvable.txt" "unresolvable_${param_cnt}.txt" \
    | grep '^-' | sed -e "s/^-*//g" -e "/unresolvable_.*.txt/d" \
    | while read -r change_unresolvable; do
      sed -i "s|${change_unresolvable//#*}.*|${change_unresolvable}|g" \
        "unresolvable.txt"
    done
  diff -u "unresolvable_perm.txt" "unresolvable_perm_${param_cnt}.txt" \
    | grep '^-' | sed -e "s/^-*//g" -e "/unresolvable_.*.txt/d" \
    | while read -r change_unresolvable_perm; do
      sed -i "s|${change_unresolvable_perm//#*}.*|${change_unresolvable_perm}|g" \
        "unresolvable_perm.txt"
    done

fi

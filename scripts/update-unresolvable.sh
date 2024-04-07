#!/usr/bin/bash
param_cnt="${1}"

# split content to domain and counter and check every line
content_lines="$(wc -l <unresolvable.txt)"
sed_begin="$(seq "${param_cnt}" "50000" "${content_lines}")"
sed_end="$(( $(seq "${param_cnt}" "50000" "${content_lines}" | tail -n1) + "49999" ))"

if [ "${content_lines}" -lt "${sed_end}" ] && [ "${content_lines}" -gt "${sed_begin}" ]; then

  echo "${sed_begin}" | while read -r sed_line; do
    sed -n "s/^\(.*\)#\([1-3]\)$/\1\t\2/p" unresolvable.txt | \
    sed -n "${sed_line},$(( sed_line + 49999 ))p" | while read -r domain cnt; do
      if [ "${cnt}" -eq 3 ]; then
        # if there's no output on dig then delete line
        if [ -z "$(dig "${domain}" +short +ignore +notcp +tries=3 +timeout=1)" ]; then
          sed -i "/^${domain}#[1-3]$/d" unresolvable.txt
          # and add domain to permanent unresolvable
          if ! grep -q "${domain}" unresolvable_perm.txt; then
            echo "${domain}" >> unresolvable_perm.txt
          fi
        else
          # if it was reachable delete from unresolvable
          sed -i "/^${domain}#[1-3]$/d" unresolvable.txt
        fi
      fi
      if [ "${cnt}" -eq 2 ] || [ "${cnt}" -eq 1 ]; then
        # if there's no output on dig then increase(+1) counter of domain
        if [ -z "$(dig "${domain}" +short +ignore +notcp +tries=3 +timeout=1)" ]; then
          cnt_sed="$(( cnt + 1 ))"
          sed -i "s/^\(${domain}#\)[1-3]$/\1${cnt_sed}/g" unresolvable.txt
        fi
      else
        # if it was reachable delete from unresolvable
        sed -i "/^${domain}#[1-3]$/d" unresolvable.txt
      fi
    done
  done

fi

#!/usr/bin/bash
ipregex='(([0-9a-fA-F]{1,4}:){7,7}[0-9a-fA-F]{1,4}|([0-9a-fA-F]{1,4}:){1,7}:|([0-9a-fA-F]{1,4}:){1,6}:[0-9a-fA-F]{1,4}|\
  ([0-9a-fA-F]{1,4}:){1,5}(:[0-9a-fA-F]{1,4}){1,2}|([0-9a-fA-F]{1,4}:){1,4}(:[0-9a-fA-F]{1,4}){1,3}|\
  ([0-9a-fA-F]{1,4}:){1,3}(:[0-9a-fA-F]{1,4}){1,4}|([0-9a-fA-F]{1,4}:){1,2}(:[0-9a-fA-F]{1,4}){1,5}|\
  [0-9a-fA-F]{1,4}:((:[0-9a-fA-F]{1,4}){1,6})|:((:[0-9a-fA-F]{1,4}){1,7}|:)|fe80:(:[0-9a-fA-F]{0,4}){0,4}%[0-9a-zA-Z]{1,}|\
  ::(ffff(:0{1,4}){0,1}:){0,1}((25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])\.){3,3}(25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])|\
  ([0-9a-fA-F]{1,4}:){1,4}:((25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])\.){3,3}(25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9]))'
ip4regex="((25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])\.){3,3}(25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])"
ip6regex="${ipregex//[[:space:]]/}"

if [ "${1}" == "IPv4" ]; then
  ipv4=(); while read -r dns2ip_v4; do
    dig4="$(dig @8.8.8.8 "${dns2ip_v4}" in A -4 +short +ignore +notcp +timeout=2 2>/dev/null)"
    if [ -n "${dig4}" ] && ! echo "${dig4}" | grep -q "^0\.0\.0\.0\|^127\.0\.0\.1$\|^;"; then
      ipv4+=( "${dig4}" )
    fi
  done < <(grep -vE "^$(sed -e '/^#.*/d' -e 's/\s*#.*$//g' -e 's/[[:space:]]//g' white.txt)$" black.txt)
  if [ "$(echo "${ipv4[*]}" | sed "s/ /\n/g" | sort -Vu | grep -coE "${ip4regex}")" -ge 100 ]; then
    for ip in "${ipv4[@]}"; do
      echo "${ip}" >> black-tmp.ipv4
    done
  fi

  # check for changes
  git fetch
  git pull

  # create whitelist IPv4
  white_sed_4="$(sed "s/${ip4regex}\)[[:space:]]#.*/\1/g" white.txt)"
  while read -r subnet4; do
    white_ip4s="$(nmap -sL -n "${subnet4}" | awk '/Nmap scan report/{print$NF}')"
    for wip4 in "${white_ip4s[@]}"; do white_sed_4+=( "${wip4}" ); done
    white_sed_4=("${white_sed_4[@]/$subnet4}")
  done < <(echo "${white_sed_4}" | grep '/[0-9]{1,3}')
  white_grep_4="$(printf '^%s\$|' "${white_sed_4[@]}")"

  # create new black.ipv4
  grep -oE "${ip4regex}" black-tmp.ipv4 | sort -Vu | sed '/^$/d' | grep -E "${white_grep_4//|$/}"                    | \
    grep -vE "(^10\.|^169\.254\.|^172\.(1[6-9]|2[0-9]|3[0-1])\.|^192\.168\.|^22[4-9]\.|^23[0-9]\.|^2[4-5][0-9]\.)"   | \
    grep -vE "(^192\.88\.99\.|^198\.51\.100\.|^203\.0\.113\.|^100\.6[4-9]\.|^100\.[7-9][0-9]\.|^100\.1[0-2][0-7]\.)" | \
    grep -vE "(^192\.31\.196\.|192\.52\.193\.|192\.175\.48\.|^192\.0\.(0|2)\.|^198\.1[8-9]\.0\.|^255\.255\.255\.255)"  \
    > black.ipv4
  # cleanup
  rm -f black-tmp.ipv4
  unset ipv4 dig4 white_sed_4 subnet4 white_ip4s wip4 white_sed_4 white_grep_4
fi
if [ "${1}" == "IPv6" ]; then
  ipv6=(); while read -r dns2ip_v6; do
    dig6="$(dig @8.8.8.8 "${dns2ip_v6}" in AAAA -4 +short +ignore +notcp +timeout=2 2>/dev/null)"
    if [ -n "${dig6}" ] && ! echo "${dig6}" | grep -q "^::$\|^::1$\|^53:$\|^;"; then
      ipv6+=( "${dig6}" )
    fi
  done < <(grep -vE "^$(sed -e '/^#.*/d' -e 's/\s*#.*$//g' -e 's/[[:space:]]//g' white.txt)$" black.txt)
  if [ "$(echo "${ipv6[*]}" | sed "s/ /\n/g" | sort -Vu | grep -coE "${ip6regex}")" -ge 100 ]; then
    for ip in "${ipv6[@]}"; do
      echo "${ip}" >> black-tmp.ipv6
    done
  fi

  # check for changes
  git fetch
  git pull

  # create whitelist IPv6
  white_sed_6="$(sed "s/${ip6regex}\)[[:space:]]#.*/\1/g" white.txt)"
  while read -r subnet6; do
    white_ip6s="$(nmap -sL -n "${subnet6}" | awk '/Nmap scan report/{print$NF}')"
    for wip6 in "${white_ip6s[@]}"; do white_sed_6+=( "${wip6}" ); done
    white_sed_6=("${white_sed_6[@]/$subnet6}")
  done < <(echo "${white_sed_6}" | grep '/[0-9]{1,3}')
  white_grep_6="$(printf '^%s\$|' "${white_sed_6[@]}")"

  # create new black.ipv6
  grep -oE "${ip6regex}" black-tmp.ipv6 | sort -Vu | sed '/^$/d' | grep -E "${white_grep_6//|$/}"        | \
    grep -vE "(^::$|^::ffff:|^64:ff9b:(0|1):|^100:|^2001:0|^2001:[1-3]0?:0|^2001:4:112:|^2001:db8:)"     | \
    grep -vE "(^2002:|^2620:4f:8000:|^f[c-d][0-9a-f][0-9a-f]:|^fe[8-9a-b][0-9a-f]:|^ff[0-9a-f][0-9a-f]:)"  \
    > black.ipv6
  # cleanup
  rm -f black-tmp.ipv6
  unset ipv6 dig6 white_sed_6 subnet6 white_ip6s wip6 white_sed_6 white_grep_6
fi

#!/usr/bin/bash
ipregex='(([0-9a-fA-F]{1,4}:){7,7}[0-9a-fA-F]{1,4}|([0-9a-fA-F]{1,4}:){1,7}:|([0-9a-fA-F]{1,4}:){1,6}:[0-9a-fA-F]{1,4}|\
  ([0-9a-fA-F]{1,4}:){1,5}(:[0-9a-fA-F]{1,4}){1,2}|([0-9a-fA-F]{1,4}:){1,4}(:[0-9a-fA-F]{1,4}){1,3}|\
  ([0-9a-fA-F]{1,4}:){1,3}(:[0-9a-fA-F]{1,4}){1,4}|([0-9a-fA-F]{1,4}:){1,2}(:[0-9a-fA-F]{1,4}){1,5}|\
  [0-9a-fA-F]{1,4}:((:[0-9a-fA-F]{1,4}){1,6})|:((:[0-9a-fA-F]{1,4}){1,7}|:)|fe80:(:[0-9a-fA-F]{0,4}){0,4}%[0-9a-zA-Z]{1,}|\
  ::(ffff(:0{1,4}){0,1}:){0,1}((25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])\.){3,3}(25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])|\
  ([0-9a-fA-F]{1,4}:){1,4}:((25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])\.){3,3}(25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9]))'
ip4regex="((25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])\.){3,3}(25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])"
ip6regex="${ipregex//[[:space:]]/}"

if [ "${1:-}" == "IPv4" ]; then
  ipv4=(); while read -r dns2ip_v4; do
    dig4="$(dig "${dns2ip_v4}" in A -4 +short +ignore +notcp +timeout=2 2>/dev/null || true)"
    if [ -n "${dig4}" ] && ! echo "${dig4}" | grep -q "^0\.0\.0\.0\|^127\.0\.0\.1$\|^;"; then
      ipv4+=( "${dig4}" )
    fi
  done < <(grep -vE "^$(sed -e '/^#.*/d' -e 's/\s*#.*$//g' -e 's/[[:space:]]//g' white.txt)$" black.txt)
  if [ "$(echo "${ipv4[*]}" | sed "s/ /\n/g" | sort -Vu | grep -coE "${ip4regex}")" -ge 100 ]; then
    true >> black.ipv4
    for ip in "${ipv4[@]}"; do
      echo "${ip}" >> black-tmp.ipv4
    done
  fi
  grep -oE "${ip4regex}" black-tmp.ipv4 | sort -Vu | sed '/^$/d'                                                     | \
    grep -vE "(^10\.|^169\.254\.|^172\.(1[6-9]|2[0-9]|3[0-1])\.|^192\.168\.|^22[4-9]\.|^23[0-9]\.|^2[4-5][0-9]\.)"   | \
    grep -vE "(^192\.88\.99\.|^198\.51\.100\.|^203\.0\.113\.|^100\.6[4-9]\.|^100\.[7-9][0-9]\.|^100\.1[0-2][0-7]\.)" | \
    grep -vE "(^192\.31\.196\.|192\.52\.193\.|192\.175\.48\.|^192\.0\.(0|2)\.|^198\.1[8-9]\.0\.|^255\.255\.255\.255)"  \
      >> black.ipv4; rm -f black-tmp.ipv4
fi
if [ "${1:-}" == "IPv6" ]; then
  ipv6=(); while read -r dns2ip_v6; do
    dig6="$(dig "${dns2ip_v6}" in AAAA -4 +short +ignore +notcp +timeout=2 2>/dev/null || true)"
    if [ -n "${dig6}" ] && ! echo "${dig6}" | grep -q "^::$\|^::1$\|^53:$\|^;"; then
      ipv6+=( "${dig6}" )
    fi
  done < <(grep -vE "^$(sed -e '/^#.*/d' -e 's/\s*#.*$//g' -e 's/[[:space:]]//g' white.txt)$" black.txt)
  if [ "$(echo "${ipv6[*]}" | sed "s/ /\n/g" | sort -Vu | grep -coE "${ip6regex}")" -ge 100 ]; then
    true > black.ipv6
    for ip in "${ipv6[@]}"; do
      echo "${ip}" >> black-tmp.ipv6
    done
  fi
  grep -oE "${ip6regex}" black-tmp.ipv6 | sort -Vu | sed -e '/^$/d' -e '/^::$/d'                        | \
    grep -vE "(^::ffff:|^64:ff9b:(0|1):|^100:|^2001:0|^2001:[1-3]0?:0|^2001:4:112:|^2001:db8:)"         | \
    grep -vE "(^2002:|^2620:4f:8000:|^f[c-d][0-9a-f][0-9a-f]:|^fe[8-9a-b][0-9a-f]:|^ff[0-9a-f][0-9a-f]:)" \
    >> black.ipv6; rm -f black-tmp.ipv6
fi

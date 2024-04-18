#!/usr/bin/bash

# ip4 + ipv6 regex check
ipregex='(([0-9a-fA-F]{1,4}:){7,7}[0-9a-fA-F]{1,4}|([0-9a-fA-F]{1,4}:){1,7}:|([0-9a-fA-F]{1,4}:){1,6}:[0-9a-fA-F]{1,4}|\
  ([0-9a-fA-F]{1,4}:){1,5}(:[0-9a-fA-F]{1,4}){1,2}|([0-9a-fA-F]{1,4}:){1,4}(:[0-9a-fA-F]{1,4}){1,3}|\
  ([0-9a-fA-F]{1,4}:){1,3}(:[0-9a-fA-F]{1,4}){1,4}|([0-9a-fA-F]{1,4}:){1,2}(:[0-9a-fA-F]{1,4}){1,5}|\
  [0-9a-fA-F]{1,4}:((:[0-9a-fA-F]{1,4}){1,6})|:((:[0-9a-fA-F]{1,4}){1,7}|:)|fe80:(:[0-9a-fA-F]{0,4}){0,4}%[0-9a-zA-Z]{1,}|\
  ::(ffff(:0{1,4}){0,1}:){0,1}((25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])\.){3,3}(25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])|\
  ([0-9a-fA-F]{1,4}:){1,4}:((25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])\.){3,3}(25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9]))'
ip4regex="((25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])\.){3,3}(25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])"
ip6regex="${ipregex//[[:space:]]/}"

if [ "${1}" == "IPv4" ]; then

  # get ip4s of domains
  ipv4=(); while read -r dns2ip_v4; do
    dig4=(); while read -r dig2ip_v4; do
      if [ -n "${dig2ip_v4}" ]; then
        dig4+=( "${dig2ip_v4}" )
      else
        if ! grep -q "${dns2ip_v4}" unresolvable.txt && ! grep -q "${dns2ip_v4}" _white.txt; then
          echo "${dns2ip_v4}#1" >> unresolvable.ipv4
        fi
      fi
    done < <(dig @9.9.9.10 "${dns2ip_v4}" in A -4 +short +ignore +notcp +timeout=2 2>/dev/null)
    if [ -n "${dig4[*]}" ]; then
      while read -r dig_ip4; do
        if ! echo "${dig_ip4}" | grep -q "^0\.0\.0\.0\|^127\.0\.0\.1$\|^;"; then
          ipv4+=( "${dig_ip4}" )
        fi
      done < <(printf '%s\n' "${dig4[@]}")
    fi
  done < <(grep -Fvxf <(sed -e '/^#.*/d' -e 's/[[:space:]]*#.*$//g' -e 's/[[:space:]]*//g' _white.txt) black.txt)
  if [ "$(echo "${ipv4[*]}" | sed "s/ /\n/g" | sort -Vu | grep -coE "${ip4regex}")" -ge 100 ]; then
    for ip in "${ipv4[@]}"; do
      echo "${ip}" >> black-tmp.ipv4
    done
  fi

  # check for changes
  git fetch
  git pull

  # create whitelist IPv4
  white_sed_4=()
  while read -r wip4; do
    white_sed_4+=( "${wip4}" )
  done < <(sed -nr "s%^(${ip4regex})[[:space:]]*#.*%\1%p" _white.txt)
  while read -r wsubnet4; do
    white_ip4s="$(python3 scripts/cidr2ip.py "${wsubnet4}")"
  done < <(sed -nr "s%^(${ip4regex}/[0-9]{1,2})[[:space:]]*#.*%\1%p" _white.txt)
  while read -r wip4; do white_sed_4+=( "${wip4}" ); done < <(printf '%s\n' "${white_ip4s[@]}")
  printf '%s\n' "${white_sed_4[@]}" | sed '/^$/d' > "white_sed_4.txt"

  # create blacklist IPv4
  black_sed_4=()
  while read -r bip4; do
    black_sed_4+=( "${bip4}" )
  done < <(sed -nr "s%^(${ip4regex})[[:space:]]*#.*%\1%p" _black.ipv4)
  while read -r bsubnet4; do
    black_ip4s="$(python3 scripts/cidr2ip.py "${bsubnet4}")"
  done < <(sed -nr "s%^(${ip4regex}/[0-9]{1,2})[[:space:]]*#.*%\1%p" _black.ipv4)
  while read -r bip4; do black_sed_4+=( "${bip4}" ); done < <(printf '%s\n' "${black_ip4s[@]}")
  printf '%s\n' "${black_sed_4[@]}" | sed '/^$/d' > "black_sed_4.txt"

  # create new black.ipv4
  grep -Fvxf white_sed_4.txt black-tmp.ipv4 | grep -oE "${ip4regex}" | sort -Vu | sed '/^$/d'                        | \
    grep -vE "(^10\.|^169\.254\.|^172\.(1[6-9]|2[0-9]|3[0-1])\.|^192\.168\.|^22[4-9]\.|^23[0-9]\.|^2[4-5][0-9]\.)"   | \
    grep -vE "(^192\.88\.99\.|^198\.51\.100\.|^203\.0\.113\.|^100\.6[4-9]\.|^100\.[7-9][0-9]\.|^100\.1[0-2][0-7]\.)" | \
    grep -vE "(^192\.31\.196\.|192\.52\.193\.|192\.175\.48\.|^192\.0\.(0|2)\.|^198\.1[8-9]\.0\.|^255\.255\.255\.255)"  \
    > black.tmp4
  sort -Vu black.tmp4 black_sed_4.txt -o black.ipv4
  # cleanup
  rm -f black-tmp.ipv4 white_sed_4.txt black_sed_4.txt black.tmp4
  unset ipv4 dig4 white_sed_4 wsubnet4 white_ip4s wip4 black_sed_4 bsubnet4 black_ip4s bip4
fi
if [ "${1}" == "IPv6" ]; then

  # get ip6s of domains
  ipv6=(); while read -r dns2ip_v6; do
    dig6=(); while read -r dig2ip_v6; do
      if [ -n "${dig2ip_v6}" ]; then
        dig6+=( "${dig2ip_v6}" )
      else
        if ! grep -q "${dns2ip_v6}" unresolvable.txt && ! grep -q "${dns2ip_v6}" _white.txt; then
          echo "${dns2ip_v6}#1" >> unresolvable.ipv6
        fi
      fi
    done < <(dig @9.9.9.10 "${dns2ip_v6}" in AAAA -4 +short +ignore +notcp +timeout=2 2>/dev/null)
    if [ -n "${dig6[*]}" ]; then
      while read -r dig_ip6; do
        if ! echo "${dig_ip6}" | grep -q "^::$\|^::1$\|^53:$\|^;"; then
          ipv6+=( "${dig_ip6}" )
        fi
      done < <(printf '%s\n' "${dig6[@]}")
    fi
  done < <(grep -Fvxf <(sed -e '/^#.*/d' -e 's/[[:space:]]*#.*$//g' -e 's/[[:space:]]*//g' _white.txt) black.txt)
  if [ "$(echo "${ipv6[*]}" | sed "s/ /\n/g" | sort -Vu | grep -coE "${ip6regex}")" -ge 100 ]; then
    for ip6 in "${ipv6[@]}"; do
      echo "${ip6}" >> black-tmp.ipv6
    done
  fi

  # check for changes
  git fetch
  git pull

  # create whitelist IPv6
  white_sed_6=()
  while read -r wip6; do
    white_sed_6+=( "${wip6}" )
  done < <(sed -nr "s%^(${ip6regex})[[:space:]]*#.*%\1%p" _white.txt)
  while read -r wsubnet6; do
    white_ip6s="$(python3 scripts/cidr2ip.py "${wsubnet6}")"
  done < <(sed -nr "s%^(${ip6regex}/[0-9]{1,3})[[:space:]]*#.*%\1%p" _white.txt)
  while read -r wip6; do white_sed_6+=( "${wip6}" ); done < <(printf '%s\n' "${white_ip6s[@]}")
  printf '%s\n' "${white_sed_6[@]}" | sed '/^$/d' > "white_sed_6.txt"

  # create blacklist IPv6
  black_sed_6=()
  while read -r bip6; do
    black_sed_6+=( "${bip6}" )
  done < <(sed -nr "s%^(${ip6regex})[[:space:]]*#.*%\1%p" _black.ipv6)
  while read -r bsubnet6; do
    black_ip6s="$(python3 scripts/cidr2ip.py "${bsubnet6}")"
  done < <(sed -nr "s%^(${ip6regex}/[0-9]{1,3})[[:space:]]*#.*%\1%p" _black.ipv6)
  while read -r bip6; do black_sed_6+=( "${bip6}" ); done < <(printf '%s\n' "${black_ip6s[@]}")
  printf '%s\n' "${black_sed_6[@]}" | sed '/^$/d' > "black_sed_6.txt"

  # create new black.ipv6
  grep -Fvxf white_sed_6.txt black-tmp.ipv6 | grep -oE "${ip6regex}" | sort -Vu | sed '/^$/d'            | \
    grep -vE "(^::$|^::ffff:|^64:ff9b:(0|1):|^100:|^2001:0|^2001:[1-3]0?:0|^2001:4:112:|^2001:db8:)"     | \
    grep -vE "(^2002:|^2620:4f:8000:|^f[c-d][0-9a-f][0-9a-f]:|^fe[8-9a-b][0-9a-f]:|^ff[0-9a-f][0-9a-f]:)"  \
    > black.tmp6
  sort -Vu black.tmp6 black_sed_6.txt -o black.ipv6
  # cleanup
  rm -f black-tmp.ipv6 white_sed_6.txt black_sed_6.txt black.tmp6
  unset ipv6 dig6 white_sed_6 wsubnet6 white_ip6s wip6 black_sed_6 bsubnet6 black_ip6s bip6
fi

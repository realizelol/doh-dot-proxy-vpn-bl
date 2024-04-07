#!/usr/bin/bash
# shellcheck disable=2091

( ( ( \
      curl -sL --connect-timeout 5 --max-time 60 --retry 5 --retry-delay 10 --retry-max-time 300 \
          https://raw.githubusercontent.com/dnswarden/dnswarden.github.io/main/index.html 2>/dev/null | \
          awk -F'"' '/data-clipboard-text=/{print$4}' | sed -e "s|.*//||g" -e "s|/.*||g" | sort -u; \
      curl -sL --connect-timeout 5 --max-time 60 --retry 5 --retry-delay 10 --retry-max-time 300 \
          https://raw.githubusercontent.com/jpgpi250/piholemanual/master/DOH.rpz 2>/dev/null | \
          sed '/^\(;\|\$\|@\|\s\)/d' | sed "s/\sCNAME\s\.//g"; \
      curl -sL --connect-timeout 5 --max-time 60 --retry 5 --retry-delay 10 --retry-max-time 300 \
          https://raw.githubusercontent.com/oneoffdallas/dohservers/master/list.txt \
          https://raw.githubusercontent.com/olbat/ut1-blacklists/master/blacklists/doh/domains \
          https://raw.githubusercontent.com/dibdot/doh-ip-blocklists/master/doh-domains.txt \
          https://raw.githubusercontent.com/cbuijs/accomplist/master/doh/plain.black.hosts.list \
          https://raw.githubusercontent.com/cbuijs/accomplist/master/doh/plain.black.top-n.domain.list \
          https://gist.githubusercontent.com/ckuethe/f71185f604be9cde370e702aa179fc2e/raw/doh-blocklist.txt \
          https://raw.githubusercontent.com/nextdns/dns-bypass-methods/main/browsers \
          https://raw.githubusercontent.com/nextdns/dns-bypass-methods/main/encrypted-dns \
          https://raw.githubusercontent.com/nextdns/dns-bypass-methods/main/linux \
          https://raw.githubusercontent.com/nextdns/dns-bypass-methods/main/proxies \
          https://raw.githubusercontent.com/nextdns/dns-bypass-methods/main/tor \
          https://raw.githubusercontent.com/nextdns/dns-bypass-methods/main/vpn \
          https://raw.githubusercontent.com/nextdns/piracy-blocklists/master/dht-bootstrap-nodes \
          https://raw.githubusercontent.com/nextdns/piracy-blocklists/master/proxies \
          https://raw.githubusercontent.com/RPiList/specials/master/Blocklisten/proxies \
          https://raw.githubusercontent.com/hagezi/dns-blocklists/main/domains/doh.txt \
          https://raw.githubusercontent.com/hagezi/dns-blocklists/main/wildcard/doh-vpn-proxy-bypass-onlydomains.txt \
          2>/dev/null; \
      curl -sL --connect-timeout 5 --max-time 60 --retry 5 --retry-delay 10 --retry-max-time 300 \
          https://raw.githubusercontent.com/wiki/curl/curl/DNS-over-HTTPS.md 2>/dev/null | \
          awk -F'|' '/^# Publicly available servers/,/^# Private DNS Server with DoH setup examples/{print$3}' | \
          grep -oP "https://[A-Za-z0-9\-\._~]*(:[0-9]*)?\/[A-Za-z0-9\-\._~]*" \
    ) | sed -e "s/[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\s*//g" -e "/^#.*$/d" \
      -e "/^$/d" -e "s/\s.*//g" -e "/^[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}$/d" \
      -e "s|^https\?://||g" -e "s|/.*$||g" -e "s|:.*$||g" | sort -u | sed \
      -e '/^|\(12\|2\)\?proxy\.ga/d'; $(: '# fix 012proxy.ga error of "plain.black.hosts.list"'); \
  ) | grep -vE "^$(sed -e '/^#.*/d' -e 's/\s*#.*$//g' -e 's/[[:space:]]//g' white.txt)$" | sed 's/#//g' \
) > black-tmp-curl.txt
sleep 2
# cleanup unresolvables
diff -u black-tmp-curl.txt <(sed -n "s/^\(.*\)#[1-3]/\1/p" unresolvable.txt) | grep '^-' > black-tmp-diff.txt
diff -u black-tmp-diff.txt unresolvable_perm.txt | grep '^-' > black.txt
# cleaup temporary files
sleep 2
rm -f black-tmp-curl.txt black-tmp-diff.txt

#!/usr/bin/python3
import ipaddress
cidr = sys.argv[1]

cidr2ip = ipaddress.ip_network(cidr)
for ip in cidr2ip:
    print(ip)

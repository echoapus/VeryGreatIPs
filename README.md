# VeryGreatIPs
VeryGreatIPs

A easy script to block IP from certain AS number.
Seperate 1 ASN ipset to two ipsets which are ipv4 and ipv6.
ipset is limited, stop when over number, IPv4 and IPv6 are now working.

# iptables -L
```
root@localhost:/usr/local/bin# iptables -L
Chain INPUT (policy DROP)
target     prot opt source               destination
DROP       all  --  anywhere             anywhere             match-set as_blocklist src
```

# ip set list
```
root@localhost:/usr/local/bin# ipset list|more
Name: as_blocklist
Type: hash:net
Revision: 7
Header: family inet hashsize 4096 maxelem 65536 bucketsize 12 initval XXXXXX
Size in memory: 335280
References: 1
Number of entries: 11896
Members:
221.192.0.0/17
....
```

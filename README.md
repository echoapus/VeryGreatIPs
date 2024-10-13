# VeryGreatIPs
VeryGreatIPs

A easy script to block IP from certain AS number.
Now it's just IPv4, IPv6 is easy to do, I'm just lazy.

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

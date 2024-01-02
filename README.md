# Swox
A proxy server written in Swift.

Socks5 TCP connection and UDP ASSOCIATE are working now.

Not implemented
====
- Socks authentication
- UDP Fragmentation(probably not going to add)
- BIND(probably not going to add)

TODO
====
- Username/password authentication
- Packet sniffing
- Custom DNS server
- Unit Tests
- HTTP proxy

Example
====
Use arg "-p" for a different port number, "-f" to enable TCP Fast Open
```
#start with default config on port 1080
Swox

#start on port 1088 with TCP fast open enabled
Swox -f -p 1088
```

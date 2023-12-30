# Swox
A Socks5 proxy server written in Swift.

TCP connection and UDP ASSOCIATE are working now.

Not implemented
====
- Socks authentication
- UDP Fragmentation(probably not going to add)
- BIND(probably not going to add)

TODO
====
- Username/password authentication
- A cleaner logging solution (Dependency injection friendly, protocol + default built-in implementation)
- Packet sniffing
- Custom DNS server
- Unit Tests

Example
====
Use arg "-p" for a different port number, "-f" to enable TCP Fast Open
```
Swox -f -p 1088
```
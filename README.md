# Swox
A lightweight proxy server written in Swift.  
The only dependency is Apple's Network framework, for handling TCP and UDP connections.

Roadmap
===
✅ Implemented 👷 WIP 🕒 Likely to add in future 🤔 Less likely to add in future 🤷‍♂️ Not going to happen
- ✅ SOCKS5 CONNECT 
- ✅ SOCKS5 UDP ASSOCIATION
- ✅ Customisable logging
- ✅ HTTP Proxy
- 👷 Packet sniffing
- 🕒 Username/password authentication
- 🕒 Custom DNS
- 🕒 Unit Tests
- 🤔 Linux support(need to replace Network)
- 🤷‍♂️ Other Socks authentication
- 🤷‍♂️ UDP Fragmentation in SOCKS5 UDP ASSOCIATION
- 🤷‍♂️ SOCKS5 BIND


Example
====
Use arg "-p" for a different port number, "-f" to enable TCP Fast Open
```
#start with default config on port 1080
Swox

#start on port 1088 with TCP fast open enabled
Swox -f -p 1088
```

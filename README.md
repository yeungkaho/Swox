# Swox
A lightweight proxy server written in Swift.  
The only dependency is Apple's Network framework, for handling TCP and UDP connections.


Examples
====
Swox as command line tool
---
Use arg "-p" for a different port number, "-f" to enable TCP Fast Open
```
#start with default config on port 1080
Swox

#start on port 1088 with TCP fast open enabled
Swox -f -p 1088
```

SwoxLib as a Swift library
---
```
do {
    let proxyServer =
    try SwoxProxyServer(
        port: 1080,
        tcpFastOpen: true,
        logger: ConsolePrinterLogger(level: .info)
    )
    proxyServer.start()
    // ...
    proxyServer.stop()
} catch(let error) {
    // If failed, most likely it's because the port you're trying to use is occupied
}
```


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
- 🤷‍♂️ Other Socks authentication methods
- 🤷‍♂️ UDP Fragmentation in SOCKS5 UDP ASSOCIATION
- 🤷‍♂️ SOCKS5 BIND

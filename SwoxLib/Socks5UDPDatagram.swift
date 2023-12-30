//
//  Socks5UDPDatagram.swift
//  SwoxLib
//
//  Created by kahoyeung on 30/12/2023.
//

import Foundation

/**
 A UDP-based client MUST send its datagrams to the UDP relay server at
 the UDP port indicated by BND.PORT in the reply to the UDP ASSOCIATE
 request.  If the selected authentication method provides
 encapsulation for the purposes of authenticity, integrity, and/or
 confidentiality, the datagram MUST be encapsulated using the
 appropriate encapsulation.  Each UDP datagram carries a UDP request
 header with it:
 +----+------+------+----------+----------+----------+
 |RSV | FRAG | ATYP | DST.ADDR | DST.PORT |   DATA   |
 +----+------+------+----------+----------+----------+
 | 2  |  1   |  1   | Variable |    2     | Variable |
 +----+------+------+----------+----------+----------+
 
 The fields in the UDP request header are:

           o  RSV  Reserved X'0000'
           o  FRAG    Current fragment number
           o  ATYP    address type of following addresses:
              o  IP V4 address: X'01'
              o  DOMAINNAME: X'03'
              o  IP V6 address: X'04'
           o  DST.ADDR       desired destination address
           o  DST.PORT       desired destination port
           o  DATA     user data
 
 */

struct Socks5UDPDatagram {
    
    let address: Socks5Address
    let payload: Data
    
    init(address: Socks5Address, payload: Data) {
        self.address = address
        self.payload = payload
    }
    
    init?(data: Data) {
        // Parse address and payload from data
        guard data[0] + data[1] + data[2] == 0 else {
            // RSV and FRAG != 0x00
            return nil
        }
        guard let addressType = Socks5Address.AddressType(rawValue: data[3]) else {
            // invalid address type
            return nil
        }
        switch addressType { // Address Type
        case .ipV4:
            guard let parsed = Socks5Address(data: Data(data[3 ..< 10])) else {
                return nil
            }
            address = parsed
            payload = Data(data[10 ..< data.count])
        case .ipv6:
            guard let parsed = Socks5Address(data: Data(data[3 ..< 22])) else {
                return nil
            }
            address = parsed
            payload = Data(data[22 ..< data.count])
        case .domainName:
            let domainLength = data[4]
            // total length of address
            // = 1(ATYP) + 1(first byte is domain length) + domainLength + 2(port)
            // = 4 + domainLength
            guard let parsed = Socks5Address(data: Data(data[3 ..< (7 + domainLength)])) else {
                return nil
            }
            address = parsed
            payload = Data(data[(7 + Int(domainLength)) ..< data.count])
        }
    }
    
    func data() -> Data {
        Data([0x00, 0x00, 0x00]) + address.data() + payload
    }
}

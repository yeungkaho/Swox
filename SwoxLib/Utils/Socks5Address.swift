//
//  Socks5Address.swift
//  Swox
//
//  Created by kaho on 29/07/2023.
//

import Foundation
import Network

struct Socks5Address {
    enum AddressType: UInt8 {
        case ipV4 = 1
        case domainName = 3
        case ipv6 = 4
    }
    
    let addressType: AddressType
    let host: NWEndpoint.Host
    let port: NWEndpoint.Port
    
    init?(data: Data) {
        guard let addrType = AddressType(rawValue: data[0]) else {
            return nil
        }
        self.addressType = addrType
        switch addrType {
        case .ipV4:
            guard data.count == 7, let ipV4Address = IPv4Address(data[1...4]) else {
                // wrong data length
                return nil
            }
            host = .ipv4(ipV4Address)
        case .domainName:
            guard data.count > 5, let domainStr = String(bytes: data[2 ... data.endIndex - 3], encoding: .utf8) else {
                return nil
            }
            host = .name(domainStr, nil)
        case .ipv6:
            guard let ipv6Address = IPv6Address(data[1 ... data.endIndex - 2]) else {
                print("Cant parse ipv6 address.")
                return nil
            }
            host = .ipv6(ipv6Address)
        }
        guard let port = NWEndpoint.Port(rawValue: UInt16(data[data.endIndex - 1]) + UInt16(data[data.endIndex - 2]) * 256) else {
            return nil
        }
        self.port = port
    }
    
    init(
        addressType: AddressType,
        host: NWEndpoint.Host,
        port: NWEndpoint.Port
    ) {
        self.addressType = addressType
        self.host = host
        self.port = port
    }
    
    func data() -> Data {
        return Data([addressType.rawValue]) // ATYP
        + hostData() // ADDR
        + Data([ UInt8(port.rawValue >> 8), UInt8(port.rawValue & 0xFF)]) // PORT
    }
    
    private func hostData() -> Data {
        switch host {
        case .name(let name, _):
            return name.data(using: .ascii)!
        case .ipv4(let address):
            return address.rawValue
        case .ipv6(let address):
            return address.rawValue
        @unknown default:
            assertionFailure()
            return Data()
        }
    }
}

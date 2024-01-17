//
//  CommonMessages.swift
//  Swox
//
//  Created by kaho on 28/07/2023.
//

import Foundation

extension Data {
    static let crlf = Data("\r\n".utf8)
    static let httpConnectSuccess = Data("HTTP/1.1 200 Connection Established\r\n\r\n".utf8)
    static let socks5HandshakeComplete = Data([0x05, 0x00])
    static let socks5Connected = Data(
        [0x05, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]
    )
    static let socks5UnsupportedAuthMethod = Data([0x05, 0xff])
    static let socks5UnsupportedCommand = Data(
        [0x05, 0x07, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]
    )
}

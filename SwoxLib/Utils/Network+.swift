//
//  Network+.swift
//  SwoxLib
//
//  Created by kahoyeung on 02/01/2024.
//

import Network

extension NWConnection {
    func tryCancel() {
        if state != .cancelled {
            cancel()
        }
    }
}

extension NWParameters {
    static var defaultTCP: NWParameters {
        let tcpOptions = NWProtocolTCP.Options()
        tcpOptions.enableFastOpen = true
        tcpOptions.noDelay = true
        tcpOptions.connectionTimeout = 10
        tcpOptions.persistTimeout = 10
        tcpOptions.retransmitFinDrop = true
        return  NWParameters(tls:nil, tcp:tcpOptions)
    }
}

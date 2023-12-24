//
//  SwoxSocks5UDPRelaySession.swift
//  Swox
//
//  Created by kaho on 28/07/2023.
//

import Foundation
import Network


// TODO:

protocol SwoxSocks5UDPRelaySessionDelegate: AnyObject {
    func session(didEnd session: SwoxSocks5UDPRelaySession)
}

class SwoxSocks5UDPRelaySession: SwoxSocks5Session {
    
    let incomingEndpoint: NWEndpoint
    weak var delegate: SwoxSocks5UDPRelaySessionDelegate?
    
    override init(inConnection: NWConnection, queue: DispatchQueue) {
        incomingEndpoint = inConnection.endpoint
        super.init(inConnection: inConnection, queue: queue)
    }
    
    override func connectionCancelled() {
        cleanup()
    }
    
    private func cleanup() {
        delegate?.session(didEnd: self)
        delegate = nil
    }
}

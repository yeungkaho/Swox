//
//  SwoxSocks5UDPRelaySession.swift
//  Swox
//
//  Created by kaho on 28/07/2023.
//

import Foundation
import Network

protocol SwoxSocks5UDPRelaySessionDelegate: AnyObject {
    func session(didEnd session: SwoxSocks5UDPRelaySession)
}

class SwoxSocks5UDPRelaySession: SwoxProxySession {
    
    enum State {
        case readingRequest, outUDPConnected, inUDPListenerReady, waitingForInUDPConnection, transmitting, ended
    }
    
    let incomingEndpoint: NWEndpoint
    weak var delegate: SwoxSocks5UDPRelaySessionDelegate?
    
    let inUDPListener: NWListener
    var outUDPConnection: NWConnection!
    var inUDPConnection: NWConnection!
    var outEndpoint: NWEndpoint!
    var outSocksAddr: Socks5Address!
    private var state: State = .readingRequest
    
    override init(sessionID: Int, inConnection: NWConnection, queue: DispatchQueue, logger: Logger) throws {
        incomingEndpoint = inConnection.endpoint
        inUDPListener = try NWListener(using: .udp)
        try super.init(sessionID: sessionID, inConnection: inConnection, queue: queue, logger: logger)
    }
    
    /**
     Establishing a UDP Associate:
     - receive SOCKS5 UDP ASSOCIATE request
     - read endpoint address from in TCP
     - out UDP connection init
     - in UDP listener init
     - in TCP reply
     - accept in UDP connection from listener
     - start transmission
     */
    //
    func start() {
        inConnection.receive(
            minimumIncompleteLength: 5,
            maximumLength: 8192
        ) { [unowned self] content, contentContext, isComplete, error in
            // read addr type byte
            guard let content = content else {
                self.cleanup()
                return
            }
            do {
                let socksAddr = try Socks5Address(data: content)
                
                outSocksAddr = socksAddr
                let endpoint = NWEndpoint.hostPort(host: socksAddr.host, port: socksAddr.port)
                self.outEndpoint = endpoint
                
                self.outUDPConnection = .init(to: endpoint, using: .udp)
                self.outUDPConnection.stateUpdateHandler = self.handleOutUDPConnectionStateUpdate
                self.outUDPConnection.start(queue: self.queue)
                
            } catch let e {
                self.logger.error(e)
                self.cleanup()
                return
            }
        }
    }
    
    private func handleOutUDPConnectionStateUpdate(_ newState: NWConnection.State) {
        switch newState {
        case .ready:
            state = .outUDPConnected
            inUDPListener.newConnectionHandler = handleNewInConnection
            inUDPListener.stateUpdateHandler = handleInListenerStateUpdate
            inUDPListener.start(queue: queue)
        case .failed(let error):
            logger.error("[Socks5 UDP] Failed to establish udp connection to remote endpoint: " + error.localizedDescription)
            cleanup()
        case .cancelled:
            cleanup()
        default:
            break
        }
    }
    
    
    private func handleInListenerStateUpdate(_ newState: NWListener.State) {
        switch newState {
        case .cancelled:
            cleanup()
        case .failed(let error):
            logger.error("[Socks5 UDP] In UDP listener failed with error: " + error.localizedDescription)
        case .ready:
            guard let port = inUDPListener.port, port.rawValue > 0 else {
                // system did not allocate a valid port number for in udp listener
                logger.error("[Socks5 UDP] Failed to bind port for UDP listener ")
                cleanup()
                return
            }
            state = .inUDPListenerReady
            logger.info("[Socks5 UDP] initialized on port \(port.rawValue) from \(inConnection.endpoint) to \(outEndpoint!)")
            guard let successMessage = makeSuccessMessage() else {
                return
            }
            inConnection.send(content: successMessage, completion: .contentProcessed({ [weak self] error in
                if let error = error {
                    self?.logger.error("[Socks5 UDP] Failed to send reply for UDP ASSOCIATE: " + error.localizedDescription)
                    self?.cleanup()
                    return
                }
                self?.state = .waitingForInUDPConnection
            }))
        default:
            break
        }
    }
    
    private func makeSuccessMessage() -> Data? {
        guard let loaclEndpoint = inConnection.currentPath?.localEndpoint else {
            cleanup()
            return nil
        }
        var socksAddress: Socks5Address!
        switch loaclEndpoint {
        case .hostPort(host: let host, port: _):
            var addressType: Socks5Address.AddressType!
            switch host {
            case .ipv4:
                addressType = .ipV4
            case .ipv6:
                addressType = .ipv6
            case .name:
                addressType = .domainName
            @unknown default:
                cleanup()
                return nil
            }
            socksAddress = .init(addressType: addressType, host: host, port: inUDPListener.port!)
        default: // something went wrong if this is not a hostPort endpoint
            cleanup()
            return nil
        }
        return Data([0x05, 0x00, 0x00]) + socksAddress.data()
    }
    
    private func handleNewInConnection(_ connection: NWConnection) {
        logger.trace("[Socks5 UDP] got new udp connection from \(connection.endpoint)")
        inUDPConnection = connection
        inUDPConnection.start(queue: queue)
        self.state = .transmitting
        inRead()
        outRead()
    }
    
    private func inRead() {
        guard state == .transmitting, let inUDPConnection = inUDPConnection else {
            cleanup()
            return
        }
        inUDPConnection.receiveMessage { [weak self] content, contentContext, isComplete, error in
            defer { self?.inRead() }
            guard let self = self, let data = content, !data.isEmpty else {
                return
            }
            if let datagram = Socks5UDPDatagram(data: data) {
                outUDPConnection.send(content: datagram.payload, completion: .contentProcessed({ error in
                    if let error = error {
                        self.logger.error("[Socks5 UDP] failed to send udp datagram to remote: " + error.localizedDescription)
                    } else {
                        self.logger.trace("[Socks5 UDP] sent udp packet to remote with size: \(datagram.payload.count)")
                    }
                }))
            }
            
        }
    }
    
    private func outRead() {
        guard state == .transmitting, let outUDPConnection = outUDPConnection else {
            cleanup()
            return
        }
        outUDPConnection.receiveMessage { [weak self] content, contentContext, isComplete, error in
            defer { self?.outRead() }
            guard let self = self, let data = content, !data.isEmpty else {
                return
            }
            
            // received udp packet from remote, wrap it in a Socks5UDPDatagram and send back to in udp
            self.logger.trace("[Socks5 UDP] received data from out udp: \(data)")
            
            let datagram = Socks5UDPDatagram(address: outSocksAddr, payload: data)
            inUDPConnection.send(content: datagram.data(), completion: .contentProcessed({ error in
                if let error = error {
                    self.logger.error("[Socks5 UDP] failed to send udp datagram from remote " + error.localizedDescription)
                } else {
                    self.logger.trace("[Socks5 UDP] sent udp packet back to client with size: \(datagram.payload.count)")
                }
            }))
            
        }
    }
    
    override func connectionCancelled() {
        cleanup()
    }
    
    private func cleanup() {
        state = .ended
        delegate?.session(didEnd: self)
        delegate = nil
        inUDPListener.cancel()
        inConnection.tryCancel()
        outUDPConnection?.tryCancel()
        inUDPConnection?.tryCancel()
    }
}

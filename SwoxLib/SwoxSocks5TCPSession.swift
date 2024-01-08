//
//  SwoxSocks5Session.swift
//  Swox
//
//  Created by kaho on 28/07/2023.
//

import Foundation
import Network

protocol SwoxSocks5TCPSessionDelegate: AnyObject {
    func session(didEnd session: SwoxSocks5TCPSession)
}

final class SwoxSocks5TCPSession: SwoxProxySession {
    
    static let tcpParams: NWParameters = {
        let tcpOptions = NWProtocolTCP.Options()
        tcpOptions.enableFastOpen = true
        tcpOptions.noDelay = true
        tcpOptions.connectionTimeout = 10
        tcpOptions.persistTimeout = 10
        tcpOptions.retransmitFinDrop = true
        return  NWParameters(tls:nil, tcp:tcpOptions)
    }()
    
    enum State {
        case readingRequest, connected, ended
    }
    
    weak var delegate: SwoxSocks5TCPSessionDelegate?
    
    private let maximumReadLength = 8192
    private var outConnection: NWConnection!
    private var state: State = .readingRequest
    
    override init(sessionID: Int, inConnection: NWConnection, queue: DispatchQueue, logger: Logger) throws {
        try super.init(sessionID: sessionID, inConnection: inConnection, queue: queue, logger: logger)
    }
    
    func start() {
        guard state == .readingRequest else {
            fatalError("should not call start now")
        }
        inConnection.receive(
            minimumIncompleteLength: 5,
            maximumLength: maximumReadLength
        ) { [weak self] content, contentContext, isComplete, error in
            // read addr type byte
            guard let self = self, let content = content else {
                self?.cleanup()
                return
            }
            
            do {
                let sockAddr = try Socks5Address(data: content)
                let endpoint = NWEndpoint.hostPort(host: sockAddr.host, port: sockAddr.port)
                self.outConnection = .init(to: endpoint, using: Self.tcpParams)
                self.outConnection.stateUpdateHandler = { [weak self] newState in
                    self?.handleOutConnectionStateUpdate(newState: newState)
                }
                self.outConnection.start(queue: self.queue)
            } catch let error {
                self.logger.error(error)
                self.cleanup()
                return
            }
            
            
        }
    }
    
    private func inRead() {
        inConnection.receive(minimumIncompleteLength: 1, maximumLength: maximumReadLength) { [weak self] content, contentContext, isComplete, error in
            guard let self = self else { return }
            if let error = error {
                self.logger.error("[SOCKS5 TCP]Error when receiving data from in connection: \(error)")
                self.cleanup()
                return
            }
            if let content = content {
                self.outConnection.send(content: content, completion: .contentProcessed({ error in
                    if let error = error {
                        self.logger.error("[SOCKS5 TCP]Error when sending data to out connection: \(error)")
                        self.cleanup()
                        return
                    }
                    self.inRead()
                }))
            } else {
                self.inRead()
            }
        }
    }
    
    private func outRead() {
        outConnection.receive(minimumIncompleteLength: 1, maximumLength: maximumReadLength) { [weak self] content, contentContext, isComplete, error in
            guard let self = self else { return }
            if let error = error {
                self.logger.error("[SOCKS5 TCP]Error when receiving data from out connection: \(error)")
                self.cleanup()
                return
            }
            if let content = content {
                self.inConnection.send(content: content, completion: .contentProcessed({ error in
                    if let error = error {
                        self.logger.error("[SOCKS5 TCP]Error when sending data to in connection: \(error)")
                        self.cleanup()
                        return
                    }
                    self.outRead()
                }))
            } else {
                self.outRead()
            }
        }
    }
    
    private func handleOutConnectionStateUpdate(newState: NWConnection.State) {
        switch newState {
        case .setup:
            self.logger.trace("[SOCKS5 TCP]State of out connection to \(outConnection.endpoint): setup")
        case .waiting(let e):
            self.logger.trace("[SOCKS5 TCP]State of out connection to \(outConnection.endpoint): waiting(\(e)")
        case .preparing:
            self.logger.trace("[SOCKS5 TCP]State of out connection to \(outConnection.endpoint): preparing")
        case .ready:
            self.logger.trace("[SOCKS5 TCP]State of out connection to \(outConnection.endpoint): ready")
            guard state == .readingRequest else {
                self.logger.warning("[SOCKS5 TCP]State of out connection to \(outConnection.endpoint): ready again?")
                return
            }
            state = .connected
            inConnection.send(content: .socks5Connected, completion: .contentProcessed({ [weak self] error in
                guard let self = self else { return }
                if let error = error {
                    self.logger.error("[SOCKS5 TCP]Error when sending connected response to in connection: \(error)")
                    self.cleanup()
                    return
                }
                self.inRead()
                self.outRead()
            }))
        case .failed(let e):
            self.logger.error("[SOCKS5 TCP]State of out connection to \(outConnection.endpoint): faile with error: \(e)")
            cleanup()
        case .cancelled:
            self.logger.trace("[SOCKS5 TCP]State of out connection to \(outConnection.endpoint): cancelled")
            cleanup()
        @unknown default:
            self.logger.warning("[SOCKS5 TCP]State of out connection to \(outConnection.endpoint): unknown")
            cleanup()
        }
    }
    
    override func connectionCancelled() {
        cleanup()
    }
    
    private func cleanup() {
        state = .ended
        inConnection.tryCancel()
        outConnection.tryCancel()
        delegate?.session(didEnd: self)
        delegate = nil
    }
    
    deinit {
        inConnection.tryCancel()
        outConnection.tryCancel()
    }
}

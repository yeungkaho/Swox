//
//  SwoxSocks5Server.swift
//  Swox
//
//  Created by kaho on 27/07/2023.
//

import Foundation
import Network

public class SwoxProxyServer: SwoxSocks5TCPSessionDelegate, SwoxSocks5UDPRelaySessionDelegate {
    
    enum Socks5ServerError: Error {
        case invalidPortNumber
    }
    
    let listenQueue = DispatchQueue(label: "Swox.Listen", qos: .default, attributes: .concurrent, autoreleaseFrequency: .workItem)
    let sessionsQueue = DispatchQueue(label: "Swox.Sessions", qos: .userInteractive, autoreleaseFrequency: .workItem)
    let listener: NWListener
    
    let sessionFactory: SwoxSessionFactory
    
    let logger: Logger
    
    var sessions = Set<SwoxProxySession>()
    
    public init(
        port: UInt16,
        tcpFastOpen: Bool = false,
        tcpKeepAlive: Bool = false,
        tcpNoDelay: Bool = true,
        logger: Logger = ConsolePrinterLogger(level: .info)
    ) throws {
        guard let port = NWEndpoint.Port(rawValue: port) else {
            throw Socks5ServerError.invalidPortNumber
        }
        
        let tcpOptions = NWProtocolTCP.Options()
        tcpOptions.enableFastOpen = tcpFastOpen
        if tcpKeepAlive {
            tcpOptions.enableKeepalive = true
        }
        tcpOptions.noDelay = tcpNoDelay
        tcpOptions.connectionTimeout = 10
        tcpOptions.persistTimeout = 10
        tcpOptions.retransmitFinDrop = true
        
        let params = NWParameters(tls: nil, tcp: tcpOptions)
        params.allowFastOpen = tcpFastOpen
        params.allowLocalEndpointReuse = true
        
        listener = try NWListener(using: params, on: port)
        sessionFactory = SwoxSessionFactory(queue: sessionsQueue, logger: logger)
        self.logger = logger
        
        listener.newConnectionHandler = newConnectionHandler
        listener.stateUpdateHandler = { [weak self] newState in
            self?.handleListenerNewState(newState: newState)
        }
        
    }
    
    public func start() {
        listener.start(queue: listenQueue)
    }
    
    public func stop() {
        listener.cancel()
        sessionsQueue.async { [weak self] in
            self?.sessions.removeAll()
        }
    }
    
    private func newConnectionHandler(newConnection: NWConnection) {
        sessionFactory.makeNewSession(inConnection: newConnection) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let session):
                switch session {
                case .socks5TCP(let socks5TCPSession):
                    socks5TCPSession.delegate = self
                    self.sessions.insert(socks5TCPSession)
                    socks5TCPSession.start()
                case .socks5UDPRelay(let socks5UDPSession):
                    socks5UDPSession.delegate = self
                    self.sessions.insert(socks5UDPSession)
                    socks5UDPSession.start()
                case .http(let httpProxySession):
                    // TODO:
                    
                    self.sessions.insert(httpProxySession)
                    
                }
            case .failure(let error):
                newConnection.tryCancel()
                self.logger.error(error)
            }
        }
    }
    
    private func handleListenerNewState(newState: NWListener.State) {
        logger.trace("NWListener stateDidChange: \(newState)")
        switch newState {
        case .failed(let error):
            logger.error(error)
        default:
            break
        }
    }
    
    func session(didEnd session: SwoxSocks5TCPSession) {
        sessionsQueue.async { [weak self] in
            self?.sessions.remove(session)
        }
    }
    
    func session(didEnd session: SwoxSocks5UDPRelaySession) {
        sessionsQueue.async { [weak self] in
            self?.sessions.remove(session)
        }
    }
    
}

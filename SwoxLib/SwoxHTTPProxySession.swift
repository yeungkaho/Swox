//
//  SwoxHTTPProxySession.swift
//  SwoxLib
//
//  Created by kahoyeung on 02/01/2024.
//

import Foundation
import Network

final class SwoxHTTPProxySession: SwoxProxySession {
    
    enum State {
        case readingRequest, connected, ended
    }
    
    private let maximumReadLength = 8192
    private var outConnection: NWConnection!
    private var state: State = .readingRequest
    
    private let header: HTTPHeader
    
    init(sessionID: Int,
                  inConnection: NWConnection,
                  header: HTTPHeader,
                  queue: DispatchQueue,
                  logger: Logger) throws {
        self.header = header
        try super.init(sessionID: sessionID, inConnection: inConnection, queue: queue, logger: logger)
    }
    
    func start() {
        guard state == .readingRequest else {
            fatalError("should not call start now")
        }
        // At this point we already have the HTTP header to work with
        outConnection = .init(host: .name(header.host, nil), port: NWEndpoint.Port(rawValue: header.port)!, using: .defaultTCP)
        outConnection.stateUpdateHandler = { [weak self] newState in
            self?.handleOutConnectionStateUpdate(newState: newState)
        }
        outConnection.start(queue: queue)
    }
    
    private func handleOutConnectionStateUpdate(newState: NWConnection.State) {
        switch newState {
        case .setup:
            self.logger.trace("[HTTP]State of out connection to \(outConnection.endpoint): setup")
        case .waiting(let e):
            self.logger.trace("[HTTP]State of out connection to \(outConnection.endpoint): waiting(\(e)")
        case .preparing:
            self.logger.trace("[HTTP]State of out connection to \(outConnection.endpoint): preparing")
        case .ready:
            self.logger.trace("[HTTP]State of out connection to \(outConnection.endpoint): ready")
            guard state == .readingRequest else {
                self.logger.warning("[HTTP]State of out connection to \(outConnection.endpoint): ready again?")
                return
            }
            state = .connected
            if header.isConnect {
                inConnection.send(content: .httpConnectSuccess, completion: .contentProcessed({ [weak self] error in
                    guard let self = self else { return }
                    if let error = error {
                        self.logger.error("[HTTP]Error when sending connected response to in connection: \(error)")
                        self.cleanup()
                        return
                    }
                    self.inRead()
                    self.outRead()
                }))
            } else {
                inRead()
                outRead()
            }
            
        case .failed(let e):
            self.logger.error("[HTTP]State of out connection to \(outConnection.endpoint): faile with error: \(e)")
            cleanup()
        case .cancelled:
            self.logger.trace("[HTTP]State of out connection to \(outConnection.endpoint): cancelled")
            cleanup()
        @unknown default:
            self.logger.warning("[HTTP]State of out connection to \(outConnection.endpoint): unknown")
            cleanup()
        }
    }
    
    private func inRead() {
        inConnection.receive(minimumIncompleteLength: 1, maximumLength: maximumReadLength) { [weak self] content, contentContext, isComplete, error in
            guard let self = self else { return }
            if let error = error {
                self.logger.error("[HTTP]Error when receiving data from in connection: \(error)")
                self.cleanup()
                return
            }
            if let content = content {
                self.outConnection.send(content: content, completion: .contentProcessed({  [weak self]  error in
                    guard let self = self else { return }
                    if let error = error {
                        self.logger.error("[HTTP]Error when sending data to out connection: \(error)")
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
                
                self.logger.error("[HTTP]Error when receiving data from out connection: \(error)")
                if error != NWError.posix(.ENODATA) {
                    // POSIXErrorCode(rawValue: 96): No message available on STREAM
                    // sometimes this error will occur while everything seems to working fine
                    // could be one of Network framework's weird quirks
                    // for now, we tolerate this error,
                    // and only terminate this session if one of other errors occurred
                    self.cleanup()
                    return
                }
            }
            if let content = content {
                self.inConnection.send(content: content, completion: .contentProcessed({ error in
                    if let error = error {
                        self.logger.error("[HTTP]Error when sending data to in connection: \(error)")
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
    
    override func connectionCancelled() {
        cleanup()
    }
    
    override func cleanup() {
        super.cleanup()
        state = .ended
        inConnection.tryCancel()
        outConnection.tryCancel()
    }
    
    deinit {
        inConnection.tryCancel()
        outConnection.tryCancel()
    }
}

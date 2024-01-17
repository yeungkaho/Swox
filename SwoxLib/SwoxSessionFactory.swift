//
//  SwoxSessionFactory.swift
//  Swox
//
//  Created by kaho on 28/07/2023.
//

import Foundation
import Network

class SwoxSessionFactory {
    
    enum NewSession {
        case socks5TCP(SwoxSocks5TCPSession)
        case socks5UDPRelay(SwoxSocks5UDPRelaySession)
        case http(SwoxHTTPProxySession)
    }
    
    enum SessionFactoryError: Error {
        case failed(Error),
             cancelled,
             handshakeFailed,
             failedToInitializeSession,
             failedToReadFromConnection,
             unsupportedAuthenticationMethod,
             unsupportedSocksVersion,
             contaminatedRequest,
             invalidSocksCommand,
             bindCommandNotSupported
    }
    
    class SessionIDDispenser {
        private var value = 0
        private let semaphore = DispatchSemaphore(value: 1)
        func nextID() -> Int {
            semaphore.wait()
            defer { semaphore.signal() }
            value &+= 1
            return value
        }
    }
    
    enum RequestType {
        case invalid(SessionFactoryError), socks5, http(header: HTTPHeader)
    }
    
    private let sessionIdDispenser = SessionIDDispenser()
    private let queue: DispatchQueue
    private let logger: Logger
    
    init(queue: DispatchQueue, logger: Logger) {
        self.queue = queue
        self.logger = logger
    }
    
    func makeNewSession(inConnection: NWConnection, completion: @escaping (Result<NewSession, SessionFactoryError>) -> Void) {
        let logger = logger
        inConnection.stateUpdateHandler = { [weak self] state in
            guard let self = self else {
                completion(.failure(.cancelled))
                return
            }
            switch state {
            case .ready:
                logger.trace("[Session Factory]" + inConnection.debugDescription + ": ready")
                inConnection.receive(minimumIncompleteLength: 3, maximumLength: 8192) { [weak self] content, contentContext, isComplete, error in
                    guard let self = self else {
                        completion(.failure(.cancelled))
                        return
                    }
                    
                    /*
                     Here we try to read the first packet from client to determine what it wants
                     3 possible outcomes:
                     - Socks5 proxy request, then we shall continue to read its Socks5 Command;
                     - HTTP proxy request, then we shall return a new HTTP session;
                     - Invalid, return error;
                     */
                    
                    guard let content = content, content.count >= 3 else {
                        completion(.failure(.failedToReadFromConnection))
                        return
                    }
                    
                    let requestType = self.parseRequestType(data: content)
                    switch requestType {
                    case .socks5:
                        inConnection.send(content: .socks5HandshakeComplete, completion: .contentProcessed({  [weak self] error in
                            if let error = error {
                                logger.error("[Session Factory] Error sending Socks5 handshake complete message: \(error)")
                                completion(.failure(.handshakeFailed))
                                return
                            }
                            inConnection.receive(minimumIncompleteLength: 3, maximumLength: 3) { [weak self] content, contentContext, isComplete, error in
                                guard let self = self else {
                                    completion(.failure(.cancelled))
                                    return
                                }
                                guard let content = content, content.count == 3 else {
                                    completion(.failure(.failedToReadFromConnection))
                                    return
                                }
                                guard content[0] == 5 else {
                                    // Swox only supports SOCKS Protocol Version 5
                                    // Should not reach here in normal circumstances
                                    completion(.failure(.unsupportedSocksVersion))
                                    return
                                }
                                guard content[2] == 0 else {
                                    // Reserved byte should always equal to 0x00
                                    completion(.failure(.contaminatedRequest))
                                    return
                                }
                                let command = content[1]
                                switch command {
                                case 1: // TCP
                                    do {
                                        completion(.success(.socks5TCP(try .init(sessionID: self.sessionIdDispenser.nextID(),inConnection: inConnection, queue: self.queue, logger: logger))))
                                    } catch {
                                        completion(.failure(.failedToInitializeSession))
                                    }
                                    return
                                case 2: // BIND
                                    inConnection.send(content: .socks5UnsupportedCommand, completion: .contentProcessed({ error in
                                        completion(.failure(.bindCommandNotSupported))
                                    }))
                                    return
                                case 3: // UDP ASSOCIATE
                                    do {
                                        completion(.success(.socks5UDPRelay(try .init(sessionID: self.sessionIdDispenser.nextID(), inConnection: inConnection, queue: self.queue, logger: logger))))
                                    } catch {
                                        completion(.failure(.failedToInitializeSession))
                                    }
                                    return
                                default: // UNKNOWN CMD
                                    inConnection.send(content: .socks5UnsupportedCommand, completion: .contentProcessed({ error in
                                        completion(.failure(.invalidSocksCommand))
                                    }))
                                    return
                                }
                            }
                            
                        }))
                        
                    case .http(header: let header):
                        do {
                            completion(.success(.http(try .init(sessionID: self.sessionIdDispenser.nextID(), inConnection: inConnection, header: header, queue: self.queue, logger: logger))))
                        } catch {
                            completion(.failure(.failedToInitializeSession))
                        }
                        
                    case .invalid(let error):
                        switch error {
                        case .unsupportedAuthenticationMethod:
                            // TODO: Socks5 Authentication not supported yet
                            inConnection.send(content: .socks5UnsupportedAuthMethod, completion: .contentProcessed({ error in
                                completion(.failure(.unsupportedAuthenticationMethod))
                            }))
                            
                        default:
                            completion(.failure(.contaminatedRequest))
                        }
                    }
                }
            
            case .setup:
                logger.trace("[Session Factory]" + inConnection.debugDescription + ": setup")
            case .waiting(let e):
                logger.trace("[Session Factory]" + inConnection.debugDescription + ": waiting: \(e)")
            case .preparing:
                logger.trace("[Session Factory]" + inConnection.debugDescription + ": preparing")
            case .failed(let e):
                logger.trace("[Session Factory]" + inConnection.debugDescription + ": failed: \(e)")
                completion(.failure(.failed(e)))
            case .cancelled:
                logger.trace("[Session Factory]" + inConnection.debugDescription + ": cancelled")
                completion(.failure(.cancelled))
            @unknown default:
                logger.warning("[Session Factory]" + inConnection.debugDescription + ": @unknown state")
            }
        }
        inConnection.start(queue: queue)
    }
    
    func parseRequestType(data: Data) -> RequestType {
        // a valid Socks5 handshake request must have a length == 3
        // a valid http header should have a length > 3
        if data.count > 3 {
            if let httpHeader = try? HTTPHeader(data: data) {
                return .http(header: httpHeader)
            } else {
                return .invalid(.contaminatedRequest)
            }
        }
        
        guard data[0] == 5 else {
            // Swox only supports SOCKS Protocol Version 5
            return .invalid(.unsupportedSocksVersion)
        }
        guard data[1] == 1, data[2] == 0 else {
            // As of now we don't have authentication yet therefore only accept data[2] == 0
            return .invalid(.unsupportedAuthenticationMethod)
        }
        
        return .socks5
    }
    
}

//
//  SwoxProxySession.swift
//  Swox
//
//  Created by kaho on 28/07/2023.
//

import Foundation
import Network

protocol SwoxSessionDelegate: AnyObject {
    func session(didEnd session: SwoxProxySession)
}

class SwoxProxySession {
    
    let inConnection: NWConnection
    let queue: DispatchQueue
    let sessionID: Int
    let logger: Logger
    
    weak var delegate: SwoxSessionDelegate?
    
    init(sessionID: Int, inConnection: NWConnection, queue: DispatchQueue, logger: Logger) throws {
        self.sessionID = sessionID
        self.queue = queue
        self.inConnection = inConnection
        self.logger = logger
        self.inConnection.stateUpdateHandler = { [weak self] state in
            self?.inConnectionStateUpdateHandler(newState: state)
        }
    }
    
    private func inConnectionStateUpdateHandler(newState: NWConnection.State) {
        switch newState {
        case .cancelled, .failed(_):
            connectionCancelled()
        default:
            break
        }
    }
    
    func connectionCancelled() {
        fatalError("not implemented")
    }
    
    func cleanup() {
        delegate?.session(didEnd: self)
    }
    
}

extension SwoxProxySession: Hashable {
    static func == (lhs: SwoxProxySession, rhs: SwoxProxySession) -> Bool {
        lhs.sessionID == rhs.sessionID
    }
    func hash(into hasher: inout Hasher) {
        hasher.combine(sessionID.hashValue)
    }
}

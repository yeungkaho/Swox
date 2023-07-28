//
//  SwoxSocks5Session.swift
//  Swox
//
//  Created by kaho on 28/07/2023.
//

import Foundation
import Network

class SwoxSocks5Session {
  
  let inConnection: NWConnection
  let queue: DispatchQueue
  
  init(inConnection: NWConnection, queue: DispatchQueue) {
    self.queue = queue
    self.inConnection = inConnection
    self.inConnection.stateUpdateHandler = inConnectionStateUpdateHandler(newState:)
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
  
}

extension SwoxSocks5Session: Hashable {
  static func == (lhs: SwoxSocks5Session, rhs: SwoxSocks5Session) -> Bool {
      lhs.inConnection.endpoint == rhs.inConnection.endpoint
  }
  func hash(into hasher: inout Hasher) {
      hasher.combine(inConnection.endpoint.hashValue)
  }
}

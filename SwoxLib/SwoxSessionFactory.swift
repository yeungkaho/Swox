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
    case tcp(SwoxSocks5TCPSession)
    case udpRelay(SwoxSocks5UDPRelaySession)
  }
  
  enum SessionFactoryError: Error {
    case failed(Error),
         cancelled,
         handshakeFailed,
         failedToReadFromConnection,
         unsupportedAuthenticationMethod,
         unsupportedSocksVersion,
         contaminatedRequest,
         invalidSocksCommand,
         bindCommandNotSupported
  }
  
  let queue: DispatchQueue
  
  init(queue: DispatchQueue) {
    self.queue = queue
  }

  func makeNewSession(inConnection: NWConnection, completion: @escaping (Result<NewSession, SessionFactoryError>) -> Void) {
    
    inConnection.stateUpdateHandler = { [weak self] state in
      guard let self = self else {
        completion(.failure(.cancelled))
        return
      }
      switch state {
      case .ready:
        print(inConnection.debugDescription + ": ready")
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
            completion(.failure(.unsupportedSocksVersion))
            return
          }
          guard content[1] == 1, content[2] == 0 else {
            // TODO: Socks5 Authentication not supported yet
            inConnection.send(content: .socks5UnsupportedAuthMethod, completion: .contentProcessed({ error in
              completion(.failure(.unsupportedAuthenticationMethod))
            }))
            return
          }
          
          inConnection.send(content: .socks5HandshakeComplete, completion: .contentProcessed({ error in
            if let error = error {
              print("Error sending handshake complete message: \(error)")
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
              case 1:
                completion(.success(.tcp(.init(inConnection: inConnection, queue: self.queue))))
                return
              case 2:
                inConnection.send(content: .socks5UnsupportedCommand, completion: .contentProcessed({ error in
                  completion(.failure(.bindCommandNotSupported))
                }))
                return
              case 3:
                completion(.success(.udpRelay(.init(inConnection: inConnection, queue: self.queue))))
                return
              default:
                inConnection.send(content: .socks5UnsupportedCommand, completion: .contentProcessed({ error in
                  completion(.failure(.invalidSocksCommand))
                }))
                return
              }
            }
          }))
        }
      case .setup:
        print(inConnection.debugDescription + ": setup")
      case .waiting(let e):
        print(inConnection.debugDescription + ": waiting: \(e)")
      case .preparing:
        print(inConnection.debugDescription + ": preparing")
      case .failed(let e):
        print(inConnection.debugDescription + ": failed: \(e)")
        completion(.failure(.failed(e)))
      case .cancelled:
        print(inConnection.debugDescription + ": cancelled")
        completion(.failure(.cancelled))
      @unknown default:
        print(inConnection.debugDescription + ": @unknown state")
      }
    }
    inConnection.start(queue: queue)
  }
}

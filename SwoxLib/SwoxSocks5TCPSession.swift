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

class SwoxSocks5TCPSession: SwoxSocks5Session {
  
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
  
  override init(inConnection: NWConnection, queue: DispatchQueue) {
    super.init(inConnection: inConnection, queue: queue)
  }
  
  func start() {
    guard state == .readingRequest else {
      fatalError("should not call start now")
    }
    inConnection.receive(minimumIncompleteLength: 5, maximumLength: maximumReadLength) { [unowned self] content, contentContext, isComplete, error in
      // read addr type byte
      guard let content = content, let sockAddr = Socks5Address(data: content) else {
        self.cleanup()
        return
      }
      
      let endpoint = NWEndpoint.hostPort(host: sockAddr.host, port: sockAddr.port)
      self.outConnection = .init(to: endpoint, using: Self.tcpParams)
      self.outConnection.stateUpdateHandler = self.outConnectionStateUpdateHandler
      self.outConnection.start(queue: queue)
      
    }
  }

  func inRead() {
    inConnection.receive(minimumIncompleteLength: 1, maximumLength: maximumReadLength) { [weak self] content, contentContext, isComplete, error in
      guard let self = self else { return }
      if let error = error {
        print("Error when receiving data from in connection: \(error)")
        self.cleanup()
        return
      }
      if let content = content {
        self.outConnection.send(content: content, completion: .contentProcessed({ error in
          if let error = error {
            print("Error when sending data to out connection: \(error)")
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
  
  func outRead() {
    outConnection.receive(minimumIncompleteLength: 1, maximumLength: maximumReadLength) { [weak self] content, contentContext, isComplete, error in
      guard let self = self else { return }
      if let error = error {
        print("Error when receiving data from out connection: \(error)")
        self.cleanup()
        return
      }
      if let content = content {
        self.inConnection.send(content: content, completion: .contentProcessed({ error in
          if let error = error {
            print("Error when sending data to in connection: \(error)")
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
  
  private func outConnectionStateUpdateHandler(newState: NWConnection.State) {
    switch newState {
    case .setup:
      print("State of out connection to \(outConnection.endpoint): setup")
    case .waiting(let e):
      print("State of out connection to \(outConnection.endpoint): waiting(\(e)")
    case .preparing:
      print("State of out connection to \(outConnection.endpoint): preparing")
    case .ready:
      print("State of out connection to \(outConnection.endpoint): ready")
      guard state == .readingRequest else {
        print("State of out connection to \(outConnection.endpoint): ready again?")
        return
      }
      state = .connected
      inConnection.send(content: .socks5Connected, completion: .contentProcessed({ [weak self] error in
        guard let self = self else { return }
        if let error = error {
          print("Error when sending connected response to in connection: \(error)")
          self.cleanup()
          return
        }
        self.inRead()
        self.outRead()
      }))
    case .failed(let e):
      print("State of out connection to \(outConnection.endpoint): faile with error: \(e)")
      cleanup()
    case .cancelled:
      print("State of out connection to \(outConnection.endpoint): cancelled")
      cleanup()
    @unknown default:
      print("State of out connection to \(outConnection.endpoint): unknown")
      cleanup()
    }
  }
  
  override func connectionCancelled() {
    cleanup()
  }
  
  private func cleanup() {
    state = .ended
    inConnection.cancel()
    outConnection.cancel()
    delegate?.session(didEnd: self)
    delegate = nil
  }
}

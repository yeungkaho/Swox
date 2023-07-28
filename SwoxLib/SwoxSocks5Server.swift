//
//  SwoxSocks5Server.swift
//  Swox
//
//  Created by kaho on 27/07/2023.
//

import Foundation
import Network

public class SwoxSocks5Server: SwoxSocks5TCPSessionDelegate, SwoxSocks5UDPRelaySessionDelegate {
  enum Socks5ServerError: Error {
    case invalidPortNumber
  }
  enum ConnectionSortResult {
    
  }
  let listenQueue = DispatchQueue(label: "Swox.Socks5.Listen", qos: .default, attributes: .concurrent, autoreleaseFrequency: .workItem)
  let sessionsQueue = DispatchQueue(label: "Swox.Socks5.Sessions", qos: .userInteractive, autoreleaseFrequency: .workItem)
  let listener: NWListener
  
  let sessionFactory: SwoxSessionFactory
  
  var tcpSessions = Set<SwoxSocks5TCPSession>()
  var udpRelaySessions = Set<SwoxSocks5UDPRelaySession>()
  
  public init(port: UInt16, tcpFastOpen: Bool = true, tcpKeepAlive: Bool = true, tcpNoDelay: Bool = true) throws {
    guard let port = NWEndpoint.Port(rawValue: port) else {
      throw Socks5ServerError.invalidPortNumber
    }
    
    let tcpOptions = NWProtocolTCP.Options()
    tcpOptions.enableFastOpen = tcpFastOpen
    if tcpKeepAlive {
        tcpOptions.enableKeepalive = true
        tcpOptions.keepaliveIdle = 2
        tcpOptions.keepaliveCount = 2
        tcpOptions.keepaliveInterval = 2
    }
    tcpOptions.noDelay = tcpNoDelay
    tcpOptions.connectionTimeout = 10
    tcpOptions.persistTimeout = 10
    tcpOptions.retransmitFinDrop = true
    
    let params = NWParameters(tls: nil, tcp: tcpOptions)
    params.allowFastOpen = tcpFastOpen
    params.allowLocalEndpointReuse = true
    
    listener = try NWListener(using: params, on: port)
    sessionFactory = SwoxSessionFactory(queue: sessionsQueue)
    listener.newConnectionHandler = newConnectionHandler
    listener.stateUpdateHandler = listionerStateeUpdateHandler
  }
  
  public func start() {
    listener.start(queue: listenQueue)
  }
  
  private func newConnectionHandler(newConnection: NWConnection) {
    sessionFactory.makeNewSession(inConnection: newConnection) { [weak self] result in
      guard let self = self else { return }
      switch result {
      case .success(let session):
        switch session {
        case .tcp(let tcpSession):
          tcpSession.delegate = self
          self.tcpSessions.insert(tcpSession)
          tcpSession.start()
        case .udpRelay(let udpSession):
          udpSession.delegate = self
          self.udpRelaySessions.insert(udpSession)
          //TODO: UDP relay
        }
      case .failure(let error):
        newConnection.cancel()
        print(error)
      }
    }
  }

  private func listionerStateeUpdateHandler(newState: NWListener.State) {
    print("NWListener stateDidChange: \(newState)")
    switch newState {
    case .failed(let error):
      print(error.localizedDescription)
    default:
        break
    }
  }
  
  func session(didEnd session: SwoxSocks5TCPSession) {
    sessionsQueue.async { [weak self] in
      self?.tcpSessions.remove(session)
    }
  }
  
  func session(didEnd session: SwoxSocks5UDPRelaySession) {
    sessionsQueue.async { [weak self] in
      self?.udpRelaySessions.remove(session)
    }
  }
  
}

//
//  SwoxHTTPProxySession.swift
//  SwoxLib
//
//  Created by kahoyeung on 02/01/2024.
//

import Foundation
import Network

final class SwoxHTTPProxySession: SwoxProxySession {
    // TODO:
    init(sessionID: Int,
                  inConnection: NWConnection,
                  header: HTTPHeader,
                  queue: DispatchQueue,
                  logger: Logger) throws {
        try super.init(sessionID: sessionID, inConnection: inConnection, queue: queue, logger: logger)
    }
}

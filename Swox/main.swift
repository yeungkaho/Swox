//
//  main.swift
//  Swox
//
//  Created by kaho on 29/07/2023.
//

import Foundation
import SwoxLib

/*
    Default port is 1080.
    
    Use arg "-p" for a different port number, "-f" to enable TCP Fast Open

    Example:
    `Swox -p 1088`
    
 */

var port: UInt16 = 1080
var tfoEnabled = false

enum ArgParsingState {
    case searching, expectingPortNumber
}

var state = ArgParsingState.searching

for arg in CommandLine.arguments {
    switch state {
    case .searching:
        switch arg {
        case "-p":
            state = .expectingPortNumber
        case "-f":
            tfoEnabled = true
            print("TCP Fast Open enabled")
        default:
            print("invalid argument: \(arg)")
            continue
        }
    case .expectingPortNumber:
        guard let overridePort = UInt16(arg) else {
            print("'\(arg)'is not a valid port number")
            exit(1)
        }
        port = overridePort
        state = .searching
    }
}

print("Starting Swox on port \(port)...")

let server = try! SwoxSocks5Server(port: port, tcpFastOpen: tfoEnabled)
server.start()

RunLoop.main.run()

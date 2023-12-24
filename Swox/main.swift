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
Use arg "-p" for a different port number.

Example:
`Swox -p 1088`
 */

var port: UInt16 = 1080

let args = CommandLine.arguments

for i in args.indices {
    if args[i] == "-p", i < args.count - 1 {
        guard let overridePort = UInt16(args[i + 1]) else {
            print("'\(args[i + 1])'is not a valid port number")
            break
        }
        port = overridePort
        break
    }
}

print("Starting Swox on port \(port)")

let server = try! SwoxSocks5Server(port: port)
server.start()

RunLoop.main.run()

//
//  HTTPHeader.swift
//  SwoxLib
//
//  Created by kahoyeung on 02/01/2024.
//

import Foundation

struct HTTPHeader {
    
    enum HeaderError: Error {
        case failedToParse
        case invalidRequest
        case invalidOrMissingHost
        case invalidEncoding
    }
    
    let rawData: Data
    let firstLine: String
    let method: String
    let isConnect: Bool
    let path: String
    let httpVersion: String
    let host: String
    let port: UInt16
    
    var headers: [String: String]
    
    
    init(data: Data) throws {
        guard let rawString = String(data: data, encoding: .utf8) else {
            throw HeaderError.invalidEncoding
        }
        
        rawData = data
        
        let lines = rawString.components(separatedBy: "\r\n")
        
        guard !lines.isEmpty else { throw HeaderError.failedToParse }
        
        firstLine = lines[0]
        let requestComponents = firstLine.components(separatedBy: " ")
        // the request sohuld always always contain 3 parts
        // <Method> <Request-Target> <HTTP-Version>
        guard requestComponents.count == 3 else { throw HeaderError.invalidRequest }
        
        method = requestComponents[0]
        httpVersion = requestComponents[2]
        
        headers = try lines[1 ..< lines.count - 2].reduce(into: [String: String](), { partialResult, line in
            let components = line.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
            guard components.count == 2 else { throw HeaderError.failedToParse }
            let key = components[0].trimmingCharacters(in: .whitespaces)
            let value = components[1].trimmingCharacters(in: .whitespaces)
            partialResult[key] = value
        })
        
        isConnect = method.uppercased() == "CONNECT"
        if isConnect {
            path = ""
            // for CONNECT it is required to specify both host and port
            let hostPort = requestComponents[1].components(separatedBy: ":")
            guard hostPort.count == 2, let portNumber = UInt16(hostPort[1]) else { throw HeaderError.invalidRequest }
            host = hostPort[0]
            port = portNumber
        } else {
            path = requestComponents[1]
            guard let hostInHeaders = headers["Host"] else {
                throw HeaderError.invalidOrMissingHost
            }
            if hostInHeaders.contains(":") {
                let hostPort = hostInHeaders.components(separatedBy: ":")
                guard hostPort.count == 2, let portNumber = UInt16(hostPort[1]) else { throw HeaderError.invalidOrMissingHost }
                host = hostPort[0]
                port = portNumber
            } else {
                host = hostInHeaders
                port = 80
            }
        }
        
        
    }
}

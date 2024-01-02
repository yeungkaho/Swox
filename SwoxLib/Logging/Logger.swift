//
//  Logger.swift
//  SwoxLib
//
//  Created by kahoyeung on 02/01/2024.
//

import Foundation

public enum LogLevel: Int {
    case error = 1
    case warning
    case info
    case debug
    case trace
}

public protocol Logger {
    func log(_ message: String, level: LogLevel)
}

public extension Logger { // convenience
    
    @inline(__always)
    func error(_ message: String) {
        log(message, level: .error)
    }
    @inline(__always)
    func error(_ error: Error) {
        log(error.localizedDescription, level: .error)
    }
    
    @inline(__always)
    func warning(_ message: String) {
        log(message, level: .warning)
    }
    
    @inline(__always)
    func info(_ message: String) {
        log(message, level: .info)
    }
    
    @inline(__always)
    func debug(_ message: String) {
        log(message, level: .debug)
    }
    
    @inline(__always)
    func trace(_ message: String) {
        log(message, level: .trace)
    }
    
}

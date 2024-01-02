//
//  ConsolePrinterLogger.swift
//  SwoxLib
//
//  Created by kahoyeung on 02/01/2024.
//

import Foundation

fileprivate extension LogLevel {
    var asString: String {
        switch self {
        case .error: "ERROR"
        case .warning: "WARNING"
        case .info: "INFO"
        case .debug: "DEBUG"
        case .trace: "TRACE"
        }
    }
}

public class ConsolePrinterLogger: Logger {
    let level: LogLevel
    public init(level: LogLevel) {
        self.level = level
    }
    public func log(_ message: String, level: LogLevel) {
        guard level.rawValue <= self.level.rawValue else { return }
        print("[\(level.asString)]" + message)
    }
}

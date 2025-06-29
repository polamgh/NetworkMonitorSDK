//
//  NetworkLogger.swift
//  NetworkMonitorSDK
//
//  Created by Ali Ghanavati on 2025-06-29.
//

import Foundation


enum LogLevel: String {
    case debug = "DEBUG"
    case info = "INFO"
    case warning = "WARNING"
    case error = "ERROR"
}

final class NetworkLogger {
    static var isLoggingEnabled = true
    static var minimumLevelToLog: LogLevel = .debug

    static func log(_ message: @autoclosure () -> String, level: LogLevel = .debug) {
#if DEBUG
        guard isLoggingEnabled else { return }
        if level.shouldLog(current: minimumLevelToLog) {
            let timestamp = DateFormatter.logTimestampFormatter.string(from: Date())
            print("[NetworkMonitorSDK] \(level.rawValue) | \(timestamp): \(message())")
        }
#endif
    }
}

private extension LogLevel {
    func shouldLog(current: LogLevel) -> Bool {
        switch (self, current) {
        case (.error, _), (.warning, .debug), (.warning, .info), (.info, .debug), (.debug, .debug):
            return true
        default:
            return self == current
        }
    }
}

private extension DateFormatter {
    static let logTimestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter
    }()
}

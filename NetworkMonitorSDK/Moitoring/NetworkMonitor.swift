//
//  NetworkMonitor.swift
//  NetworkMonitorSDK
//
//  Created by Ali Ghanavati on 2025-06-28.
//

import Foundation


@objcMembers
@objc public class NetworkMonitor: NSObject {
    @objc public static let shared = NetworkMonitor()

    private var inFlightTasks: [Int: NetworkMonitorTaskInfo] = [:]
    private let taskQueue = DispatchQueue(label: "com.networkmonitorsdk.taskQueue")
    private var isMonitoring = false

    private override init() {}

    /// Starts monitoring by swizzling URLSessionConfiguration and registering custom URLProtocol
    @objc public static func startMonitoring() {
        NetworkSwizzler.swizzleSessionConfigurations()

        guard !NetworkMonitor.shared.isMonitoring else { return }
        NetworkMonitor.shared.isMonitoring = true

        URLProtocol.registerClass(NetworkMonitorURLProtocol.self)
        NetworkLogger.log("Started monitoring.", level: .info)
    }

    /// Stops monitoring by unregistering the custom URLProtocol
    public static func stopMonitoring() {
        guard NetworkMonitor.shared.isMonitoring else { return }
        NetworkMonitor.shared.isMonitoring = false
        URLProtocol.unregisterClass(NetworkMonitorURLProtocol.self)
        NetworkLogger.log("Stopped monitoring.", level: .info)
    }

    /// Injects URLProtocol into a given URLSessionConfiguration
    @objc public func addURLProtocolToConfiguration(_ configuration: URLSessionConfiguration, type: String) {
        var protocolClasses = configuration.protocolClasses ?? []
        if !protocolClasses.contains(where: { $0 == NetworkMonitorURLProtocol.self }) {
            protocolClasses.insert(NetworkMonitorURLProtocol.self, at: 0)
            configuration.protocolClasses = protocolClasses
            NetworkLogger.log("Injected URLProtocol into \(type) configuration.", level: .debug)
        } else {
            NetworkLogger.log("URLProtocol already present in \(type) configuration.", level: .debug)
        }
    }

    /// Tracks the creation of a network task
    @objc public func trackTaskCreation(taskIdentifier: Int, initialURL: URL, type: String) {
        taskQueue.async {
            self.inFlightTasks[taskIdentifier] = NetworkMonitorTaskInfo(
                initialURL: initialURL,
                startTime: Date(),
                taskType: type
            )
            NetworkLogger.log("Task \(taskIdentifier) (\(type)) created for URL: \(initialURL.absoluteString)", level: .debug)
        }
    }

    /// Tracks the completion of a network task
    @objc public func trackTaskCompletion(taskIdentifier: Int, response: URLResponse?, error: Error?) {
        taskQueue.async {
            guard let info = self.inFlightTasks.removeValue(forKey: taskIdentifier) else {
                NetworkLogger.log("Missing task info for completion. Task ID: \(taskIdentifier)", level: .warning)
                return
            }

            let duration = Date().timeIntervalSince(info.startTime) * 1000 // ms
            let isSuccessful = (error == nil)

            let log = NetworkConnectionLog(
                initialURL: info.initialURL.absoluteString,
                durationMs: Int(duration),
                finalURL: response?.url?.absoluteString,
                isSuccessful: isSuccessful,
                timestamp: Date(),
                taskType: info.taskType
            )

            NetworkMonitorStorage.shared.addLog(log)
            NetworkLogger.log("Logged task \(taskIdentifier): \(info.initialURL.absoluteString), Duration: \(Int(duration))ms, Success: \(isSuccessful)", level: .info)
        }
    }
}

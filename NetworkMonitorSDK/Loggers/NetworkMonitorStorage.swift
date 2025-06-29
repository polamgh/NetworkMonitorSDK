//
//  NetworkMonitorStorage.swift.swift
//  NetworkMonitorSDK
//
//  Created by Ali Ghanavati on 2025-06-28.
//

import Foundation

// MARK: - Network Connection Log Model
public struct NetworkConnectionLog: Codable {
    public let initialURL: String
    public let durationMs: Int
    public let finalURL: String?
    public let isSuccessful: Bool
    public let timestamp: Date
    let taskType: String
}

// MARK: - Persistent Storage for Logs
public final class NetworkMonitorStorage {

    // Singleton instance
    public static let shared = NetworkMonitorStorage()

    private let fileName = "network_logs.json"
    private var logs: [NetworkConnectionLog] = []
    private let queue = DispatchQueue(label: "com.networkmonitorsdk.storageQueue", qos: .background)

    private init() {
        loadLogs()
    }

    // MARK: - File Management

    private func getFileURL() -> URL? {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?
            .appendingPathComponent(fileName)
    }

    // MARK: - Load Existing Logs from Disk

    private func loadLogs() {
        queue.sync {
            guard let fileURL = getFileURL() else {
                NetworkLogger.log("Failed to locate documents directory.", level: .error)
                return
            }

            do {
                let data = try Data(contentsOf: fileURL)
                logs = try JSONDecoder().decode([NetworkConnectionLog].self, from: data)
                NetworkLogger.log("Loaded \(logs.count) existing logs from disk.", level: .debug)
            } catch {
                logs = []
                NetworkLogger.log("Failed to load logs: \(error.localizedDescription)", level: .error)
            }
        }
    }

    // MARK: - Public APIs

    public func addLog(_ log: NetworkConnectionLog) {
        queue.sync {
            logs.append(log)
            saveLogs()
        }
    }

    public func getAllLogs(completion: @escaping ([NetworkConnectionLog]) -> Void) {
        queue.async {
            completion(self.logs)
        }
    }

    public func clearAllLogs() {
        queue.async {
            self.logs.removeAll()
            self.saveLogs()
        }
    }

    // MARK: - Save Logs to Disk

    private func saveLogs() {
        guard let fileURL = getFileURL() else {
            NetworkLogger.log("Cannot save logs: invalid file URL.", level: .error)
            return
        }

        do {
            let data = try JSONEncoder().encode(logs)
            try data.write(to: fileURL)
            NetworkLogger.log("Saved \(logs.count) logs to \(fileURL.lastPathComponent)", level: .debug)
        } catch {
            NetworkLogger.log("Failed to save logs: \(error.localizedDescription)", level: .error)
        }
    }
    
}

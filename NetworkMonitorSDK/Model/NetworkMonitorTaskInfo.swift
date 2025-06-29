//
//  NetworkMonitorTaskInfo.swift
//  NetworkMonitorSDK
//
//  Created by Ali Ghanavati on 2025-06-29.
//

import Foundation


class NetworkMonitorTaskInfo {
    let initialURL: URL
    let startTime: Date
    var finalURL: URL?
    var isSuccessful: Bool?
    var taskType: String 

    init(initialURL: URL, startTime: Date, taskType: String) {
        self.initialURL = initialURL
        self.startTime = startTime
        self.taskType = taskType
    }
}

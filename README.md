
# NetworkMonitorSDK

## Summary
A lightweight and pluggable SDK for tracking `URLSession` network activity including timing, success/failure status, and redirection handling — with automatic logging to disk.

## Overview

`NetworkMonitorSDK` provides a plug-and-play solution to track all outgoing HTTP/HTTPS traffic inside your app using a combination of `URLProtocol` and method swizzling. It transparently observes network connections created via `URLSession`, and logs key metrics such as:

- Request start and end time (duration)
- Initial and final URLs (with redirection detection)
- Success or failure status
- Automatic storage of logs in a persistent JSON file

This SDK is designed for developers and QA engineers looking to:

- Debug flaky connections
- Track API performance
- Monitor behavior of embedded third-party SDKs
- Audit outgoing network activity

## How to Build

To generate a cross-platform `.xcframework`:

```bash
xcodebuild archive \
  -scheme NetworkMonitorSDK \
  -destination "generic/platform=iOS" \
  -archivePath ./build/NetworkMonitorSDK-iOS \
  SKIP_INSTALL=NO \
  BUILD_LIBRARY_FOR_DISTRIBUTION=YES

xcodebuild archive \
  -scheme NetworkMonitorSDK \
  -destination "generic/platform=iOS Simulator" \
  -archivePath ./build/NetworkMonitorSDK-iOS-Simulator \
  SKIP_INSTALL=NO \
  BUILD_LIBRARY_FOR_DISTRIBUTION=YES

xcodebuild -create-xcframework \
  -framework ./build/NetworkMonitorSDK-iOS.xcarchive/Products/Library/Frameworks/NetworkMonitorSDK.framework \
  -framework ./build/NetworkMonitorSDK-iOS-Simulator.xcarchive/Products/Library/Frameworks/NetworkMonitorSDK.framework \
  -output ./NetworkMonitorSDK.xcframework
```

You can now embed `NetworkMonitorSDK.xcframework` into any Xcode project.

## How to Use

1. **Import the SDK:**

   ```swift
   import NetworkMonitorSDK
   ```

2. **Start monitoring (e.g., in `AppDelegate` or early in your app lifecycle):**

   ```swift
   NetworkMonitor.startMonitoring()
   ```

3. **Stop monitoring when appropriate:**

   ```swift
   NetworkMonitor.stopMonitoring()
   ```

Logs will automatically be tracked for all outgoing `URLSession` traffic.

## How to View Logs

All connection data is stored in a local file as an array of JSON objects.

### Programmatically:
```swift
NetworkMonitorStorage.shared.getAllLogs { logs in
    for log in logs {
        print("Request to \(log.initialURL), took \(log.durationMs)ms, success: \(log.isSuccessful)")
    }
}
```

### Manually:
Navigate to the file using:

```
~/Library/Developer/CoreSimulator/Devices/<DeviceID>/data/Containers/Data/Application/<AppID>/Documents/network_logs.json
```

You can open the `.json` file in any text editor or JSON viewer.

## Topics

### Monitoring

- `NetworkMonitor`  
- `NetworkMonitor.startMonitoring()`
- `NetworkMonitor.stopMonitoring()`

### Logging

- `NetworkConnectionLog`
- `NetworkMonitorStorage`

### Internal Mechanics

- `NetworkSwizzler`  
- `NetworkMonitorURLProtocol`

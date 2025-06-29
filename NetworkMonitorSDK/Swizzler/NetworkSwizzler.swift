//
//  NetworkSwizzler.swift
//  NetworkMonitorSDK
//
//  Created by Ali Ghanavati on 2025-06-29.
//

import Foundation
import ObjectiveC

/// A utility class responsible for swizzling URLSessionConfiguration factory methods
/// to inject our custom URLProtocol for monitoring purposes.
final class NetworkSwizzler {

    private static var didSwizzle = false
    private static let swizzleQueue = DispatchQueue(label: "com.networkmonitorsdk.swizzleQueue", qos: .userInitiated)

    // MARK: - Original Method Implementations (IMPs)
    private static var originalDefaultSessionConfigurationIMP: IMP?
    private static var originalEphemeralSessionConfigurationIMP: IMP?
    private static var originalBackgroundSessionConfigurationWithIdentifierIMP: IMP?

    /// Public entry point to apply all necessary swizzles (called once)
    static func swizzleSessionConfigurations() {
        swizzleQueue.sync {
            guard !didSwizzle else {
                NetworkLogger.log("Already swizzled session configurations.", level: .debug)
                return
            }
            didSwizzle = true

            guard
                let targetMetaClass = object_getClass(URLSessionConfiguration.self),
                let swizzlerMetaClass = object_getClass(NetworkSwizzler.self)
            else {
                NetworkLogger.log("Could not get metaclasses for swizzling.", level: .error)
                return
            }

            // Apply swizzling for each factory method
            performSingleSwizzle(
                on: targetMetaClass,
                originalSelector: #selector(getter: URLSessionConfiguration.default),
                swizzledSelector: #selector(swizzled_defaultSessionConfiguration),
                originalIMPStorage: &originalDefaultSessionConfigurationIMP,
                name: "defaultSessionConfiguration",
                swizzlerMetaClass: swizzlerMetaClass
            )

            performSingleSwizzle(
                on: targetMetaClass,
                originalSelector: #selector(getter: URLSessionConfiguration.ephemeral),
                swizzledSelector: #selector(swizzled_ephemeralSessionConfiguration),
                originalIMPStorage: &originalEphemeralSessionConfigurationIMP,
                name: "ephemeralSessionConfiguration",
                swizzlerMetaClass: swizzlerMetaClass
            )

            performSingleSwizzle(
                on: targetMetaClass,
                originalSelector: NSSelectorFromString("backgroundSessionConfigurationWithIdentifier:"),
                swizzledSelector: #selector(swizzled_backgroundSessionConfigurationWithIdentifier(_:)),
                originalIMPStorage: &originalBackgroundSessionConfigurationWithIdentifierIMP,
                name: "backgroundSessionConfigurationWithIdentifier",
                swizzlerMetaClass: swizzlerMetaClass
            )
        }
    }

    /// Performs the actual swizzling of a single class method
    private static func performSingleSwizzle(
        on targetMetaClass: AnyClass,
        originalSelector: Selector,
        swizzledSelector: Selector,
        originalIMPStorage: inout IMP?,
        name: String,
        swizzlerMetaClass: AnyClass
    ) {
        guard let originalMethod = class_getClassMethod(targetMetaClass, originalSelector) else {
            NetworkLogger.log("Original method not found: \(name)", level: .warning)
            return
        }

        guard let swizzledMethod = class_getClassMethod(swizzlerMetaClass, swizzledSelector) else {
            NetworkLogger.log("Swizzled method not found: \(swizzledSelector)", level: .error)
            return
        }

        originalIMPStorage = method_getImplementation(originalMethod)

        let oldImp = class_replaceMethod(
            targetMetaClass,
            originalSelector,
            method_getImplementation(swizzledMethod),
            method_getTypeEncoding(originalMethod)
        )

        if oldImp != nil {
            NetworkLogger.log("Swizzled \(name) successfully.", level: .info)
        } else {
            NetworkLogger.log("Swizzle fallback: \(name) may not have existed directly.", level: .debug)
        }

        NetworkLogger.log("Completed swizzle: \(name)", level: .debug)
    }

    // MARK: - Swizzled Methods

    @objc static func swizzled_defaultSessionConfiguration() -> URLSessionConfiguration {
        guard let imp = originalDefaultSessionConfigurationIMP else {
            fatalError("Missing IMP for defaultSessionConfiguration.")
        }
        typealias Function = @convention(c) (AnyClass, Selector) -> URLSessionConfiguration
        let original = unsafeBitCast(imp, to: Function.self)
        let config = original(self, #selector(getter: URLSessionConfiguration.default))
        NetworkMonitor.shared.addURLProtocolToConfiguration(config, type: "defaultSessionConfiguration")
        return config
    }

    @objc static func swizzled_ephemeralSessionConfiguration() -> URLSessionConfiguration {
        guard let imp = originalEphemeralSessionConfigurationIMP else {
            fatalError("Missing IMP for ephemeralSessionConfiguration.")
        }
        typealias Function = @convention(c) (AnyClass, Selector) -> URLSessionConfiguration
        let original = unsafeBitCast(imp, to: Function.self)
        let config = original(self, #selector(getter: URLSessionConfiguration.ephemeral))
        NetworkMonitor.shared.addURLProtocolToConfiguration(config, type: "ephemeralSessionConfiguration")
        return config
    }

    @objc static func swizzled_backgroundSessionConfigurationWithIdentifier(_ identifier: String) -> URLSessionConfiguration {
        guard let imp = originalBackgroundSessionConfigurationWithIdentifierIMP else {
            fatalError("Missing IMP for backgroundSessionConfigurationWithIdentifier.")
        }
        typealias Function = @convention(c) (AnyClass, Selector, String) -> URLSessionConfiguration
        let original = unsafeBitCast(imp, to: Function.self)
        let config = original(self, NSSelectorFromString("backgroundSessionConfigurationWithIdentifier:"), identifier)
        NetworkMonitor.shared.addURLProtocolToConfiguration(config, type: "backgroundSessionConfigurationWithIdentifier")
        return config
    }
}

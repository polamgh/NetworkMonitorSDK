//
//  NetworkMonitorSDKTests.swift
//  NetworkMonitorSDKTests
//
//  Created by Ali Ghanavati on 2025-06-28.
//

import XCTest
@testable import NetworkMonitorSDK

final class NetworkMonitorSDKTests: XCTestCase {

    override func setUpWithError() throws {
        NetworkMonitorStorage.shared.clearAllLogs()
        NetworkMonitor.startMonitoring()
    }

    override func tearDownWithError() throws {
        NetworkMonitor.stopMonitoring()
        NetworkMonitorStorage.shared.clearAllLogs()
    }

    func testBasicSuccessfulRequestIsLogged() throws {
        let expectation = XCTestExpectation(description: "Successful request is logged")
        let url = URL(string: "https://apple.com")!

        URLSession.shared.dataTask(with: url) { _, _, _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                NetworkMonitorStorage.shared.getAllLogs { logs in
                    XCTAssertEqual(logs.count, 1)
                    XCTAssertTrue(logs[0].isSuccessful)
                    XCTAssertEqual(logs[0].initialURL, url.absoluteString)
                    expectation.fulfill()
                }
            }
        }.resume()

        wait(for: [expectation], timeout: 10)
    }

    func testRedirectionIsDetected() throws {
        let expectation = XCTestExpectation(description: "Redirection is tracked")
        let url = URL(string: "http://yahoo.com")!

        URLSession.shared.dataTask(with: url) { _, _, _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                NetworkMonitorStorage.shared.getAllLogs { logs in
                    XCTAssertEqual(logs.count, 1)
                    let log = logs[0]
                    XCTAssertNotEqual(log.initialURL, log.finalURL)
                    XCTAssertTrue(log.isSuccessful)
                    expectation.fulfill()
                }
            }
        }.resume()

    }

    func testFailureRequestIsLogged() throws {
        let expectation = XCTestExpectation(description: "Failed request is logged")
        let url = URL(string: "https://polamgh2.com")!

        URLSession.shared.dataTask(with: url) { _, _, _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                NetworkMonitorStorage.shared.getAllLogs { logs in
                    XCTAssertEqual(logs.count, 1)
                    XCTAssertFalse(logs[0].isSuccessful)
                    expectation.fulfill()
                }
            }
        }.resume()

        wait(for: [expectation], timeout: 10)
    }

    func testLogFilePersistsToDisk() throws {
        let expectation = XCTestExpectation(description: "Log file saved")
        let url = URL(string: "https://apple.com")!

        URLSession.shared.dataTask(with: url) { _, _, _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                guard let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
                    XCTFail("Documents directory not found")
                    expectation.fulfill()
                    return
                }
                let path = dir.appendingPathComponent("network_logs.json")
                XCTAssertTrue(FileManager.default.fileExists(atPath: path.path))
                if let data = try? Data(contentsOf: path),
                   let decoded = try? JSONDecoder().decode([NetworkConnectionLog].self, from: data) {
                    XCTAssertFalse(decoded.isEmpty)
                } else {
                    XCTFail("Log file not readable or decodable")
                }
                expectation.fulfill()
            }
        }.resume()

        wait(for: [expectation], timeout: 12)
    }

    func testMultipleRequestsAreAllLogged() throws {
        let expectation = XCTestExpectation(description: "All requests are logged")
        expectation.expectedFulfillmentCount = 2

        let urls = ["https://apple.com", "http://polamgh.com"].compactMap(URL.init)
        urls.forEach { url in
            URLSession.shared.dataTask(with: url) { _, _, _ in
                expectation.fulfill()
            }.resume()
        }

        wait(for: [expectation], timeout: 10)

        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            NetworkMonitorStorage.shared.getAllLogs { logs in
                XCTAssertEqual(logs.count, 2)
            }
        }
    }
}

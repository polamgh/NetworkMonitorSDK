//
//  NetworkMonitorURLProtocol.swift
//  NetworkMonitorSDK
//
//  Created by Ali Ghanavati on 2025-06-28.
//

import Foundation

/// A custom URLProtocol that intercepts and logs all HTTP/HTTPS requests for monitoring purposes.
final class NetworkMonitorURLProtocol: URLProtocol {

    private static let requestHandledKey = "NetworkMonitorURLProtocolHandledKey"

    override class func canInit(with request: URLRequest) -> Bool {
        guard
            URLProtocol.property(forKey: requestHandledKey, in: request) == nil,
            let url = request.url,
            ["http", "https"].contains(url.scheme?.lowercased())
        else {
            return false
        }
        return true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        return request
    }

    override func startLoading() {
        guard let mutableRequest = (request as NSURLRequest).mutableCopy() as? NSMutableURLRequest else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }

        URLProtocol.setProperty(true, forKey: Self.requestHandledKey, in: mutableRequest)

        let cleanConfig = URLSessionConfiguration.default
        cleanConfig.protocolClasses = cleanConfig.protocolClasses?.filter { $0 != Self.self }

        let session = URLSession(configuration: cleanConfig, delegate: self, delegateQueue: nil)

        let task: URLSessionTask

        let method = mutableRequest.httpMethod 

        if mutableRequest.httpBodyStream != nil {
            // Upload with stream
            task = session.uploadTask(withStreamedRequest: mutableRequest as URLRequest)
        } else if ["POST", "PUT", "PATCH"].contains(method.uppercased()) {
            if let body = mutableRequest.httpBody {
                // Upload with body data
                task = session.uploadTask(with: mutableRequest as URLRequest, from: body)
            } else {
                // Fallback to dataTask
                task = session.dataTask(with: mutableRequest as URLRequest)
            }
        } else {
            // For GET/DELETE etc.
            task = session.dataTask(with: mutableRequest as URLRequest)
        }

        NetworkMonitor.shared.trackTaskCreation(
            taskIdentifier: task.taskIdentifier,
            initialURL: mutableRequest.url ?? URL(string: "about:blank")!,
            type: "URLProtocol_Handled"
        )
        task.resume()
    }

    override func stopLoading() {}
}

// MARK: - URLSession Delegate

extension NetworkMonitorURLProtocol: URLSessionDelegate, URLSessionDataDelegate {

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        NetworkMonitor.shared.trackTaskCompletion(
            taskIdentifier: task.taskIdentifier,
            response: task.response,
            error: error
        )

        if let error = error {
            client?.urlProtocol(self, didFailWithError: error)
        } else {
            client?.urlProtocolDidFinishLoading(self)
        }
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        completionHandler(.allow)
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        client?.urlProtocol(self, didLoad: data)
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        client?.urlProtocol(self, wasRedirectedTo: request, redirectResponse: response)
        completionHandler(request)
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, needNewBodyStream completionHandler: @escaping (InputStream?) -> Void) {
        completionHandler(nil)
    }
}

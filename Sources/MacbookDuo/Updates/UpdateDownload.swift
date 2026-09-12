import Foundation
import FoldCore

/// Reject untrusted redirects and enforce the byte limit while receiving, not afterwards.
final class UpdateDownload: NSObject, URLSessionDataDelegate, @unchecked Sendable {
    private let maximum: Int
    private var received = Data()
    private var completion: CheckedContinuation<Data, Error>?
    private var failure: Error?
    private var session: URLSession?
    init(maximum: Int) { self.maximum = maximum }

    static func fetch(_ url: URL, maximum: Int) async throws -> Data {
        let download = UpdateDownload(maximum:maximum)
        return try await withCheckedThrowingContinuation { continuation in
            download.completion = continuation
            let configuration = URLSessionConfiguration.ephemeral
            configuration.timeoutIntervalForRequest = 30
            configuration.timeoutIntervalForResource = 180
            configuration.urlCache = nil;configuration.httpCookieStorage = nil
            let session = URLSession(configuration:configuration,delegate:download,delegateQueue:nil)
            download.session = session
            var request = URLRequest(url:url)
            request.setValue("MacbookDuo-Updater",forHTTPHeaderField:"User-Agent")
            request.setValue("application/vnd.github+json",forHTTPHeaderField:"Accept")
            session.dataTask(with:request).resume()
        }
    }
    private static func allowed(_ url: URL?) -> Bool {
        guard let url, url.scheme == "https", url.user == nil, url.password == nil,
              url.port == nil || url.port == 443 else { return false }
        return ["api.github.com","github.com","release-assets.githubusercontent.com","objects.githubusercontent.com"].contains(url.host ?? "")
    }
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        guard Self.allowed(request.url) else {
            failure = UpdateError.invalid("GitHub redirected the download to an unexpected location.")
            completionHandler(nil);return
        }
        completionHandler(request)
    }
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse,
                    completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        guard Self.allowed(response.url), let response = response as? HTTPURLResponse, response.statusCode == 200,
              response.expectedContentLength <= maximum else {
            failure = UpdateError.invalid("GitHub could not provide the update. Check your connection and try again later.")
            completionHandler(.cancel);return
        }
        completionHandler(.allow)
    }
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        guard received.count <= maximum-data.count else {
            failure = UpdateError.invalid("The update download exceeded its size limit.");dataTask.cancel();return
        }
        received.append(data)
    }
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = failure ?? error { completion?.resume(throwing:error) }
        else { completion?.resume(returning:received) }
        completion = nil;session.invalidateAndCancel();self.session = nil
    }
}

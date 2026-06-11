import Foundation

extension Error {
    /// Whether this error is a cooperative task cancellation or a URLSession
    /// request cancellation, rather than a genuine failure.
    ///
    /// SwiftUI cancels a view's `.task` when the view leaves the hierarchy — e.g.
    /// switching tabs tears down the Bookmarks `.task` mid-request. The in-flight
    /// call then throws (a `CancellationError`, or `URLError.cancelled` from
    /// `URLSession`), and surfacing that as an error state flashes
    /// "Something went wrong" on a screen the user just navigated back to.
    /// Loaders check this to skip the error UI on teardown.
    var isCancellation: Bool {
        if self is CancellationError { return true }
        let nsError = self as NSError
        return nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled
    }
}

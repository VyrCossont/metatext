// Copyright © 2024 Vyr Cossont. All rights reserved.

import Foundation

// TODO: (Vyr) Swift 6: require errors to implement AnnotatedError
/// HTTP request rate limiter that can optionally use target and response header info.
public protocol RateLimiter: Sendable {
    /// Call this before making a request.
    /// Returns immediately if there is capacity left.
    /// Otherwise, waits until there is capacity again.
    func request(_ target: Target) async throws
    /// Call this with the HTTP response
    func update(_ target: Target, _ response: HTTPURLResponse) async throws
}

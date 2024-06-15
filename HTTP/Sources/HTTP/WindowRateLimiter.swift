// Copyright © 2024 Vyr Cossont. All rights reserved.

import Foundation

/// Rate limiter using `X-RateLimit` headers from Mastodon or GotoSocial.
public actor WindowRateLimiter: RateLimiter {
    private(set) public var limit: Int
    private(set) public var remaining: Int
    private(set) public var reset: Date

    public init(limit: Int, remaining: Int, reset: Date) {
        self.limit = limit
        self.remaining = remaining
        self.reset = reset
    }

    public func request(_ target: Target) async throws {
        if remaining == 0 {
            try await Task.sleep(nanoseconds: UInt64(reset.timeIntervalSinceNow) * NSEC_PER_SEC)
            remaining = limit
        }

        remaining -= 1
    }

    public func update(_ target: Target, _ response: HTTPURLResponse) {
        if let limit = response.value(forHTTPHeaderField: "X-RateLimit-Limit").flatMap(Int.init) {
            self.limit = limit
        }
        if let remaining = response.value(forHTTPHeaderField: "X-RateLimit-Remaining").flatMap(Int.init) {
            self.remaining = remaining
        }
        if let string = response.value(forHTTPHeaderField: "X-RateLimit-Reset"),
           let reset = Self.dateFormatter.date(from: string) {
            self.reset = reset
        }
    }

    /// Both Mastodon and GtS use RFC 3339 timestamps with fractional seconds for the reset.
    private static let dateFormatter: ISO8601DateFormatter = {
        let dateFormatter = ISO8601DateFormatter()

        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        return dateFormatter
    }()
}

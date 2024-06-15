// Copyright © 2024 Vyr Cossont. All rights reserved.

import Foundation
import HTTP

/// Rate limiter aware of Mastodon-specific configuration.
/// Assumes a single logged-in account.
/// May not match other or customized instances.
/// - See: https://docs.joinmastodon.org/api/rate-limits/#limits
public actor MastodonRateLimiter: RateLimiter {
    private let `default`: RateLimiter = WindowRateLimiter(
        limit: 300,
        remaining: 300,
        reset: Date.now.addingTimeInterval(5 * 60)
    )

    private let mediaUpload: RateLimiter = WindowRateLimiter(
        limit: 30,
        remaining: 30,
        reset: Date.now.addingTimeInterval(30 * 60)
    )

    private let deleteUnreblog: RateLimiter = WindowRateLimiter(
        limit: 30,
        remaining: 30,
        reset: Date.now.addingTimeInterval(30 * 60)
    )

    public init() {}

    public func request(_ target: Target) async throws {
        try await limiter(target).request(target)
    }
    
    public func update(_ target: Target, _ response: HTTPURLResponse) async throws {
        try await limiter(target).update(target, response)
    }

    private func limiter(_ target: Target) -> RateLimiter {
        if let mastodonTarget = target as? MastodonAPITarget<AttachmentEndpoint>,
           case AttachmentEndpoint.create = mastodonTarget.endpoint {
            return mediaUpload
        }

        if let mastodonTarget = target as? MastodonAPITarget<StatusEndpoint> {
            switch mastodonTarget.endpoint {
            case .delete, .unreblog:
                return deleteUnreblog
            default:
                break
            }
        }

        return `default`
    }
}

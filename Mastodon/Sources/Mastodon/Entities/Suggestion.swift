// Copyright © 2023 Vyr Cossont. All rights reserved.

import Foundation

/// A suggested account to follow, with attached reason.
/// https://docs.joinmastodon.org/entities/Suggestion/
public struct Suggestion: Codable, Hashable, Sendable {
    /// https://docs.joinmastodon.org/entities/Suggestion/#source
    public enum Source: String, Codable, Unknowable, Sendable {
        case staff
        case pastInteractions = "past_interactions"
        case global
        case unknown

        public static var unknownCase: Self { .unknown }
    }

    public let source: Source
    /// New in Mastodon 4.3. Should never be empty, will always contain `source` as an element.
    public let sources: [Source]?
    public var unifiedSources: [Source] {
        sources ?? [source]
    }

    public let account: Account
}

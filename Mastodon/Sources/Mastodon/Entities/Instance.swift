// Copyright © 2020 Metabolist. All rights reserved.

import Foundation

// swiftlint:disable nesting

/// Result of calling the Mastodon v1 instance API, a mix of instance metadata and client configuration.
/// See also: `DB.Identity.Instance` summary version in identity database.
public struct Instance: Codable {
    public let uri: String
    /// Mastodon servers use a bare domain in the `uri` field,
    /// but Akkoma and GotoSocial (at least) use an `https://` URL.
    public var domain: String {
        if let url = URL(string: uri), let host = url.host {
            return host
        } else {
            return uri
        }
    }
    public let title: String
    public let description: HTML
    public let shortDescription: String?
    public let email: String
    public let version: String
    @DecodableDefault.EmptyList public private(set) var languages: [String]
    @DecodableDefault.False public private(set) var registrations: Bool
    @DecodableDefault.False public private(set) var approvalRequired: Bool
    @DecodableDefault.False public private(set) var invitesEnabled: Bool
    public let urls: URLs
    public let stats: Stats
    public let thumbnail: UnicodeURL?
    public let contactAccount: Account?

    /// Present in everything except vanilla Mastodon and Firefish.
    public let maxTootChars: Int?
    /// Not present in Pleroma or Akkoma.
    public let configuration: Configuration?

    public var unifiedMaxTootChars: Int? {
        configuration?.statuses?.maxCharacters ?? maxTootChars
    }

    @DecodableDefault.EmptyList public private(set) var rules: [Rule]

    public init(
        uri: String,
        title: String,
        description: HTML,
        shortDescription: String?,
        email: String,
        version: String,
        urls: Instance.URLs,
        stats: Instance.Stats,
        thumbnail: UnicodeURL?,
        contactAccount: Account?,
        maxTootChars: Int?,
        configuration: Configuration?,
        rules: [Rule]
    ) {
        self.uri = uri
        self.title = title
        self.description = description
        self.shortDescription = shortDescription
        self.email = email
        self.version = version
        self.urls = urls
        self.stats = stats
        self.thumbnail = thumbnail
        self.contactAccount = contactAccount
        self.maxTootChars = maxTootChars
        self.configuration = configuration
        self.rules = rules
    }
}

extension Instance: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(uri)
    }
}

public extension Instance {
    struct URLs: Codable, Hashable {
        public let streamingApi: UnicodeURL?
    }

    struct Stats: Codable, Hashable {
        public let userCount: Int
        public let statusCount: Int
        public let domainCount: Int
    }

    struct Configuration: Codable, Hashable {
        public struct Accounts: Codable, Hashable {
            public let maxFeaturedTags: Int?
            public let maxProfileFields: Int?
            // TODO: (Vyr) max_pinned_statuses might be instance API v2 only
            public let maxPinnedStatuses: Int?
            /// GotoSocial only.
            public let allowCustomCss: Bool?

            init(
                maxFeaturedTags: Int?,
                maxProfileFields: Int?,
                maxPinnedStatuses: Int?,
                allowCustomCss: Bool?
            ) {
                self.maxFeaturedTags = maxFeaturedTags
                self.maxProfileFields = maxProfileFields
                self.maxPinnedStatuses = maxPinnedStatuses
                self.allowCustomCss = allowCustomCss
            }
        }

        public struct Statuses: Codable, Hashable {
            public let maxCharacters: Int?
            public let maxMediaAttachments: Int?
            public let charactersReservedPerUrl: Int?
            /// GotoSocial and Glitch only.
            public let supportedMimeTypes: [String]?

            public init(
                maxCharacters: Int?,
                maxMediaAttachments: Int?,
                charactersReservedPerUrl: Int?,
                supportedMimeTypes: [String]?
            ) {
                self.maxCharacters = maxCharacters
                self.maxMediaAttachments = maxMediaAttachments
                self.charactersReservedPerUrl = charactersReservedPerUrl
                self.supportedMimeTypes = supportedMimeTypes
            }
        }

        public struct MediaAttachments: Codable, Hashable {
            public let supportedMimeTypes: [String]?
            public let imageSizeLimit: Int?
            public let imageMatrixLimit: Int?
            public let videoSizeLimit: Int?
            public let videoFrameRateLimit: Int?
            public let videoMatrixLimit: Int?

            init(
                supportedMimeTypes: [String]?,
                imageSizeLimit: Int?,
                imageMatrixLimit: Int?,
                videoSizeLimit: Int?,
                videoFrameRateLimit: Int?,
                videoMatrixLimit: Int?
            ) {
                self.supportedMimeTypes = supportedMimeTypes
                self.imageSizeLimit = imageSizeLimit
                self.imageMatrixLimit = imageMatrixLimit
                self.videoSizeLimit = videoSizeLimit
                self.videoFrameRateLimit = videoFrameRateLimit
                self.videoMatrixLimit = videoMatrixLimit
            }
        }

        public struct Polls: Codable, Hashable {
            public let maxOptions: Int?
            public let maxCharactersPerOption: Int?
            public let minExpiration: Int?
            public let maxExpiration: Int?

            public init(
                maxOptions: Int?,
                maxCharactersPerOption: Int?,
                minExpiration: Int?,
                maxExpiration: Int?
            ) {
                self.maxOptions = maxOptions
                self.maxCharactersPerOption = maxCharactersPerOption
                self.minExpiration = minExpiration
                self.maxExpiration = maxExpiration
            }
        }

        public struct Translation: Codable, Hashable {
            public let enabled: Bool?

            public init(enabled: Bool?) {
                self.enabled = enabled
            }
        }

        /// Present only in Glitch instances running PR #2221.
        public struct Reactions: Codable, Hashable {
            public let maxReactions: Int?

            public init(maxReactions: Int?) {
                self.maxReactions = maxReactions
            }
        }

        public let accounts: Accounts?
        public let statuses: Statuses?
        public let mediaAttachments: MediaAttachments?
        public let polls: Polls?
        public let translation: Translation?
        public let reactions: Reactions?

        public init(
            accounts: Accounts?,
            statuses: Statuses?,
            mediaAttachments: MediaAttachments?,
            polls: Polls?,
            translation: Translation?,
            reactions: Reactions?
        ) {
            self.accounts = accounts
            self.statuses = statuses
            self.mediaAttachments = mediaAttachments
            self.polls = polls
            self.translation = translation
            self.reactions = reactions
        }
    }

}

// swiftlint:enable nesting

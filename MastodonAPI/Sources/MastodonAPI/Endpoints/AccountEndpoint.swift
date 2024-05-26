// Copyright © 2020 Metabolist. All rights reserved.

import Foundation
import HTTP
import Mastodon
import Semver

public enum AccountEndpoint {
    case verifyCredentials
    case updateCredentials(UpdateCredentialsRequest)
    case accounts(id: Account.Id)
    case deleteAvatar
    case deleteHeader
}

extension AccountEndpoint: Endpoint {
    public typealias ResultType = Account

    public var context: [String] {
        switch self {
        case .verifyCredentials, .updateCredentials, .accounts:
            return defaultContext + ["accounts"]
        case .deleteAvatar, .deleteHeader:
            return defaultContext + ["profile"]
        }
    }

    public var pathComponentsInContext: [String] {
        switch self {
        case .verifyCredentials: return ["verify_credentials"]
        case .updateCredentials: return ["update_credentials"]
        case let .accounts(id): return [id]
        case .deleteAvatar: return ["avatar"]
        case .deleteHeader: return ["header"]
        }
    }

    public var method: HTTPMethod {
        switch self {
        case .verifyCredentials, .accounts: return .get
        case .updateCredentials: return .patch
        case .deleteAvatar, .deleteHeader: return .delete
        }
    }

    public var multipartFormData: [String: MultipartFormValue]? {
        switch self {
        case .verifyCredentials, .accounts, .deleteAvatar, .deleteHeader:
            return nil
        case let .updateCredentials(request):
            return request.multipartFormData
        }
    }

    public var notFound: EntityNotFound? {
        switch self {
        case .verifyCredentials, .updateCredentials, .deleteAvatar, .deleteHeader:
            return nil
        case .accounts(let id):
            return .account(id)
        }
    }

    public var requires: APICapabilityRequirements? {
        switch self {
        case .verifyCredentials, .accounts:
            return nil
        case .deleteAvatar, .deleteHeader:
            return .mastodonForks("4.2.0") | [
                .gotosocial: "0.16.0-0"
            ]
        case let .updateCredentials(request):
            return request.requires
        }
    }
}

public extension AccountEndpoint {
    /// - See: <https://docs.joinmastodon.org/methods/accounts/#form-data-parameters-1>
    struct UpdateCredentialsRequest {
        let displayName: String?
        let note: String?
        let avatar: Data?
        let avatarMimeType: String?
        let header: Data?
        let headerMimeType: String?
        let locked: Bool?
        let bot: Bool?
        let discoverable: Bool?
        let hideCollections: Bool?
        /// Mastodon 4.2 only (so far).
        let indexable: Bool?
        let fields: [Account.Source.Field]?
        let privacy: Status.Visibility?
        let sensitive: Bool?
        let language: String?

        /// Default MIME type to interpret posts as.
        /// GotoSocial only: `text/plain` or `text/markdown`.
        /// Glitch doesn't extend the API to set this.
        let statusContentType: String?

        /// File name of theme to use. Send empty string to unset it.
        /// GotoSocial only.
        let theme: String?

        /// Custom CSS to use when rendering this account's profile or statuses.
        /// Limited to 5k chars by default.
        /// GotoSocial only.
        let customCSS: String?

        /// Enable RSS feed for this account's public posts.
        /// GotoSocial only.
        let enableRSS: Bool?

        public init(
            displayName: String?,
            note: String?,
            avatar: Data?,
            avatarMimeType: String?,
            header: Data?,
            headerMimeType: String?,
            locked: Bool?,
            bot: Bool?,
            discoverable: Bool?,
            hideCollections: Bool?,
            indexable: Bool?,
            fields: [Account.Source.Field]?,
            privacy: Status.Visibility?,
            sensitive: Bool?,
            language: String?,
            statusContentType: String?,
            theme: String?,
            customCSS: String?,
            enableRSS: Bool?
        ) {
            self.displayName = displayName
            self.note = note
            self.avatar = avatar
            self.avatarMimeType = avatarMimeType
            self.header = header
            self.headerMimeType = headerMimeType
            self.locked = locked
            self.bot = bot
            self.discoverable = discoverable
            self.hideCollections = hideCollections
            self.indexable = indexable
            self.fields = fields
            self.privacy = privacy
            self.sensitive = sensitive
            self.language = language
            self.statusContentType = statusContentType
            self.theme = theme
            self.customCSS = customCSS
            self.enableRSS = enableRSS
        }

        public var multipartFormData: [String: MultipartFormValue] {
            var params = [String: MultipartFormValue]()

            params.add("display_name", displayName)
            params.add("note", note)
            params.add("avatar", avatar, avatarMimeType)
            params.add("header", header, headerMimeType)
            params.add("locked", locked)
            params.add("bot", bot)
            params.add("discoverable", discoverable)
            params.add("hide_collections", hideCollections)
            params.add("indexable", indexable)
            params.add("source[privacy]", privacy?.rawValue)
            params.add("source[sensitive]", sensitive)
            params.add("source[language]", language)
            params.add("source[status_content_type]", statusContentType)
            params.add("theme", theme)
            params.add("custom_css", customCSS)
            params.add("enable_rss", enableRSS)

            if let fields = fields {
                for (index, field) in fields.enumerated() {
                    params["fields_attributes[\(index)][name]"] = .string(field.name)
                    params["fields_attributes[\(index)][value]"] = .string(field.value)
                }
            }

            return params
        }

        var requires: APICapabilityRequirements? {
            // Mastodon-specific feature.
            if indexable != nil {
                return .mastodonForks("3.5.0")
            }

            // GotoSocial-specific features.
            func requireAtLeast(_ accumulator: inout Semver?, _ requirement: Semver) {
                if let version = accumulator {
                    accumulator = max(version, requirement)
                } else {
                    accumulator = requirement
                }
            }
            var gtsVersion: Semver?
            if statusContentType != nil {
                requireAtLeast(&gtsVersion, .assumeAvailable)
            }
            if theme != nil {
                requireAtLeast(&gtsVersion, "0.15.0")
            }
            if customCSS != nil {
                requireAtLeast(&gtsVersion, .assumeAvailable)
            }
            if enableRSS != nil {
                requireAtLeast(&gtsVersion, .assumeAvailable)
            }
            if let gtsVersion = gtsVersion {
                return [.gotosocial: gtsVersion]
            }

            return nil
        }
    }
}

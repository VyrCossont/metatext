// Copyright © 2020 Metabolist. All rights reserved.

import Foundation
import HTTP
import Mastodon
import Semver

public enum AccountEndpoint {
    /// Fetch the current user's profile with extra info used when editing it.
    case verifyCredentials
    /// Update the current user's profile.
    case updateCredentials(UpdateCredentialsRequest)
    /// Delete the current user's avatar.
    case deleteAvatar
    /// Delete the current user's header.
    case deleteHeader
    /// Fetch any account by ID.
    case accounts(id: Account.Id)
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
            // TODO: (Vyr) go through every implementation to check supported fields
            // TODO: (Vyr) snac2 doesn't have this API endpoint at all
            return request.requires
        }
    }
}

public extension AccountEndpoint {
    /// - See: <https://docs.joinmastodon.org/methods/accounts/#form-data-parameters-1>
    struct UpdateCredentialsRequest {
        public var displayName: String?
        public var note: String?
        public var avatar: Data?
        public var avatarMimeType: String?
        public var header: Data?
        public var headerMimeType: String?
        public var locked: Bool?
        public var bot: Bool?
        public var discoverable: Bool?
        /// Requires Mastodon 4.1 or GotoSocial 0.15.
        public var hideCollections: Bool?
        /// Requires Mastodon 4.2.
        public var indexable: Bool?
        public var fields: [Account.Source.Field]?
        public var privacy: Status.Visibility?
        public var sensitive: Bool?
        public var language: String?

        /// Default MIME type to interpret posts as.
        /// GotoSocial only: `text/plain` or `text/markdown`.
        /// Glitch doesn't extend the API to set this.
        public var statusContentType: ContentType?

        /// File name of theme to use. Send empty string to unset it.
        /// GotoSocial only.
        public var theme: String?

        /// Custom CSS to use when rendering this account's profile or statuses.
        /// Limited to 5k chars by default.
        /// GotoSocial only.
        public var customCSS: String?

        /// Enable RSS feed for this account's public posts.
        /// GotoSocial only.
        public var enableRSS: Bool?

        public init(
            displayName: String? = nil,
            note: String? = nil,
            avatar: Data? = nil,
            avatarMimeType: String? = nil,
            header: Data? = nil,
            headerMimeType: String? = nil,
            locked: Bool? = nil,
            bot: Bool? = nil,
            discoverable: Bool? = nil,
            hideCollections: Bool? = nil,
            indexable: Bool? = nil,
            fields: [Account.Source.Field]? = nil,
            privacy: Status.Visibility? = nil,
            sensitive: Bool? = nil,
            language: String? = nil,
            statusContentType: ContentType? = nil,
            theme: String? = nil,
            customCSS: String? = nil,
            enableRSS: Bool? = nil
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

        public var isEmpty: Bool {
            displayName == nil &&
            note == nil &&
            avatar == nil &&
            avatarMimeType == nil &&
            header == nil &&
            headerMimeType == nil &&
            locked == nil &&
            bot == nil &&
            discoverable == nil &&
            hideCollections == nil &&
            indexable == nil &&
            fields == nil &&
            privacy == nil &&
            sensitive == nil &&
            language == nil &&
            statusContentType == nil &&
            theme == nil &&
            customCSS == nil &&
            enableRSS == nil
        }

        var multipartFormData: [String: MultipartFormValue] {
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
            params.add("source[status_content_type]", statusContentType?.rawValue)
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
            // Requirement for each parameter.
            var paramRequirements = [APICapabilityRequirements]()

            // Mastodon-specific feature.
            if indexable != nil {
                paramRequirements.append(.mastodonForks("4.2.0"))
            }

            // GotoSocial-specific features.
            if statusContentType != nil {
                paramRequirements.append([.gotosocial: .assumeAvailable])
            }
            if theme != nil {
                paramRequirements.append([.gotosocial: "0.15.0"])
            }
            if customCSS != nil {
                paramRequirements.append([.gotosocial: .assumeAvailable])
            }
            if enableRSS != nil {
                paramRequirements.append([.gotosocial: .assumeAvailable])
            }

            // Features supported by both Mastodon and GotoSocial but nothing else.
            if hideCollections != nil {
                paramRequirements.append(.mastodonForks("4.1.0") | [.gotosocial: "0.15.0"])
            }

            // If there are no implementation-specific requirements, return early.
            guard let first = paramRequirements.first else { return nil }

            // Return a requirement that covers all parameters.
            // In the event of an illegal combination of parameters, this will be unsatisifable.
            return paramRequirements.dropFirst().reduce(first, { $0 & $1 })
        }
    }
}

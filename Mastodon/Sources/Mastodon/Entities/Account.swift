// Copyright © 2020 Metabolist. All rights reserved.

import Foundation

// swiftlint:disable nesting

/// User (or group) account.
/// May have additional properties depending on which API it was fetched from.
/// This is a class because it may contain another `Account` in the `moved` field.
/// - See: <https://docs.joinmastodon.org/entities/Account/>
public final class Account: Codable, Identifiable {
    public let id: Id
    public let username: String
    public let acct: String
    public let displayName: String
    public let locked: Bool
    public let createdAt: Date
    public let followersCount: Int
    public let followingCount: Int
    public let statusesCount: Int
    public let lastStatusAt: Date?
    public let note: HTML
    public let url: String

    public let avatar: UnicodeURL
    public let avatarStatic: UnicodeURL?
    /// Hajkey doesn't return URLs for non-animated versions of image assets.
    public var unifiedAvatarStatic: UnicodeURL {
        avatarStatic ?? avatar
    }

    public let header: UnicodeURL
    public let headerStatic: UnicodeURL?
    /// Hajkey doesn't return URLs for non-animated versions of image assets.
    public var unifiedHeaderStatic: UnicodeURL {
        headerStatic ?? header
    }

    @DecodableDefault.EmptyList public private(set) var fields: [Field]
    @DecodableDefault.EmptyList public private(set) var emojis: [Emoji]
    @DecodableDefault.False public private(set) var bot: Bool
    @DecodableDefault.False public private(set) var group: Bool
    @DecodableDefault.False public private(set) var suspended: Bool
    @DecodableDefault.False public private(set) var limited: Bool

    /// Used when editing your own account.
    public let discoverable: Bool?
    /// Used when editing your own account.
    /// Note: the API for *editing* the account inverts this and calls it `indexable`.
    public let noindex: Bool?
    /// Used when editing your own account.
    public let hideCollections: Bool?

    public let moved: Account?
    public let role: Role?

    /// File name of theme to use.
    /// GotoSocial only.
    public let theme: String?

    /// Enable RSS feed for this account's public posts.
    /// GotoSocial only.
    public let enableRss: Bool?

    /// Custom CSS to use when rendering this account's profile or statuses.
    /// Feditext only supports this in order to let the user edit it, not to style text.
    /// GotoSocial only.
    public let customCss: String?

    /// Only present when calling the verify credentials endpoint.
    /// Used when editing your own account.
    public let source: Source?

    /// Only present when retrieving the list of muted accounts.
    /// - See: <https://docs.joinmastodon.org/entities/Account/#mute_expires_at>
    public let muteExpiresAt: Date?

    public init(
        id: Id,
        username: String,
        acct: String,
        displayName: String,
        locked: Bool,
        createdAt: Date,
        followersCount: Int,
        followingCount: Int,
        statusesCount: Int,
        lastStatusAt: Date?,
        note: HTML,
        url: String,
        avatar: UnicodeURL,
        avatarStatic: UnicodeURL,
        header: UnicodeURL,
        headerStatic: UnicodeURL,
        fields: [Account.Field],
        emojis: [Emoji],
        bot: Bool,
        group: Bool,
        suspended: Bool,
        limited: Bool,
        discoverable: Bool?,
        noindex: Bool?,
        hideCollections: Bool?,
        moved: Account?,
        source: Source?,
        role: Role?,
        theme: String?,
        enableRSS: Bool?,
        customCSS: String?,
        muteExpiresAt: Date?
    ) {
        self.id = id
        self.username = username
        self.acct = acct
        self.displayName = displayName
        self.locked = locked
        self.createdAt = createdAt
        self.followersCount = followersCount
        self.followingCount = followingCount
        self.statusesCount = statusesCount
        self.lastStatusAt = lastStatusAt
        self.note = note
        self.url = url
        self.avatar = avatar
        self.avatarStatic = avatarStatic
        self.header = header
        self.headerStatic = headerStatic
        self.discoverable = discoverable
        self.noindex = noindex
        self.hideCollections = hideCollections
        self.moved = moved
        self.source = source
        self.role = role
        self.muteExpiresAt = muteExpiresAt
        self.theme = theme
        self.enableRss = enableRSS
        self.customCss = customCSS
        self.fields = fields
        self.emojis = emojis
        self.bot = bot
        self.group = group
        self.suspended = suspended
        self.limited = limited
    }
}

public extension Account {
    typealias Id = String

    struct Field: Codable, Hashable {
        public let name: String
        public let value: HTML
        public let verifiedAt: Date?
    }

    /// - See: <https://docs.joinmastodon.org/entities/Account/#source>
    struct Source: Codable, Hashable {
        public let note: String?
        public let fields: [Field]
        public let privacy: Status.Visibility?
        public let sensitive: Bool?
        public let language: String?
        public let followRequestsCount: Int?
        @DecodableDefault.False public private(set) var discoverable: Bool
        /// Opposite-sense source flag for `Account.noindex`.
        /// Only implemented by Mastodon 4.3 as of 2024-05-21.
        @DecodableDefault.False public private(set) var indexable: Bool
        /// Not documented by Mastodon, but present in at least 4.3. Documented by GotoSocial.
        @DecodableDefault.False public private(set) var hideCollections: Bool

        /// Default MIME type for posts. GotoSocial only.
        public let statusContentType: String?

        /// Account aliases. GotoSocial only.
        /// - See: <https://docs.gotosocial.org/en/latest/user_guide/settings/#alias-account>
        public let alsoKnownAsUris: [String]?

        /// Source variant of `Account.Field`.
        /// Value is the source text (not HTML) and we don't care about the verified date.
        public struct Field: Codable, Hashable {
            public let name: String
            public let value: String
        }
    }

    /// Local user role assigned by the server admin.
    /// Note that while Mastodon roles may have the full set of properties,
    /// GotoSocial roles only have a name.
    /// - See: <https://docs.joinmastodon.org/entities/Role/>
    struct Role: Codable, Hashable {
        public typealias Id = String

        public let id: Id?
        public let name: String
        public let color: HexColor?
        public let permissions: Permissions?
        public let highlighted: Bool?

        /// - See: <https://docs.joinmastodon.org/entities/Role/#permission-flags>
        public struct Permissions: OptionSet, CaseIterable, Hashable {
            public let rawValue: Int

            public init(rawValue: Int) {
                self.rawValue = rawValue
            }

            public static let administrator: Self = .init(rawValue: 0x1)
            public static let devops: Self = .init(rawValue: 0x2)
            public static let viewAuditLog: Self = .init(rawValue: 0x4)
            public static let viewDashboard: Self = .init(rawValue: 0x8)
            public static let manageReports: Self = .init(rawValue: 0x10)
            public static let manageFederation: Self = .init(rawValue: 0x20)
            public static let manageSettings: Self = .init(rawValue: 0x40)
            public static let manageBlocks: Self = .init(rawValue: 0x80)
            public static let manageTaxonomies: Self = .init(rawValue: 0x100)
            public static let manageAppeals: Self = .init(rawValue: 0x200)
            public static let manageUsers: Self = .init(rawValue: 0x400)
            public static let manageInvites: Self = .init(rawValue: 0x800)
            public static let manageRules: Self = .init(rawValue: 0x1000)
            public static let manageAnnouncements: Self = .init(rawValue: 0x2000)
            public static let manageCustomEmojis: Self = .init(rawValue: 0x4000)
            public static let manageWebhooks: Self = .init(rawValue: 0x8000)
            public static let inviteUsers: Self = .init(rawValue: 0x10000)
            public static let manageRoles: Self = .init(rawValue: 0x20000)
            public static let manageUserAccess: Self = .init(rawValue: 0x40000)
            public static let deleteUserData: Self = .init(rawValue: 0x80000)

            public static var allCases: [Account.Role.Permissions] = [
                administrator,
                devops,
                viewAuditLog,
                viewDashboard,
                manageReports,
                manageFederation,
                manageSettings,
                manageBlocks,
                manageTaxonomies,
                manageAppeals,
                manageUsers,
                manageInvites,
                manageRules,
                manageAnnouncements,
                manageCustomEmojis,
                manageWebhooks,
                inviteUsers,
                manageRoles,
                manageUserAccess,
                deleteUserData,
            ]
        }
    }
}

extension Account.Role.Permissions: Decodable {
    public init(from decoder: any Decoder) throws {
        let string = try decoder.singleValueContainer().decode(String.self)
        if let int = Int(string) {
            self = .init(rawValue: int)
        } else {
            throw DecodingError.dataCorrupted(
                .init(
                    codingPath: decoder.codingPath,
                    debugDescription: "Account.Role.Permissions couldn't parse a numeric string as an integer"
                )
            )
        }
    }
}

extension Account.Role.Permissions: Encodable {
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(String(describing: rawValue))
    }
}

extension Account: Hashable {
    public static func == (lhs: Account, rhs: Account) -> Bool {
        return lhs.id == rhs.id &&
            lhs.username == rhs.username &&
            lhs.acct == rhs.acct &&
            lhs.displayName == rhs.displayName &&
            lhs.locked == rhs.locked &&
            lhs.createdAt == rhs.createdAt &&
            lhs.followersCount == rhs.followersCount &&
            lhs.followingCount == rhs.followingCount &&
            lhs.statusesCount == rhs.statusesCount &&
            lhs.note == rhs.note &&
            lhs.url == rhs.url &&
            lhs.avatar == rhs.avatar &&
            lhs.avatarStatic == rhs.avatarStatic &&
            lhs.header == rhs.header &&
            lhs.headerStatic == rhs.headerStatic &&
            lhs.fields == rhs.fields &&
            lhs.emojis == rhs.emojis &&
            lhs._bot == rhs._bot &&
            lhs._group == rhs._group &&
            lhs._suspended == rhs._suspended &&
            lhs._limited == rhs._limited &&
            lhs.discoverable == rhs.discoverable &&
            lhs.noindex == rhs.noindex &&
            lhs.hideCollections == rhs.hideCollections &&
            lhs.moved == rhs.moved &&
            lhs.source == rhs.source &&
            lhs.role == rhs.role &&
            lhs.theme == rhs.theme &&
            lhs.enableRss == rhs.enableRss &&
            lhs.customCss == rhs.customCss &&
            lhs.muteExpiresAt == rhs.muteExpiresAt
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// swiftlint:enable nesting

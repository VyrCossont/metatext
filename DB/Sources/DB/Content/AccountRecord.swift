// Copyright © 2020 Metabolist. All rights reserved.

import Foundation
import GRDB
import Mastodon

struct AccountRecord: ContentDatabaseRecord, Hashable {
    let id: Account.Id
    let username: String
    let acct: String
    let displayName: String
    let locked: Bool
    let createdAt: Date
    let followersCount: Int
    let followingCount: Int
    let statusesCount: Int
    let lastStatusAt: Date?
    let note: HTML
    let url: String
    let avatar: UnicodeURL
    let avatarStatic: UnicodeURL
    let header: UnicodeURL
    let headerStatic: UnicodeURL
    let fields: [Account.Field]
    let emojis: [Emoji]
    let bot: Bool
    let group: Bool
    let suspended: Bool
    let limited: Bool
    let movedId: Account.Id?
    let role: Account.Role?
    let muteExpiresAt: Date?
}

extension AccountRecord {
    enum Columns {
        static let id = Column(CodingKeys.id)
        static let username = Column(CodingKeys.username)
        static let acct = Column(CodingKeys.acct)
        static let displayName = Column(CodingKeys.displayName)
        static let locked = Column(CodingKeys.locked)
        static let createdAt = Column(CodingKeys.createdAt)
        static let followersCount = Column(CodingKeys.followersCount)
        static let followingCount = Column(CodingKeys.followingCount)
        static let statusesCount = Column(CodingKeys.statusesCount)
        static let lastStatusAt = Column(CodingKeys.lastStatusAt)
        static let note = Column(CodingKeys.note)
        static let url = Column(CodingKeys.url)
        static let avatar = Column(CodingKeys.avatar)
        static let avatarStatic = Column(CodingKeys.avatarStatic)
        static let header = Column(CodingKeys.header)
        static let headerStatic = Column(CodingKeys.headerStatic)
        static let fields = Column(CodingKeys.fields)
        static let emojis = Column(CodingKeys.emojis)
        static let bot = Column(CodingKeys.bot)
        static let group = Column(CodingKeys.group)
        static let suspended = Column(CodingKeys.suspended)
        static let limited = Column(CodingKeys.limited)
        static let movedId = Column(CodingKeys.movedId)
        static let role = Column(CodingKeys.role)
        static let muteExpiresAt = Column(CodingKeys.muteExpiresAt)
    }
}

extension AccountRecord {
    static let moved = belongsTo(AccountRecord.self)
    static let relationship = hasOne(Relationship.self)
    static let identityProofs = hasMany(IdentityProofRecord.self)
    static let featuredTags = hasMany(FeaturedTagRecord.self)
    static let pinnedStatusJoins = hasMany(AccountPinnedStatusJoin.self)
        .order(AccountPinnedStatusJoin.Columns.order)
    static let pinnedStatuses = hasMany(
        StatusRecord.self,
        through: pinnedStatusJoins,
        using: AccountPinnedStatusJoin.status)
    static let familiarFollowersJoins = hasMany(
        FamiliarFollowersJoin.self,
        using: ForeignKey([FamiliarFollowersJoin.Columns.followedAccountId])
    )
    static let familiarFollowers = hasMany(
        AccountRecord.self,
        through: familiarFollowersJoins,
        using: FamiliarFollowersJoin.followingAccount
    )
    static let suggestion = hasOne(SuggestionRecord.self)

    var pinnedStatuses: QueryInterfaceRequest<StatusInfo> {
        StatusInfo.request(request(for: Self.pinnedStatuses), .account)
    }

    init(account: Account) {
        id = account.id
        username = account.username
        acct = account.acct
        displayName = account.displayName
        locked = account.locked
        createdAt = account.createdAt
        followersCount = account.followersCount
        followingCount = account.followingCount
        statusesCount = account.statusesCount
        lastStatusAt = account.lastStatusAt
        note = account.note
        url = account.url
        avatar = account.avatar
        avatarStatic = account.unifiedAvatarStatic
        header = account.header
        headerStatic = account.unifiedHeaderStatic
        fields = account.fields
        emojis = account.emojis
        bot = account.bot
        group = account.group
        suspended = account.suspended
        limited = account.limited
        movedId = account.moved?.id
        role = account.role
        muteExpiresAt = account.muteExpiresAt
    }
}

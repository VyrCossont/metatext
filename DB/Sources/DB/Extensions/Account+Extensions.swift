// Copyright © 2020 Metabolist. All rights reserved.

import Foundation
import GRDB
import Mastodon

extension Account {
    func save(_ db: Database) throws {
        if let moved = moved {
            try moved.save(db)
        }

        try AccountRecord(account: self).save(db)
    }

    convenience init(info: AccountInfo) {
        var moved: Account?

        if let movedRecord = info.movedRecord {
            moved = Self(record: movedRecord, moved: nil)
        }

        self.init(record: info.record, moved: moved)
    }
}

private extension Account {
    convenience init(record: AccountRecord, moved: Account?) {
        // TODO: (Vyr) most of these fields should be stored, which means another migration
        self.init(
            id: record.id,
            username: record.username,
            acct: record.acct,
            displayName: record.displayName,
            locked: record.locked,
            createdAt: record.createdAt,
            followersCount: record.followersCount,
            followingCount: record.followingCount,
            statusesCount: record.statusesCount,
            lastStatusAt: record.lastStatusAt,
            note: record.note,
            url: record.url,
            avatar: record.avatar,
            avatarStatic: record.avatarStatic,
            header: record.header,
            headerStatic: record.headerStatic,
            fields: record.fields,
            emojis: record.emojis,
            bot: record.bot,
            group: record.group,
            suspended: record.suspended,
            limited: record.limited,
            discoverable: nil,
            noindex: nil,
            hideCollections: nil,
            moved: moved,
            source: nil,
            role: record.role,
            theme: nil,
            enableRSS: nil,
            customCSS: nil,
            muteExpiresAt: record.muteExpiresAt
        )
    }
}

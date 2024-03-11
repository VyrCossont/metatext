// Copyright © 2020 Metabolist. All rights reserved.

import AppMetadata
import Foundation
import GRDB
import os

// https://github.com/groue/GRDB.swift/blob/master/Documentation/SharingADatabase.md

extension DatabasePool {
    class func withFileCoordinator(url: URL,
                                   migrator: DatabaseMigrator,
                                   passphrase: @escaping (() throws -> String)) throws -> Self {
        let coordinator = NSFileCoordinator(filePresenter: nil)
        var coordinatorError: NSError?
        var dbPool: Self?
        var dbError: Error?

        coordinator.coordinate(writingItemAt: url, options: .forMerging, error: &coordinatorError) { coordinatedURL in
            do {
                var configuration = Configuration()

                configuration.busyMode = .timeout(5)
                configuration.defaultTransactionKind = .immediate
                configuration.observesSuspensionNotifications = true
                configuration.prepareDatabase { db in
#if DEBUG
                    db.trace {
                        Logger(
                            subsystem: AppMetadata.bundleIDBase,
                            category: "SQL"
                        )
                        // Traced SQL statements only contain value placeholders, not actual values, and can be public.
                        .trace("\($0, privacy: .public)")
                    }
#endif

                    try db.usePassphrase(passphrase())
                    try db.execute(sql: "PRAGMA cipher_plaintext_header_size = 32")

                    if !db.configuration.readonly {
                        var flag: CInt = 1
                        let code = withUnsafeMutablePointer(to: &flag) {
                            sqlite3_file_control(db.sqliteConnection, nil, SQLITE_FCNTL_PERSIST_WAL, $0)
                        }

                        guard code == SQLITE_OK else {
                            throw DatabaseError(resultCode: ResultCode(rawValue: code))
                        }
                    }
                }

                dbPool = try Self(path: coordinatedURL.path, configuration: configuration)

                try migrator.migrate(dbPool!)
            } catch {
                dbError = error
            }
        }

        if let error = dbError ?? coordinatorError {
            throw error
        }

        return dbPool!
    }
}

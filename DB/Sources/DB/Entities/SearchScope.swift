// Copyright © 2021 Metabolist. All rights reserved.

import Foundation

public enum SearchScope: Int, CaseIterable, Sendable {
    case all
    case accounts
    case statuses
    case tags
}

// Copyright © 2020 Metabolist. All rights reserved.

import Foundation

public enum ProfileCollection: String, Codable, CaseIterable, Sendable {
    case statuses
    case statusesAndReplies
    case statusesAndBoosts
    case media
}

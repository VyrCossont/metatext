// Copyright © 2020 Metabolist. All rights reserved.

import Foundation

public struct Marker: Codable, Hashable, Sendable {
    public let lastReadId: String
    public let updatedAt: Date
    public let version: Int
}

public extension Marker {
    enum Timeline: String, Codable, Sendable {
        case home
        case notifications
    }
}

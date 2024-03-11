// Copyright © 2020 Metabolist. All rights reserved.

import Foundation

public struct AccessToken: Codable, Sendable {
    public let scope: String
    public let tokenType: String
    public let accessToken: String
}

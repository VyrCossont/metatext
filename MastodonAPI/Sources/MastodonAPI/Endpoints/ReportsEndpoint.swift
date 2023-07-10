// Copyright © 2023 Vyr Cossont. All rights reserved.

import Foundation
import HTTP
import Mastodon

/// - https://api.pleroma.social/#tag/Reports
public enum ReportsEndpoint {
    case reports
}

extension ReportsEndpoint: Endpoint {
    public typealias ResultType = [Report]

    public var context: [String] {
        defaultContext + ["reports"]
    }

    public var pathComponentsInContext: [String] {
        []
    }

    public var method: HTTPMethod { .get }

    public var requires: APICapabilityRequirements? {
        // Not available on Mastodon: https://github.com/mastodon/mastodon/issues/1685
        [
            .pleroma: .assumeAvailable,
            .akkoma: .assumeAvailable,
            .gotosocial: .assumeAvailable
        ]
    }

    public var fallback: [Report]? { [] }
}

// Copyright © 2020 Metabolist. All rights reserved.

import Foundation
import HTTP
import Mastodon

public enum AccountEndpoint {
    case verifyCredentials
    case accounts(id: Account.Id)
    /// https://docs.joinmastodon.org/methods/accounts/#lookup
    case lookup(acct: String)
}

extension AccountEndpoint: Endpoint {
    public typealias ResultType = Account

    public var context: [String] {
        defaultContext + ["accounts"]
    }

    public var pathComponentsInContext: [String] {
        switch self {
        case .verifyCredentials: return ["verify_credentials"]
        case let .accounts(id): return [id]
        case .lookup: return ["lookup"]
        }
    }

    public var method: HTTPMethod {
        .get
    }

    public var queryParameters: [URLQueryItem] {
        switch self {
        case .verifyCredentials, .accounts:
            return []

        case let .lookup(acct):
            return [.init(name: "acct", value: acct)]
        }
    }

    public var notFound: EntityNotFound? {
        switch self {
        case .verifyCredentials, .lookup:
            return nil

        case .accounts(let id):
            return .account(id)
        }
    }

    public var requires: APICapabilityRequirements? {
        switch self {
        case .verifyCredentials, .accounts:
            return nil

        case .lookup:
            return .mastodonForks("3.4.0") | [
                .gotosocial: .assumeAvailable
            ]
        }
    }
}

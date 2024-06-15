// Copyright © 2020 Metabolist. All rights reserved.

import Foundation
import HTTP
import Mastodon

public enum AccountsEndpoint {
    case rebloggedBy(id: Status.Id)
    case favouritedBy(id: Status.Id)
    /// https://docs.joinmastodon.org/methods/mutes/
    case mutes
    case blocks
    case accountsFollowers(id: Account.Id)
    case accountsFollowing(id: Account.Id)
    case followRequests
    /// https://docs.joinmastodon.org/methods/directory/
    case directory(
        local: Bool? = nil,
        order: DirectoryOrder? = nil,
        limit: Int? = nil,
        offset: Int? = nil
    )
    /// https://docs.joinmastodon.org/methods/accounts/#search
    case search(
        query: String,
        resolve: Bool = false,
        following: Bool = false,
        limit: Int? = nil,
        offset: Int? = nil
    )
}

public extension AccountsEndpoint {
    enum DirectoryOrder: String {
        /// Sort by most recent posters first.
        case active
        /// Sort by newest accounts first.
        case new
    }
}

extension AccountsEndpoint: Endpoint {
    public typealias ResultType = [Account]

    public var context: [String] {
        switch self {
        case .rebloggedBy, .favouritedBy:
            return defaultContext + ["statuses"]
        case .mutes, .blocks, .followRequests, .directory:
            return defaultContext
        case .accountsFollowers, .accountsFollowing, .search:
            return defaultContext + ["accounts"]
        }
    }

    public var pathComponentsInContext: [String] {
        switch self {
        case let .rebloggedBy(id):
            return [id, "reblogged_by"]
        case let .favouritedBy(id):
            return [id, "favourited_by"]
        case .mutes:
            return ["mutes"]
        case .blocks:
            return ["blocks"]
        case let .accountsFollowers(id):
            return [id, "followers"]
        case let .accountsFollowing(id):
            return [id, "following"]
        case .followRequests:
            return ["follow_requests"]
        case .directory:
            return ["directory"]
        case .search:
            return ["search"]
        }
    }

    public var queryParameters: [URLQueryItem] {
        switch self {
        case let .directory(local, order, limit, offset):
            var params = [URLQueryItem]()
            params.add("local", local)
            params.add("order", order?.rawValue)
            params.add("limit", limit)
            params.add("offset", offset)
            return params

        case let .search(query, resolve, following, limit, offset):
            var params = [URLQueryItem]()
            params.add("query", query)
            params.add("resolve", resolve)
            params.add("following", following)
            params.add("limit", limit)
            params.add("offset", offset)
            return params

        default:
            return []
        }
    }

    public var method: HTTPMethod {
        .get
    }

    public var requires: APICapabilityRequirements? {
        switch self {
        case .directory:
            return .mastodonForks("3.0.0") | [
                .fedibird: "0.1.0"
            ]
        case .search:
            return .mastodonForks("2.8.0") | [
                .fedibird: "0.1.0",
                .gotosocial: .assumeAvailable
            ]
        case .mutes:
            return .mastodonForks(.assumeAvailable) | [
                .fedibird: "0.1.0",
                .pleroma: .assumeAvailable,
                .akkoma: .assumeAvailable,
                .calckey: .assumeAvailable,
                .firefish: "1.0.0",
                .iceshrimp: "1.0.0",
                .pixelfed: .assumeAvailable,
                .gotosocial: "0.16.0-0"
            ]
        default:
            return nil
        }
    }

    public var fallback: [Account]? { [] }
}

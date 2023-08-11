// Copyright © 2020 Metabolist. All rights reserved.

import Foundation
import HTTP
import Mastodon

/// https://docs.joinmastodon.org/methods/push/
public enum PushSubscriptionEndpoint {
    case create(
        endpoint: URL,
        publicKey: String,
        auth: String,
        alerts: PushSubscription.Alerts,
        policy: PushSubscription.Policy?
    )
    case read
    case update(
        alerts: PushSubscription.Alerts,
        policy: PushSubscription.Policy?
    )
    case delete
}

extension PushSubscriptionEndpoint: Endpoint {
    public typealias ResultType = PushSubscription

    public var context: [String] {
        defaultContext + ["push", "subscription"]
    }

    public var pathComponentsInContext: [String] { [] }

    public var method: HTTPMethod {
        switch self {
        case .create: return .post
        case .read: return .get
        case .update: return .put
        case .delete: return .delete
        }
    }

    public var jsonBody: [String: Any]? {
        switch self {
        case let .create(endpoint, publicKey, auth, alerts, policy):
            let subscription: [String: Any] = [
                "endpoint": endpoint.absoluteString,
                "keys": [
                    "p256dh": publicKey,
                    "auth": auth
                ]
            ]

            var data: [String: Any] = [
                "alerts": alerts.jsonBody
            ]

            if let policy = policy {
                data["policy"] = policy.rawValue
            }

            return [
                "subscription": subscription,
                "data": data
            ]
        case let .update(alerts, policy):
            var data: [String: Any] = [
                "alerts": alerts.jsonBody
            ]

            if let policy = policy {
                data["policy"] = policy.rawValue
            }

            return [
                "data": data
            ]
        default: return nil
        }
    }

    public var requires: APICapabilityRequirements? {
        switch self {
        case .read,
                .delete,
                .create(_, _, _, _, policy: nil),
                .update(_, policy: nil):
            return .mastodonForks("2.4.0") | [
                .fedibird: "0.1.0",
                .pleroma: .assumeAvailable,
                .akkoma: .assumeAvailable
            ]
        case .create, .update:
            return .mastodonForks("3.4.0") | [
                .fedibird: "0.1.0"
            ]
        }
    }
}

private extension PushSubscription.Alerts {
    var jsonBody: [String: Any] {
        [
            "follow": follow,
            "favourite": favourite,
            "reblog": reblog,
            "mention": mention,
            "follow_request": followRequest,
            "poll": poll,
            "status": status,
            "update": update,
            "admin.sign_up": adminSignup,
            "admin.report": adminReport
        ]
    }
}

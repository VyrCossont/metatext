// Copyright © 2020 Metabolist. All rights reserved.

import Foundation
import HTTP
import Mastodon

public enum StatusEndpoint {
    case status(id: Status.Id)
    case reblog(id: Status.Id)
    case unreblog(id: Status.Id)
    case favourite(id: Status.Id)
    case unfavourite(id: Status.Id)
    case bookmark(id: Status.Id)
    case unbookmark(id: Status.Id)
    case pin(id: Status.Id)
    case unpin(id: Status.Id)
    case mute(id: Status.Id)
    case unmute(id: Status.Id)
    case delete(id: Status.Id)
    case post(Components)
    case put(id: Status.Id, Components)
    case react(id: Status.Id, name: String)
    case unreact(id: Status.Id, name: String)

    // Specific to Pleroma/Akkoma. Might someday be replaced with the Glitch equivalent.
    case pleromaReact(id: Status.Id, name: String)
    case pleromaUnreact(id: Status.Id, name: String)
}

public extension StatusEndpoint {
    struct Components {
        public let inReplyToId: Status.Id?
        public let text: String
        public let spoilerText: String
        public let mediaIds: [Attachment.Id]
        public let visibility: Status.Visibility?
        public let language: String?
        public let sensitive: Bool
        public let pollOptions: [String]
        public let pollExpiresIn: Int
        public let pollMultipleChoice: Bool

        /// GotoSocial only.
        public let federated: Bool?
        /// GotoSocial only.
        public let boostable: Bool?
        /// GotoSocial only.
        public let replyable: Bool?
        /// GotoSocial only.
        public let likeable: Bool?

        public init(
            inReplyToId: Status.Id?,
            text: String,
            spoilerText: String,
            mediaIds: [Attachment.Id],
            visibility: Status.Visibility?,
            language: String?,
            sensitive: Bool,
            pollOptions: [String],
            pollExpiresIn: Int,
            pollMultipleChoice: Bool,
            federated: Bool?,
            boostable: Bool?,
            replyable: Bool?,
            likeable: Bool?
        ) {
            self.inReplyToId = inReplyToId
            self.text = text
            self.spoilerText = spoilerText
            self.mediaIds = mediaIds
            self.visibility = visibility
            self.language = language
            self.sensitive = sensitive
            self.pollOptions = pollOptions
            self.pollExpiresIn = pollExpiresIn
            self.pollMultipleChoice = pollMultipleChoice
            self.federated = federated
            self.boostable = boostable
            self.replyable = replyable
            self.likeable = likeable
        }
    }
}

extension StatusEndpoint.Components {
    var jsonBody: [String: Any]? {
        var params = [String: Any]()

        if !text.isEmpty {
            params["status"] = text
        }

        if !spoilerText.isEmpty {
            params["spoiler_text"] = spoilerText
        }

        if !mediaIds.isEmpty {
            params["media_ids"] = mediaIds
        }

        params["in_reply_to_id"] = inReplyToId
        params["visibility"] = visibility?.rawValue
        params["language"] = language

        if sensitive {
            params["sensitive"] = true
        }

        if !pollOptions.isEmpty {
            var poll = [String: Any]()

            poll["options"] = pollOptions
            poll["expires_in"] = pollExpiresIn
            poll["multiple"] = pollMultipleChoice

            params["poll"] = poll
        }

        // GotoSocial interaction controls.
        if let federated = federated {
            params["federated"] = federated
        }
        if let boostable = boostable {
            params["boostable"] = boostable
        }
        if let replyable = replyable {
            params["replyable"] = replyable
        }
        if let likeable = likeable {
            params["likeable"] = likeable
        }

        return params
    }
}

extension StatusEndpoint: Endpoint {
    public typealias ResultType = Status

    public var context: [String] {
        switch self {
        case.pleromaReact, .pleromaUnreact:
            return defaultContext + ["pleroma", "statuses"]
        default:
            return defaultContext + ["statuses"]
        }
    }

    public var pathComponentsInContext: [String] {
        switch self {
        case let .status(id), let .delete(id), let .put(id, _):
            return [id]
        case let .reblog(id):
            return [id, "reblog"]
        case let .unreblog(id):
            return [id, "unreblog"]
        case let .favourite(id):
            return [id, "favourite"]
        case let .unfavourite(id):
            return [id, "unfavourite"]
        case let .bookmark(id):
            return [id, "bookmark"]
        case let .unbookmark(id):
            return [id, "unbookmark"]
        case let .pin(id):
            return [id, "pin"]
        case let .unpin(id):
            return [id, "unpin"]
        case let .mute(id):
            return [id, "mute"]
        case let .unmute(id):
            return [id, "unmute"]
        case let .react(id, name):
            return [id, "react", name]
        case let .unreact(id, name):
            return [id, "unreact", name]
        case let .pleromaReact(id, name), let .pleromaUnreact(id, name):
            return [id, "reactions", name]
        case .post:
            return []
        }
    }

    public var jsonBody: [String: Any]? {
        switch self {
        case let .post(components), let .put(_, components):
            return components.jsonBody
        default:
            return nil
        }
    }

    public var method: HTTPMethod {
        switch self {
        case .status:
            return .get
        case .delete, .pleromaUnreact:
            return .delete
        case .put, .pleromaReact:
            return .put
        default:
            return .post
        }
    }

    public var requires: APICapabilityRequirements? {
        switch self {
        case .put:
            return StatusEditsEndpoint.history(id: "").requires
        case .bookmark, .unbookmark:
            return StatusesEndpoint.bookmarks.requires
        case .mute, .unmute:
            return .mastodonForks(.assumeAvailable) | [
                .pleroma: .assumeAvailable,
                .akkoma: .assumeAvailable,
                .gotosocial: .assumeAvailable,
            ]
        case .react, .unreact:
            // Glitch PR #2221 reaction support must be detected using the instance API.
            return .features(.emojiReactions) | [
                .firefish: "1.0.4-0",
                .iceshrimp: "1.0.2"
            ]
        case .pleromaReact, .pleromaUnreact:
            return [
                .pleroma: .assumeAvailable,
                .akkoma: .assumeAvailable
            ]

        case let .post(components):
            // These are *future* GtS features and have some surprising behavior in 0.16.
            if components.visibility == .mutualsOnly ||
                components.federated != nil ||
                components.replyable != nil ||
                components.boostable != nil ||
                components.likeable != nil {
                return [:]
            }

            return nil

        default:
            return nil
        }
    }

    public var notFound: EntityNotFound? {
        switch self {
        case .post:
            return nil

        case .status(id: let id),
                .reblog(id: let id),
                .unreblog(id: let id),
                .favourite(id: let id),
                .unfavourite(id: let id),
                .bookmark(id: let id),
                .unbookmark(id: let id),
                .pin(id: let id),
                .unpin(id: let id),
                .mute(id: let id),
                .unmute(id: let id),
                .delete(id: let id),
                .put(id: let id, _),
                .react(id: let id, _),
                .unreact(id: let id, _),
                .pleromaReact(id: let id, _),
                .pleromaUnreact(id: let id, _):
            return .status(id)
        }
    }
}

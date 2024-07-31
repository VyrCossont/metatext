// Copyright © 2020 Metabolist. All rights reserved.

import Foundation
import HTTP
import Mastodon

public enum AttachmentEndpoint {
    case create(data: Data, mimeType: String, description: String?, focus: Attachment.Meta.Focus?)
    case update(id: Attachment.Id, description: String?, focus: Attachment.Meta.Focus?)
}

extension AttachmentEndpoint: Endpoint {
    public typealias ResultType = Attachment

    public var context: [String] {
        defaultContext + ["media"]
    }

    public var pathComponentsInContext: [String] {
        switch self {
        case .create:
            return []
        case let .update(id, _, _):
            return [id]
        }
    }

    public var multipartFormData: [String: MultipartFormValue]? {
        switch self {
        case let .create(data, mimeType, description, focus):
            var params = [String: MultipartFormValue]()

            params.add("file", data, mimeType)
            params.add("description", description)

            if let x = focus?.x, let y = focus?.y {
                params["focus"] = .string("\(x),\(y)")
            }

            return params
        case let .update(_, description, focus):
            var params = [String: MultipartFormValue]()

            params.add("description", description)

            if let x = focus?.x, let y = focus?.y {
                params["focus"] = .string("\(x),\(y)")
            }

            return params
        }
    }

    public var method: HTTPMethod {
        switch self {
        case .create:
            return .post
        case .update:
            return .put
        }
    }

    public var notFound: EntityNotFound? {
        switch self {
        case .create:
            return nil

        case .update(let id, _, _):
            return .attachment(id)
        }
    }
}

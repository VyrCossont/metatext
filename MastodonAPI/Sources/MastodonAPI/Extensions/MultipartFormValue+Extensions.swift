// Copyright © 2024 Vyr Cossont. All rights reserved.

import Foundation
import HTTP

/// Convenience methods for adding optional params to a multipart form.
extension [String: MultipartFormValue] {
    /// Add an optional string-convertible parameter.
    mutating func add<T: LosslessStringConvertible>(_ name: String, _ value: T?) {
        if let value = value {
            self[name] = .string(.init(describing: value))
        }
    }

    /// Add an optional file parameter.
    mutating func add(_ name: String, _ data: Data?, _ mimeType: String?, filename: String? = nil) {
        if let data = data, let mimeType = mimeType {
            self[name] = .data(data, filename: filename ?? UUID().uuidString, mimeType: mimeType)
        }
    }
}

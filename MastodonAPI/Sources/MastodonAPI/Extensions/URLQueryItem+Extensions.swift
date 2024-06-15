// Copyright © 2024 Vyr Cossont. All rights reserved.

import Foundation
import HTTP

/// Convenience methods for adding optional params to an URL query.
extension [URLQueryItem] {
    /// Add an optional string-convertible parameter.
    mutating func add<T: LosslessStringConvertible>(_ name: String, _ value: T?) {
        if let value = value {
            self.append(.init(name: name, value: .init(describing: value)))
        }
    }
}

// Copyright © 2023 Vyr Cossont. All rights reserved.

import Combine
import Foundation

/// Making this correct for strict concurrency is an open problem:
/// https://forums.swift.org/t/how-to-correctly-convert-from-an-async-function-to-combine-or-any-other-framework/64009
public extension Future {
    convenience init(async closure: @Sendable @escaping () async -> Output) {
        self.init { promise in
            Task {
                let result = await closure()
                promise(.success(result))
            }
        }
    }

    convenience init(asyncThrows closure: @Sendable @escaping () async throws -> Output) where Failure == Error {
        self.init { promise in
            Task {
                do {
                    let result = try await closure()
                    promise(.success(result))
                } catch {
                    promise(.failure(error))
                }
            }
        }
    }
}

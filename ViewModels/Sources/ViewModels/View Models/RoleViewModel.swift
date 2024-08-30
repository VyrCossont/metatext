// Copyright © 2024 Vyr Cossont. All rights reserved.

import Foundation
import Mastodon

/// Make ``Account.Role`` identifiable so we can use it in a ``SwiftUI.ForEach``.
public final class RoleViewModel: ObservableObject, Identifiable {
    private let role: Account.Role

    public init(_ role: Account.Role) {
        self.role = role
    }

    public var id: String { role.id ?? role.name }
    public var name: String { role.name }
}

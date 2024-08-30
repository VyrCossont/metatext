// Copyright © 2024 Vyr Cossont. All rights reserved.

import Foundation
import SwiftUI
import ViewModels

/// Display the names of an account's instance roles.
struct RolePillsView: View {
    let roles: [RoleViewModel]

    var body: some View {
        HStack {
            ForEach(roles) { role in
                Text(verbatim: role.name)
                    .font(.footnote.smallCaps())
                    .padding(.all, .compactSpacing)
                    .foregroundStyle(.background)
                    .fixedSize(horizontal: true, vertical: false)
                    .background(.secondary, in: RoundedRectangle(cornerRadius: .defaultCornerRadius))
            }
        }
    }
}

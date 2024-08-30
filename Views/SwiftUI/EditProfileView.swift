// Copyright © 2024 Vyr Cossont. All rights reserved.

import ViewModels
import SwiftUI

/// View for editing your profile: display name, avatar, header, bio, fields, etc.
struct EditProfileView: View {
    let viewModel: EditProfileViewModel

    var body: some View {
        switch viewModel.state {
        case .loading:
            Text("loading")
        case .ready:
            VStack {
                Text("ready")
                Text(viewModel.displayName ?? "<no display name>")
            }
        case .saving:
            Text("saving")
        case .done:
            Text("done")
        case .error:
            Text("error")
        }
    }
}

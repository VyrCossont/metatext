// Copyright © 2020 Metabolist. All rights reserved.

import Foundation
import SwiftUI
import UIKit
import UniformTypeIdentifiers
import ViewModels

extension View {
    @MainActor
    func alertItem(_ alertItem: Binding<AlertItem?>) -> some View {
        alert(item: alertItem) {
            let copyButtonTitle: LocalizedStringKey
            let copyItems: [String: Data]
            if let json = $0.json {
                copyButtonTitle = "error.alert.copy-json"
                copyItems = [
                    UTType.json.identifier: json,
                    // Intentional JSON as text: it's already pretty-printed and most apps can't handle a JSON paste.
                    UTType.utf8PlainText.identifier: json,
                ]
            } else {
                copyButtonTitle = "error.alert.copy-text"
                copyItems = [
                    UTType.utf8PlainText.identifier: $0.text
                ]
            }

            return Alert(
                title: Text($0.title),
                message: Text($0.message),
                primaryButton: .default(Text("ok")),
                secondaryButton: .default(Text(copyButtonTitle)) {
                    UIPasteboard.general.setItems([copyItems])
                }
            )
        }
    }
}

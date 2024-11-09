// Copyright © 2020 Metabolist. All rights reserved.

import AppUrls
import ServiceLayer
import SwiftUI
import UIKit
import ViewModels

struct RootView: View {
    @StateObject var viewModel: RootViewModel

    var body: some View {
        ZStack(alignment: .topTrailing) {
            if let navigationViewModel = viewModel.navigationViewModel {
                MainNavigationView { navigationViewModel }
                    .id(navigationViewModel.identityContext.identity.id)
                    .environmentObject(viewModel)
                    .transition(.opacity)
                    .handlesExternalEvents(preferring: ["*"], allowing: ["*"])
                    .onOpenURL(perform: { openURL(navigationViewModel, $0) })
                    .edgesIgnoringSafeArea(.all)
                    .onReceive(navigationViewModel.identityContext.$appPreferences.map(\.colorScheme),
                               perform: setColorScheme)
                    .tint(viewModel.tintColor?.color)
                    .onReceive(viewModel.$tintColor,
                               perform: setTintColor)
                    .environment(\.statusWord, viewModel.statusWord)
                    .toast($viewModel.toastAlertItem)
            } else {
                NavigationView {
                    AddIdentityView(
                        viewModelClosure: { viewModel.addIdentityViewModel() },
                        displayWelcome: true)
                    .navigationBarTitleDisplayMode(.inline)
                    .navigationBarHidden(true)
                }
            }

            OrbView(viewModel: viewModel)
                .offset(x: -25, y: 5)
        }
    }

    /// Open `feditext:` URLs from the action extension and `web+ap://` URLs from whereever.
    private func openURL(_ navigationViewModel: NavigationViewModel, _ url: URL) {
        guard let appUrl = AppUrl(url: url) else { return }
        switch appUrl {
        case let .search(searchUrl):
            navigationViewModel.navigateToURL(searchUrl)
        default:
            break
        }
    }
}

struct OrbView: View {
    @ObservedObject var viewModel: RootViewModel

    var body: some View {
        Circle()
            .fill(.purple)
            .frame(width: 2 * viewModel.shame, height: 2 * viewModel.shame)
            .padding(.all, 10 - viewModel.shame)
    }
}

private extension RootView {
    func setColorScheme(_ colorScheme: AppPreferences.ColorScheme) {
        for scene in UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }) {
            for window in scene.windows {
                window.overrideUserInterfaceStyle = colorScheme.uiKit
            }
        }
    }

    func setTintColor(_ tintColor: Identity.Preferences.TintColor?) {
        for scene in UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }) {
            for window in scene.windows {
                window.tintColor = tintColor.map { UIColor($0.color) }
            }
        }
    }
}

extension AppPreferences.ColorScheme {
    var uiKit: UIUserInterfaceStyle {
        switch self {
        case .system:
            return .unspecified
        case .light:
            return .light
        case .dark:
            return .dark
        }
    }
}

#if DEBUG
import Combine
import PreviewViewModels

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        RootView(viewModel: .preview)
    }
}
#endif

// Copyright © 2024 Vyr Cossont. All rights reserved.

import Combine
import Foundation
import Mastodon
import MastodonAPI
import ServiceLayer

/// View for editing your profile: display name, avatar, header, bio, fields, etc.
/// Contains a copy of the pre-edit state of your profile to check which fields need to be updated.
@MainActor
public class EditProfileViewModel: ObservableObject {
    /// Used to call the profile update method.
    private let identityService: IdentityService
    /// Used to fetch user language prefs and instance config such as allowed status content types.
    private let identityContext: IdentityContext
    private var cancellables = Set<AnyCancellable>()

    @Published private(set) public var state: State = .loading
    @Published private(set) public var alertItem: AlertItem?
    /// Has the user actually changed anything that we can save?
    @Published private(set) public var canSave: Bool = false

    /// Workflow for editing the user's profile.
    public enum State {
        /// Loading the original profile state. Display a spinner.
        case loading
        /// Ready to edit. Display the edit form.
        case ready
        /// Saving profile and/or media updates. Display a spinner.
        case saving
        /// Finished saving. The view should be dismissed.
        case done
        /// An error has occured. Display the error.
        case error
    }

    /// Profile state before we started editing it.
    /// We'll compare this to the current state when deciding what to call to update it.
    private var beforeEdits: Account?
    public var beforeEditsAvatar: URL? { beforeEdits?.avatar.url }
    public var beforeEditsHeader: URL? { beforeEdits?.header.url }

    /// Update request that we're authoring with this view.
    @Published private(set) public var update = AccountEndpoint.UpdateCredentialsRequest()

    // Most of these variables correspond directly to `AccountEndpoint.UpdateCredentialsRequest` fields.
    // The others are to keep track of whether they can be changed and what they can be changed to.

    @Published public var displayName: String?
    @Published public var note: String?

    @Published public var avatar = ProfileMedia.unchanged
    @Published public var header = ProfileMedia.unchanged

    public enum ProfileMedia: Equatable {
        /// The user hasn't changed this profile media.
        case unchanged
        /// The user has provided a new file to upload.
        case new(_ data: Data, _ mimeType: String)
        /// Remove this profile media.
        case delete
    }

    @Published public var locked: Bool?
    @Published public var bot: Bool?
    @Published public var discoverable: Bool?

    @Published public var hideCollections: Bool?
    public var hasHideCollections: Bool {
        AccountEndpoint.updateCredentials(.init(hideCollections: true))
            .canCallWith(identityContext.apiCapabilities)
    }

    @Published public var indexable: Bool?
    /// Requires Mastodon 4.2.
    public var hasIndexable: Bool {
        AccountEndpoint.updateCredentials(.init(indexable: true))
            .canCallWith(identityContext.apiCapabilities)
    }

    @Published public var fields: [Account.Source.Field]?
    @Published public var privacy: Status.Visibility?
    @Published public var sensitive: Bool?

    @Published public var language: PrefsLanguage?
    public var supportedLanguages: [PrefsLanguage]? {
        identityContext.appPreferences.postingLanguages.map(PrefsLanguage.init(tag:))
    }

    @Published public var statusContentType: ContentType?
    /// Requires GotoSocial.
    /// Glitch supports posting with alternate content types, but doesn't have an API to set a default.
    public var hasStatusContentType: Bool {
        AccountEndpoint.updateCredentials(.init(statusContentType: .init(rawValue: "")))
            .canCallWith(identityContext.apiCapabilities)
    }
    public var supportedStatusContentTypes: [ContentType]? {
        identityContext.identity.instance?.configuration?.statuses?.supportedMimeTypes
            .map { $0.map(ContentType.init) }
    }

    @Published public var theme: String?
    /// Requires GotoSocial.
    public var hasTheme: Bool {
        AccountEndpoint.updateCredentials(.init(theme: ""))
            .canCallWith(identityContext.apiCapabilities)
    }

    @Published public var customCSS: String?
    /// Requires GotoSocial.
    public var hasCustomCSS: Bool {
        AccountEndpoint.updateCredentials(.init(customCSS: ""))
            .canCallWith(identityContext.apiCapabilities)
    }

    @Published public var enableRSS: Bool?
    /// Requires GotoSocial.
    public var hasEnableRSS: Bool {
        AccountEndpoint.updateCredentials(.init(enableRSS: true))
            .canCallWith(identityContext.apiCapabilities)
    }

    public init(
        identityService: IdentityService,
        identityContext: IdentityContext
    ) {
        self.identityService = identityService
        self.identityContext = identityContext

        Task {
            do {
                let account = try await identityService.getProfileWithSource()
                beforeEdits = account

                displayName = account.displayName
                note = account.source?.note
                // Avatar and header are media and we handle those differently.
                locked = account.locked
                bot = account.bot
                discoverable = account.discoverable
                hideCollections = account.hideCollections
                indexable = account.noindex.map { !$0 }
                fields = account.source?.fields
                privacy = account.source?.privacy
                sensitive = account.source?.sensitive
                language = account.source?.language.map(PrefsLanguage.init(tag:))
                statusContentType = account.source?.statusContentType.map(ContentType.init)
                theme = account.theme
                customCSS = account.customCss
                enableRSS = account.enableRss

                state = .ready
            } catch {
                alertItem = .init(error: error)
                state = .error
            }
        }

        // Update the request we're preparing whenever fields in it change.

        $displayName
            .sink(receiveValue: { [weak self] in self?.update.displayName = $0 })
            .store(in: &cancellables)

        $note
            .sink(receiveValue: { [weak self] in self?.update.note = $0 })
            .store(in: &cancellables)

        $avatar
            .sink(receiveValue: { [weak self] in
                guard let self = self else { return }
                switch $0 {
                case let .new(data, mimeType):
                    self.update.avatar = data
                    self.update.avatarMimeType = mimeType
                case .unchanged, .delete:
                    self.update.avatar = nil
                    self.update.avatarMimeType = nil
                }
            })
            .store(in: &cancellables)

        $header
            .sink(receiveValue: { [weak self] in
                guard let self = self else { return }
                switch $0 {
                case let .new(data, mimeType):
                    self.update.header = data
                    self.update.headerMimeType = mimeType
                case .unchanged, .delete:
                    self.update.header = nil
                    self.update.headerMimeType = nil
                }
            })
            .store(in: &cancellables)

        $locked
            .sink(receiveValue: { [weak self] in self?.update.locked = $0 })
            .store(in: &cancellables)

        $bot
            .sink(receiveValue: { [weak self] in self?.update.bot = $0 })
            .store(in: &cancellables)

        $discoverable
            .sink(receiveValue: { [weak self] in self?.update.discoverable = $0 })
            .store(in: &cancellables)

        $hideCollections
            .sink(receiveValue: { [weak self] in self?.update.hideCollections = $0 })
            .store(in: &cancellables)

        $indexable
            .sink(receiveValue: { [weak self] in self?.update.indexable = $0 })
            .store(in: &cancellables)

        $fields
            .sink(receiveValue: { [weak self] in self?.update.fields = $0 })
            .store(in: &cancellables)

        $privacy
            .sink(receiveValue: { [weak self] in self?.update.privacy = $0 })
            .store(in: &cancellables)

        $sensitive
            .sink(receiveValue: { [weak self] in self?.update.sensitive = $0 })
            .store(in: &cancellables)

        $language
            .sink(receiveValue: { [weak self] in self?.update.language = $0?.tag })
            .store(in: &cancellables)

        $statusContentType
            .sink(receiveValue: { [weak self] in self?.update.statusContentType = $0 })
            .store(in: &cancellables)

        $theme
            .sink(receiveValue: { [weak self] in self?.update.theme = $0 })
            .store(in: &cancellables)

        $customCSS
            .sink(receiveValue: { [weak self] in self?.update.customCSS = $0 })
            .store(in: &cancellables)

        $enableRSS
            .sink(receiveValue: { [weak self] in self?.update.enableRSS = $0 })
            .store(in: &cancellables)

        // If we have something to update or delete, the user can save the form.
        $update
            .combineLatest($avatar, $header)
            .map { (update, avatar, header) in
                !update.isEmpty || avatar == .delete || header == .delete
            }
            .assign(to: &$canSave)
    }

    /// Enter the saving state, update the profile, and finish in the done state.
    public func save() async {
        do {
            state = .saving

            try await identityService.updateProfile(
                request: update.isEmpty ? nil : update,
                deleteAvatar: avatar == .delete,
                deleteHeader: header == .delete
            )

            state = .done
        } catch {
            alertItem = .init(error: error)
            state = .error
        }
    }
}

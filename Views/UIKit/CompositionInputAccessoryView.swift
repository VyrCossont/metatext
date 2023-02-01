// Copyright © 2020 Metabolist. All rights reserved.

import AVFoundation
import Combine
import Mastodon
import UIKit
import ViewModels

final class CompositionInputAccessoryView: UIView {
    var tagForInputView = UUID().hashValue
    let autocompleteSelections: AnyPublisher<String, Never>

    private let parentViewModel: ComposeStatusViewModel
    private let toolbar = UIToolbar()
    private let autocompleteCollectionView = UICollectionView(
        frame: .zero,
        collectionViewLayout: CompositionInputAccessoryView.autocompleteLayout())
    private let autocompleteDataSource: AutocompleteDataSource
    private let autocompleteCollectionViewHeightConstraint: NSLayoutConstraint
    private let autocompleteSelectionsSubject = PassthroughSubject<String, Never>()
    private var cancellables = Set<AnyCancellable>()

    // These controls need to be attached to view model events.
    private let attachmentButton = UIBarButtonItem()
    private let pollButton = UIBarButtonItem()
    private let contentWarningButton = UIBarButtonItem()
    private let addButton = UIBarButtonItem()
    private let charactersBarItem = UIBarButtonItem()

    init(viewModel: CompositionViewModel? = nil,
         parentViewModel: ComposeStatusViewModel,
         autocompleteQueryPublisher: AnyPublisher<String?, Never>? = nil) {
        self.parentViewModel = parentViewModel
        defer {
            self.viewModel = viewModel
            self.autocompleteQueryPublisher = autocompleteQueryPublisher
        }
        autocompleteDataSource = AutocompleteDataSource(
            collectionView: autocompleteCollectionView,
            queryPublisher: autocompleteQueryPublisher,
            parentViewModel: parentViewModel)
        autocompleteCollectionViewHeightConstraint =
            autocompleteCollectionView.heightAnchor.constraint(equalToConstant: .hairline)
        autocompleteSelections = autocompleteSelectionsSubject.eraseToAnyPublisher()

        super.init(
            frame: .init(
                origin: .zero,
                size: .init(width: UIScreen.main.bounds.width, height: .minimumButtonDimension)))

        initialSetup()
    }

    public weak var viewModel: CompositionViewModel? {
        didSet {
            cancellables.removeAll()
            viewModelSetup()
        }
    }

    public var autocompleteQueryPublisher: AnyPublisher<String?, Never>? {
        didSet {
            autocompleteDataSource.queryPublisher = autocompleteQueryPublisher
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func didMoveToSuperview() {
        super.didMoveToSuperview()

        layoutIfNeeded()
    }
}

private extension CompositionInputAccessoryView {
    static let autocompleteCollectionViewMaxHeight: CGFloat = 150

    var heightConstraint: NSLayoutConstraint? {
        superview?.constraints.first(where: { $0.identifier == "accessoryHeight" })
    }

    // swiftlint:disable:next function_body_length
    func initialSetup() {
        autoresizingMask = .flexibleHeight

        addSubview(autocompleteCollectionView)
        autocompleteCollectionView.translatesAutoresizingMaskIntoConstraints = false
        autocompleteCollectionView.alwaysBounceVertical = false
        autocompleteCollectionView.backgroundColor = .clear
        autocompleteCollectionView.layer.cornerRadius = .defaultCornerRadius
        autocompleteCollectionView.layer.maskedCorners = [.layerMaxXMinYCorner, .layerMinXMinYCorner]
        autocompleteCollectionView.dataSource = autocompleteDataSource
        autocompleteCollectionView.delegate = self

        let autocompleteBackgroundView = UIVisualEffectView(effect: UIBlurEffect(style: .systemChromeMaterial))

        autocompleteCollectionView.backgroundView = autocompleteBackgroundView

        addSubview(toolbar)
        toolbar.translatesAutoresizingMaskIntoConstraints = false
        toolbar.setContentCompressionResistancePriority(.required, for: .vertical)

        NSLayoutConstraint.activate([
            autocompleteCollectionView.leadingAnchor.constraint(equalTo: leadingAnchor),
            autocompleteCollectionView.topAnchor.constraint(equalTo: topAnchor),
            autocompleteCollectionView.trailingAnchor.constraint(equalTo: trailingAnchor),
            autocompleteCollectionView.bottomAnchor.constraint(equalTo: toolbar.topAnchor),
            toolbar.leadingAnchor.constraint(equalTo: leadingAnchor),
            toolbar.trailingAnchor.constraint(equalTo: trailingAnchor),
            toolbar.bottomAnchor.constraint(equalTo: bottomAnchor),
            toolbar.heightAnchor.constraint(equalToConstant: .minimumButtonDimension),
            autocompleteCollectionViewHeightConstraint
        ])

        var attachmentActions = [
            UIAction(
                title: NSLocalizedString("compose.browse", comment: ""),
                image: UIImage(systemName: "ellipsis")) { [weak self] _ in self?.presentDocumentPicker() },
            UIAction(
                title: NSLocalizedString("compose.photo-library", comment: ""),
                image: UIImage(systemName: "rectangle.on.rectangle")) { [weak self] _ in self?.presentMediaPicker() }
        ]

        #if !IS_SHARE_EXTENSION
        attachmentActions.insert(UIAction(
            title: NSLocalizedString("compose.take-photo-or-video", comment: ""),
            image: UIImage(systemName: "camera.fill")) { [weak self] _ in self?.presentCamera() },
        at: 1)
        #endif

        attachmentButton.image = UIImage(systemName: "paperclip")
        attachmentButton.menu = UIMenu(children: attachmentActions)
        attachmentButton.accessibilityLabel =
            NSLocalizedString("compose.attachments-button.accessibility-label", comment: "")

        pollButton.image = UIImage(systemName: "chart.bar.xaxis")
        pollButton.primaryAction = UIAction { [weak self] _ in self?.togglePoll() }
        pollButton.accessibilityLabel = NSLocalizedString("compose.poll-button.accessibility-label", comment: "")

        let visibilityButton = UIBarButtonItem(
            image: UIImage(systemName: parentViewModel.visibility.systemImageName),
            menu: visibilityMenu(selectedVisibility: parentViewModel.visibility))
        visibilityButton.isEnabled = parentViewModel.canChangeVisibility

        contentWarningButton.title = NSLocalizedString("status.content-warning-abbreviation", comment: "")
        contentWarningButton.primaryAction = UIAction { [weak self] _ in self?.toggleContentWarning() }

        let emojiButton = UIBarButtonItem(
            image: UIImage(systemName: "face.smiling"),
            primaryAction: UIAction { [weak self] _ in
                guard let self = self else { return }

                self.parentViewModel.presentEmojiPicker(tag: self.tagForInputView)
            })

        emojiButton.accessibilityLabel = NSLocalizedString("compose.emoji-button", comment: "")

        addButton.image = UIImage(systemName: "plus.circle.fill")
        addButton.primaryAction = UIAction { [weak self] _ in self?.addStatus() }

        switch parentViewModel.identityContext.appPreferences.statusWord {
        case .toot:
            addButton.accessibilityLabel =
                NSLocalizedString("compose.add-button-accessibility-label.toot", comment: "")
        case .post:
            addButton.accessibilityLabel =
                NSLocalizedString("compose.add-button-accessibility-label.post", comment: "")
        }

        charactersBarItem.isEnabled = false

        toolbar.items = [
            attachmentButton,
            UIBarButtonItem.fixedSpace(.defaultSpacing),
            pollButton,
            UIBarButtonItem.fixedSpace(.defaultSpacing),
            visibilityButton,
            UIBarButtonItem.fixedSpace(.defaultSpacing),
            contentWarningButton,
            UIBarButtonItem.fixedSpace(.defaultSpacing),
            emojiButton,
            UIBarButtonItem.flexibleSpace(),
            charactersBarItem,
            UIBarButtonItem.fixedSpace(.defaultSpacing),
            addButton]

        self.autocompleteCollectionView.publisher(for: \.contentSize)
            .map(\.height)
            .removeDuplicates()
            .throttle(for: .seconds(TimeInterval.shortAnimationDuration), scheduler: DispatchQueue.main, latest: true)
            .sink { [weak self] height in
                UIView.animate(withDuration: .zeroIfReduceMotion(.shortAnimationDuration)) {
                    self?.setAutocompleteCollectionViewHeight(height)
                }
            }
            .store(in: &cancellables)

        parentViewModel.$visibility
            .sink { [weak self] in
                visibilityButton.image = UIImage(systemName: $0.systemImageName)
                visibilityButton.menu = self?.visibilityMenu(selectedVisibility: $0)
                visibilityButton.accessibilityLabel = String.localizedStringWithFormat(
                    NSLocalizedString("compose.visibility-button.accessibility-label-%@", comment: ""),
                    $0.title ?? "")
            }
            .store(in: &cancellables)
    }

    /// Attach some controls to view model events.
    func viewModelSetup() {
        guard let viewModel = viewModel else {
            return
        }

        viewModel.$displayContentWarning.sink { [weak self] in
            guard let self = self else { return }
            if $0 {
                self.contentWarningButton.accessibilityHint =
                    NSLocalizedString("compose.content-warning-button.remove", comment: "")
            } else {
                self.contentWarningButton.accessibilityHint =
                    NSLocalizedString("compose.content-warning-button.add", comment: "")
            }
        }
        .store(in: &cancellables)

        viewModel.$canAddAttachment
            .sink { [weak self] in self?.attachmentButton.isEnabled = $0 }
            .store(in: &cancellables)

        viewModel.$attachmentViewModels
            .combineLatest(viewModel.$attachmentUploadViewModels)
            .sink { [weak self] in self?.pollButton.isEnabled = $0.isEmpty && $1.isEmpty }
            .store(in: &cancellables)

        viewModel.$remainingCharacters.sink { [weak self] in
            guard let self = self else { return }
            self.charactersBarItem.title = String($0)
            self.charactersBarItem.setTitleTextAttributes(
                [.foregroundColor: $0 < 0 ? UIColor.systemRed : UIColor.label],
                for: .disabled)
            self.charactersBarItem.accessibilityHint = String.localizedStringWithFormat(
                NSLocalizedString("compose.characters-remaining-accessibility-label-%ld", comment: ""),
                $0)
        }
        .store(in: &cancellables)

        viewModel.$isPostable
            .sink { [weak self] in self?.addButton.isEnabled = $0 }
            .store(in: &cancellables)
    }
}

extension CompositionInputAccessoryView: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)

        guard let item = autocompleteDataSource.itemIdentifier(for: indexPath) else { return }

        switch item {
        case let .account(account):
            autocompleteSelectionsSubject.send("@".appending(account.acct))
        case let .tag(tag):
            autocompleteSelectionsSubject.send("#".appending(tag.name))
        case let .emoji(emoji):
            let escaped = emoji.applyingDefaultSkinTone(identityContext: parentViewModel.identityContext).escaped

            autocompleteSelectionsSubject.send(escaped)
            autocompleteDataSource.updateUse(emoji: emoji)
        }

        UISelectionFeedbackGenerator().selectionChanged()

        // To dismiss without waiting for the throttle
        UIView.animate(withDuration: .zeroIfReduceMotion(.shortAnimationDuration)) {
            self.setAutocompleteCollectionViewHeight(.hairline)
        }
    }

    func collectionView(_ collectionView: UICollectionView,
                        contextMenuConfigurationForItemAt indexPath: IndexPath,
                        point: CGPoint) -> UIContextMenuConfiguration? {
        guard let item = autocompleteDataSource.itemIdentifier(for: indexPath),
              case let .emoji(emojiItem) = item,
              case let .system(emoji, _) = emojiItem,
              !emoji.skinToneVariations.isEmpty
        else { return nil }

        return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { _ in
            UIMenu(children: ([emoji] + emoji.skinToneVariations).map { skinToneVariation in
                UIAction(title: skinToneVariation.emoji) { [weak self] _ in
                    self?.autocompleteSelectionsSubject.send(skinToneVariation.emoji)
                    self?.autocompleteDataSource.updateUse(emoji: emojiItem)
                }
            })
        }
    }
}

private extension CompositionInputAccessoryView {
    static func autocompleteLayout() -> UICollectionViewLayout {
        var listConfig = UICollectionLayoutListConfiguration(appearance: .plain)

        listConfig.backgroundColor = .clear

        return UICollectionViewCompositionalLayout { index, environment -> NSCollectionLayoutSection? in
            guard let autocompleteSection = AutocompleteSection(rawValue: index) else { return nil }

            switch autocompleteSection {
            case .search:
                return .list(using: listConfig, layoutEnvironment: environment)
            case .emoji:
                let itemSize = NSCollectionLayoutSize(
                    widthDimension: .fractionalWidth(1.0),
                    heightDimension: .fractionalHeight(1.0))
                let item = NSCollectionLayoutItem(layoutSize: itemSize)
                let groupSize = NSCollectionLayoutSize(
                    widthDimension: .absolute(.minimumButtonDimension),
                    heightDimension: .absolute(.minimumButtonDimension))
                let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])
                let section = NSCollectionLayoutSection(group: group)

                section.interGroupSpacing = .defaultSpacing
                section.orthogonalScrollingBehavior = .continuous
                section.contentInsets = NSDirectionalEdgeInsets(
                    top: .compactSpacing,
                    leading: .compactSpacing,
                    bottom: .compactSpacing,
                    trailing: .compactSpacing)

                return section
            }
        }
    }

    func visibilityMenu(selectedVisibility: Status.Visibility) -> UIMenu {
        UIMenu(children: Status.Visibility.allCasesExceptUnknown.reversed().map { visibility in
            UIAction(
                title: visibility.title ?? "",
                image: UIImage(systemName: visibility.systemImageName),
                discoverabilityTitle: visibility.description,
                state: visibility == selectedVisibility ? .on : .off) { [weak self] _ in
                self?.parentViewModel.visibility = visibility
            }
        })
    }

    func setAutocompleteCollectionViewHeight(_ height: CGFloat) {
        let autocompleteCollectionViewHeight = min(max(height, .hairline), Self.autocompleteCollectionViewMaxHeight)

        autocompleteCollectionViewHeightConstraint.constant = autocompleteCollectionViewHeight
        autocompleteCollectionView.alpha = autocompleteCollectionViewHeightConstraint.constant == .hairline ? 0 : 1

        heightConstraint?.constant = .minimumButtonDimension + autocompleteCollectionViewHeight
        updateConstraints()
        superview?.superview?.layoutIfNeeded()
    }

    func presentDocumentPicker() {
        if let viewModel = self.viewModel {
            self.parentViewModel.presentDocumentPicker(viewModel: viewModel)
        }
    }

    func presentMediaPicker() {
        if let viewModel = self.viewModel {
            self.parentViewModel.presentMediaPicker(viewModel: viewModel)
        }
    }

    func presentCamera() {
        if let viewModel = self.viewModel {
            self.parentViewModel.presentCamera(viewModel: viewModel)
        }
    }

    func togglePoll() {
        viewModel?.displayPoll.toggle()
    }

    func toggleContentWarning() {
        viewModel?.displayContentWarning.toggle()
    }

    func addStatus() {
        if let viewModel = self.viewModel {
            self.parentViewModel.insert(after: viewModel)
        }
    }
}

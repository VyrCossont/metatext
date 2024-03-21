// Copyright © 2021 Metabolist. All rights reserved.

import Combine
import UIKit
import ViewModels

final class ExploreViewController: UICollectionViewController {
    private let webfingerIndicatorView = WebfingerIndicatorView()
    private let searchResultsController: TableViewController
    private let viewModel: ExploreViewModel
    private let rootViewModel: RootViewModel
    private var cancellables = Set<AnyCancellable>()

    private lazy var dataSource: ExploreDataSource = {
        .init(collectionView: collectionView, viewModel: viewModel)
    }()

    init(viewModel: ExploreViewModel, rootViewModel: RootViewModel) {
        self.viewModel = viewModel
        self.rootViewModel = rootViewModel
        self.searchResultsController = TableViewController(
            viewModel: viewModel.searchViewModel,
            rootViewModel: rootViewModel,
            insetBottom: false
        )

        super.init(collectionViewLayout: Self.layout())

        self.searchResultsController.parentNavigationController = navigationController

        tabBarItem = UITabBarItem(
            title: NSLocalizedString("main-navigation.explore", comment: ""),
            image: UIImage(systemName: "magnifyingglass"),
            selectedImage: nil)

        viewModel.$announcementCount
            .sink { [weak self] (_, unread) in
                if unread > 0 {
                    self?.tabBarItem.badgeValue = String(describing: unread)
                } else {
                    self?.tabBarItem.badgeValue = nil
                }
            }
            .store(in: &cancellables)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        collectionView.dataSource = dataSource
        collectionView.backgroundColor = .systemBackground
        collectionView.contentInset.bottom = Self.bottomInset
        collectionView.isAccessibilityElement = false
        collectionView.shouldGroupAccessibilityChildren = true
        clearsSelectionOnViewWillAppear = true

        collectionView.refreshControl = UIRefreshControl()
        collectionView.refreshControl?.addAction(
            UIAction { [weak self] _ in
                self?.viewModel.refresh() },
            for: .valueChanged)

        navigationItem.title = NSLocalizedString("main-navigation.explore", comment: "")

        let searchController = UISearchController(searchResultsController: searchResultsController)

        searchController.searchResultsUpdater = self
        searchController.searchBar.keyboardType = .twitter
        searchController.searchBar.autocapitalizationType = .none
        searchController.searchBar.autocorrectionType = .no
        searchController.searchBar.smartDashesType = .no
        searchController.searchBar.smartInsertDeleteType = .no
        searchController.searchBar.smartQuotesType = .no
        navigationItem.searchController = searchController

        view.addSubview(webfingerIndicatorView)
        webfingerIndicatorView.translatesAutoresizingMaskIntoConstraints = false

        viewModel.identityContext.$appPreferences.sink { appPreferences in
            searchController.searchBar.scopeButtonTitles = SearchScope.allCases.map {
                $0.title(statusWord: appPreferences.statusWord)
            }
        }
        .store(in: &cancellables)

        NSLayoutConstraint.activate([
            webfingerIndicatorView.centerXAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerXAnchor),
            webfingerIndicatorView.centerYAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerYAnchor)
        ])

        // Forward events to the table view controller that can handle them.
        // TODO: (Vyr) this table view controller does not seem to actually be in the view hierarchy:
        //  Tap an image or video and you'll get an error like:
        //  Attempt to present <AVPlayerViewController: 0x7fb997213800> on <Feditext.TableViewController: 0x7fb9b687a000> (from <Feditext.TableViewController: 0x7fb9b687a000>) whose view is not in the window hierarchy.
        viewModel.events
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in
                switch $0 {
                case let .navigation(navigation):
                    self?.handle(navigation: navigation)
                default:
                    self?.searchResultsController.handle(event: $0)
                }
            }
            .store(in: &cancellables)

        viewModel.$loading.sink { [weak self] in
            guard let self = self else { return }

            let refreshControlVisible = self.collectionView.refreshControl?.isRefreshing ?? false

            if !$0, refreshControlVisible {
                self.collectionView.refreshControl?.endRefreshing()
            }
        }
        .store(in: &cancellables)

        viewModel.searchViewModel.searchScopeChanges.sink { [weak self] in
            searchController.searchBar.selectedScopeButtonIndex = $0.rawValue
            self?.updateSearchResults(for: searchController)
        }
        .store(in: &cancellables)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        viewModel.refresh()
    }

    override func collectionView(_ collectionView: UICollectionView,
                                 shouldHighlightItemAt indexPath: IndexPath) -> Bool {
        dataSource.itemIdentifier(for: indexPath) != .instance
    }

    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard let item = dataSource.itemIdentifier(for: indexPath) else { return }

        viewModel.select(item: item)
    }
}

extension ExploreViewController: UISearchResultsUpdating {
    func updateSearchResults(for searchController: UISearchController) {
        if let scope = SearchScope(rawValue: searchController.searchBar.selectedScopeButtonIndex) {
            if scope != viewModel.searchViewModel.scope,
               let scrollView = searchController.searchResultsController?.view as? UIScrollView {
                scrollView.setContentOffset(.init(x: 0, y: -scrollView.safeAreaInsets.top), animated: false)
            }

            viewModel.searchViewModel.scope = scope
        }

        viewModel.searchViewModel.query = searchController.searchBar.text ?? ""
    }
}

extension ExploreViewController: ScrollableToTop {
    func scrollToTop(animated: Bool) {
        collectionView.scrollToTop(animated: animated)
    }
}

extension ExploreViewController: NavigationHandling {
    func handle(navigation: Navigation) {
        switch navigation {
        case let .collection(collectionService):
            let vc = TableViewController(
                viewModel: CollectionItemsViewModel(
                    collectionService: collectionService,
                    identityContext: viewModel.identityContext),
                rootViewModel: rootViewModel,
                parentNavigationController: nil)

            show(vc, sender: self)
            webfingerIndicatorView.stopAnimating()
        case let .profile(profileService):
            let vc = ProfileViewController(
                viewModel: ProfileViewModel(
                    profileService: profileService,
                    identityContext: viewModel.identityContext),
                rootViewModel: rootViewModel,
                identityContext: viewModel.identityContext,
                parentNavigationController: nil)

            show(vc, sender: self)
            webfingerIndicatorView.stopAnimating()
        case let .url(url):
            open(url: url, identityContext: viewModel.identityContext)
            webfingerIndicatorView.stopAnimating()
        case .webfingerStart:
            webfingerIndicatorView.startAnimating()
        case .webfingerEnd:
            webfingerIndicatorView.stopAnimating()
        default:
            searchResultsController.handle(navigation: navigation)
        }
    }
}

private extension ExploreViewController {
    static let bottomInset: CGFloat = .newStatusButtonDimension + .defaultSpacing * 4

    static func layout() -> UICollectionViewLayout {
        var listConfiguration = UICollectionLayoutListConfiguration(appearance: .plain)

        listConfiguration.headerMode = .supplementary

        return UICollectionViewCompositionalLayout(
            sectionProvider: {
                let section = NSCollectionLayoutSection.list(using: listConfiguration, layoutEnvironment: $1)

                if UIDevice.current.userInterfaceIdiom == .pad {
                    section.contentInsetsReference = .readableContent
                }

                return section
            })
    }
}

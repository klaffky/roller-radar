//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import Defaults
import FactoryKit
import Foundation
import JellyfinAPI

struct DefaultContentGroupProvider: ContentGroupProvider {

    @Injected(\.currentUserSession)
    var userSession: UserSession?

    let displayTitle: String = L10n.home

    /// Number of genre rows shown on the home screen
    private let homeGenreRowCount = 5
    let id: String = "default-content-group-provider"

    func makeGroups(environment: Empty) async throws -> [any ContentGroup] {
        guard let userSession else { return [] }

        let parameters = Paths.GetUserViewsParameters(userID: userSession.user.id)
        let userViewsPath = Paths.getUserViews(parameters: parameters)
        let userViews = try await userSession.send(userViewsPath)
        let excludedLibraryIDs = userSession.user.data.configuration?.latestItemsExcludes ?? []

        let resolvedUserViews = (userViews.value.items ?? [])
            .subtracting(excludedLibraryIDs, using: \.id)
            .intersecting(
                [
                    .homevideos,
                    .movies,
                    .musicvideos,
                    .tvshows,
                ],
                using: \.collectionType
            )

        let genres = (try? await homeGenres(userSession: userSession)) ?? []

        return _makeGroups(userViews: resolvedUserViews, genres: genres)
    }

    /// Movie/series genres ordered by how many items they contain.
    /// Falls back to a random order if the server does not report counts.
    private func homeGenres(userSession: UserSession) async throws -> [String] {
        var parameters = Paths.GetGenresParameters()
        parameters.userID = userSession.user.id
        parameters.includeItemTypes = [.movie, .series]
        parameters.fields = [.itemCounts]
        parameters.enableImages = false

        let response = try await userSession.client.send(Paths.getGenres(parameters: parameters))
        let genres = response.value.items ?? []

        let counted = genres.map { genre in
            (name: genre.name ?? "", count: (genre.movieCount ?? 0) + (genre.seriesCount ?? 0) + (genre.childCount ?? 0))
        }
        .filter { $0.name.isNotEmpty }

        if counted.contains(where: { $0.count > 0 }) {
            return counted
                .filter { $0.count > 0 }
                .sorted { $0.count > $1.count }
                .map(\.name)
        }

        return counted.map(\.name).shuffled()
    }

    @ContentGroupBuilder
    private func _makeGroups(userViews: [BaseItemDto], genres: [String]) -> [any ContentGroup] {

        #if os(tvOS)
        let cinematicSelectionContentGroup = CinematicSelectionContentGroup(
            resumeLibrary: ResumeItemsLibrary(mediaTypes: [.video]),
            recentlyAddedLibrary: RecentlyAddedLibrary()
        )

        cinematicSelectionContentGroup
        #else
        HeroBannerContentGroup()

        PosterGroup(
            library: ResumeItemsLibrary(mediaTypes: [.video]),
            posterDisplayType: .landscape,
            posterSize: .medium,
            _viewContext: .isInResume
        )
        #endif

        PosterGroup(
            library: NextUpLibrary()
        )

        if Defaults[.Customization.Home.showRecentlyAdded] {
            #if os(tvOS)
            CinematicRecentlyAddedContentGroup(
                viewModel: cinematicSelectionContentGroup.viewModel
            )
            #else
            PosterGroup(
                library: ItemLibrary(
                    parent: BaseItemDto(name: L10n.recentlyAdded.localizedCapitalized),
                    filters: .init(
                        itemTypes: [.movie, .series],
                        sortBy: [.dateCreated],
                        sortOrder: [.descending]
                    )
                )
            )
            #endif
        }

        if Defaults[.Customization.Home.showRecentlyPlayed] {
            PosterGroup(
                library: ItemLibrary(
                    parent: BaseItemDto(name: L10n.recentlyPlayed.localizedCapitalized),
                    filters: .init(
                        itemTypes: [.movie, .series],
                        sortBy: [.datePlayed],
                        sortOrder: [.descending],
                        traits: [.isPlayed]
                    )
                )
            )
        }

        PosterGroup(
            id: "programs-recommended",
            library: RecommendedProgramsLibrary(),
            posterDisplayType: .landscape,
            posterSize: .small
        )

        PillGroup(
            displayTitle: L10n.genres,
            id: "home-genres",
            elements: genres.map(ItemGenre.init(stringLiteral:))
        ) { router, genre in
            router.route(
                to: .contentGroup(
                    provider: ItemTypeContentGroupProvider(
                        itemTypes: [BaseItemKind.movie, .series],
                        parent: BaseItemDto(name: genre.displayTitle),
                        environment: .init(filters: .init(genres: [genre]))
                    )
                )
            )
        }

        genres
            .prefix(homeGenreRowCount)
            .map { genre in
                PosterGroup(
                    id: "home-genre-\(genre)",
                    library: ItemLibrary(
                        parent: BaseItemDto(name: genre),
                        filters: .init(
                            sortBy: [.communityRating],
                            sortOrder: [.descending]
                        ),
                        staticFilters: .init(
                            genres: [ItemGenre(stringLiteral: genre)],
                            itemTypes: [.movie, .series]
                        )
                    )
                )
            }

        userViews
            .map(LatestInLibrary.init)
            .map {
                PosterGroup(
                    library: $0,
                    posterDisplayType: .landscape
                )
            }
    }
}

//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import Combine
import FactoryKit
import JellyfinAPI
import SwiftUI

struct HeroBannerView: View {

    @ObservedObject
    var viewModel: PagingLibraryViewModel<RecentlyAddedLibrary>

    @Router
    private var router

    @State
    private var selection: ItemEntry.ID?
    @State
    private var isStartingPlayback = false

    private let heroAspectRatio: CGFloat = 0.78
    private let autoAdvance = Timer.publish(every: 8, on: .main, in: .common).autoconnect()

    private var entries: [ItemEntry] {
        Array(viewModel.elements.elements.prefix(8))
    }

    private var currentID: ItemEntry.ID? {
        selection ?? entries.first?.id
    }

    var body: some View {
        Color.clear
            .aspectRatio(heroAspectRatio, contentMode: .fit)
            .frame(maxWidth: .infinity)
            .overlay {
                TabView(selection: $selection) {
                    ForEach(entries) { entry in
                        HeroBannerPage(
                            entry: entry,
                            isStartingPlayback: isStartingPlayback,
                            onPlay: { play(entry) },
                            onSelect: { router.route(to: .item(item: entry.snapshot)) }
                        )
                        .tag(Optional(entry.id))
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }
            .overlay(alignment: .bottom) {
                pageIndicator
                    .padding(.bottom, 12)
            }
            .clipped()
            .colorScheme(.dark)
            .onReceive(autoAdvance) { _ in
                advance()
            }
    }

    // MARK: - Page Indicator

    @ViewBuilder
    private var pageIndicator: some View {
        if entries.count > 1 {
            HStack(spacing: 6) {
                ForEach(entries) { entry in
                    Capsule()
                        .fill(entry.id == currentID ? Color.white : Color.white.opacity(0.35))
                        .frame(width: entry.id == currentID ? 18 : 6, height: 6)
                }
            }
            .animation(.spring(duration: 0.35), value: currentID)
        }
    }

    private func advance() {
        guard entries.count > 1, !isStartingPlayback else { return }

        let index = entries.firstIndex { $0.id == currentID } ?? 0
        let next = entries[(index + 1) % entries.count]

        withAnimation(.easeInOut(duration: 0.6)) {
            selection = next.id
        }
    }

    // MARK: - Playback

    /// Resolves the item to play and hands it to Swiftfin's existing video player route.
    private func play(_ entry: ItemEntry) {
        guard !isStartingPlayback else { return }

        let item = entry.snapshot

        guard let userSession = Container.shared.currentUserSession() else {
            router.route(to: .item(item: item))
            return
        }

        isStartingPlayback = true

        Task { @MainActor in
            defer { isStartingPlayback = false }

            do {
                let playbackItem: BaseItemDto? = if item.type == .series {
                    try await seriesPlaybackItem(for: item, userSession: userSession)
                } else if item.isPlayable {
                    item
                } else {
                    nil
                }

                guard let playbackItem else {
                    router.route(to: .item(item: item))
                    return
                }

                let fullEntry = try await userSession.getFullItem(playbackItem)
                let provider = withExtendedLifetime(fullEntry) {
                    fullEntry.snapshot.getPlaybackItemProvider(userSession: userSession)
                }

                guard let provider else {
                    router.route(to: .item(item: item))
                    return
                }

                let queue: (any MediaPlayerQueue)? = provider.item.type == .episode ?
                    EpisodeMediaPlayerQueue(episode: provider.item) : nil

                router.route(to: .videoPlayer(provider: provider, queue: queue))
            } catch {
                router.route(to: .item(item: item))
            }
        }
    }

    private func seriesPlaybackItem(for series: BaseItemDto, userSession: UserSession) async throws -> BaseItemDto? {
        var nextUpParameters = Paths.GetNextUpParameters()
        nextUpParameters.seriesID = series.id
        nextUpParameters.limit = 1

        let nextUp = try await userSession.client.send(Paths.getNextUp(parameters: nextUpParameters))

        if let item = nextUp.value.items?.first, !item.isMissing {
            return item
        }

        var parameters = Paths.GetItemsParameters()
        parameters.includeItemTypes = [.episode]
        parameters.isMissing = false
        parameters.isRecursive = true
        parameters.limit = 1
        parameters.parentID = series.id
        parameters.sortOrder = [.ascending]

        let first = try await userSession.client.send(Paths.getItems(parameters: parameters))

        return first.value.items?.first
    }
}

// MARK: - Page

private struct HeroBannerPage: View {

    let entry: ItemEntry
    let isStartingPlayback: Bool
    let onPlay: () -> Void
    let onSelect: () -> Void

    private var item: BaseItemDto {
        entry.snapshot
    }

    private var subtitle: String {
        var parts: [String] = []

        if let year = item.productionYear {
            parts.append(String(year))
        }

        if let genres = item.genres?.prefix(2), genres.isNotEmpty {
            parts.append(contentsOf: genres)
        }

        if let rating = item.officialRating {
            parts.append(rating)
        }

        return parts.joined(separator: " · ")
    }

    @ViewBuilder
    private var logo: some View {
        ImageView(
            item.imageSource(
                .logo,
                itemID: item.id,
                environment: ImageSourceOptions(maxWidth: 280, maxHeight: 90)
            )
        )
        .placeholder { _ in
            EmptyView()
        }
        .failure {
            Text(item.displayTitle)
                .font(.largeTitle)
                .fontWeight(.bold)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.7)
                .shadow(color: .black.opacity(0.5), radius: 8)
        }
        .aspectRatio(contentMode: .fit)
        .frame(maxWidth: 280, maxHeight: 90)
        .accessibilityLabel(item.displayTitle)
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            ImageView(entry.imageSources(for: .landscape, environment: .init(maxWidth: 1200, viewContext: .isBackdrop)))
                .failure {
                    Color.secondarySystemFill
                }
                .aspectRatio(contentMode: .fill)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
                .accessibilityHidden(true)

            LinearGradient(
                stops: [
                    .init(color: .black.opacity(0.45), location: 0),
                    .init(color: .clear, location: 0.22),
                    .init(color: .clear, location: 0.45),
                    .init(color: .black.opacity(0.75), location: 0.8),
                    .init(color: .black, location: 1),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .allowsHitTesting(false)

            VStack(spacing: 12) {
                logo

                if subtitle.isNotEmpty {
                    Text(subtitle)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.white.opacity(0.8))
                        .lineLimit(1)
                }

                HStack(spacing: 12) {
                    Button(action: onPlay) {
                        HStack(spacing: 8) {
                            if isStartingPlayback {
                                ProgressView()
                                    .tint(.black)
                            } else {
                                Image(systemName: "play.fill")
                            }

                            Text(L10n.play)
                        }
                        .font(.headline)
                        .foregroundStyle(.black)
                        .frame(maxWidth: 220)
                        .frame(height: 48)
                        .background(Color.white, in: Capsule())
                    }
                    .buttonStyle(.plain)

                    Button(action: onSelect) {
                        Image(systemName: "info")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(width: 48, height: 48)
                            .background(.ultraThinMaterial, in: Circle())
                            .overlay {
                                Circle()
                                    .strokeBorder(Color.white.opacity(0.2), lineWidth: 1)
                            }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(item.displayTitle)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 36)
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onSelect)
    }
}

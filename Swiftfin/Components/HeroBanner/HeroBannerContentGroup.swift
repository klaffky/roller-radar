//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import SwiftUI

/// Large, full-width hero carousel at the top of the home screen
/// showing recently added movies and series.
struct HeroBannerContentGroup: ContentGroup {

    let id = "hero-banner"
    let viewModel: PagingLibraryViewModel<RecentlyAddedLibrary>

    var _shouldBeResolved: Bool {
        viewModel.elements.isNotEmpty
    }

    init(library: RecentlyAddedLibrary = RecentlyAddedLibrary()) {
        self.viewModel = PagingLibraryViewModel(library: library, pageSize: 8)
    }

    func body(with viewModel: PagingLibraryViewModel<RecentlyAddedLibrary>) -> some View {
        HeroBannerView(viewModel: viewModel)
            .preference(
                key: ContentGroupCustomizationKey.self,
                value: .ignoreSafeAreaTop
            )
    }
}

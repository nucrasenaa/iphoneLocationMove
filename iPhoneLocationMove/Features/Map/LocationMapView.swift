import MapKit
import SwiftUI

struct ResetConfirmationContent: Equatable {
    let title: String
    let message: String

    static func make(hasCleanupOwnership: Bool) -> Self {
        if hasCleanupOwnership {
            return Self(
                title: L10n.text(.resetStopTitle),
                message: L10n.text(.resetStopMessage)
            )
        }
        return Self(
            title: L10n.text(.resetSettingsTitle),
            message: L10n.text(.resetSettingsMessage)
        )
    }
}

private struct ResetConfirmationDialogModifier: ViewModifier {
    let isEnabled: Bool
    let confirmation: ResetConfirmationContent
    @Binding var isPresented: Bool
    let performReset: () -> Void

    @ViewBuilder
    func body(content: Content) -> some View {
        if isEnabled {
            content.confirmationDialog(
                confirmation.title,
                isPresented: $isPresented,
                titleVisibility: .visible
            ) {
                Button(L10n.text(.reset), role: .destructive, action: performReset)
                    .accessibilityIdentifier("workspace-reset-confirm")
                Button(L10n.text(.cancel), role: .cancel) {}
            } message: {
                Text(confirmation.message)
            }
        } else {
            content
        }
    }
}

struct LocationMapView: View {
    @ObservedObject private var languageStore = AppLanguageStore.shared
    @StateObject private var model: LocationMapModel
    @ObservedObject private var favoritesStore: FavoritesStore
    @ObservedObject private var macLocationCoordinator: MacLocationCoordinator
    private let simulationStore: SimulationStore?
    private let presentsResetConfirmationDialog: Bool
    #if DEBUG
    private var onSearchCancellationRequested: () -> Void = {}
    private var onPreviewAddressCancellationRequested: () -> Void = {}
    #endif
    @State private var query = ""
    @State private var searchRequest: MapSearchRequest?
    @State private var activeSearch: MKLocalSearch?
    @State private var activeGeocoder: CLGeocoder?
    @State private var activeDirections: MKDirections?
    @State private var message: String?
    @State private var simulationMessage: String?
    @State private var roundTrip = false
    @State private var isResetConfirmationPresented = false
    @State private var resetConfirmationContent =
        ResetConfirmationContent.make(hasCleanupOwnership: false)
    @State private var editingFavoriteID: UUID?
    @State private var favoriteDraft = ""
    @FocusState private var favoriteFieldIsFocused: Bool

    init(
        simulationStore: SimulationStore? = nil,
        macLocationCoordinator: MacLocationCoordinator = MacLocationCoordinator(),
        model: LocationMapModel = LocationMapModel(),
        favoritesStore: FavoritesStore,
        initialQuery: String = "",
        initialRoundTrip: Bool = false,
        presentsResetConfirmationDialog: Bool = true
    ) {
        _model = StateObject(wrappedValue: model)
        _favoritesStore = ObservedObject(wrappedValue: favoritesStore)
        _query = State(initialValue: initialQuery)
        _roundTrip = State(initialValue: initialRoundTrip)
        self.simulationStore = simulationStore
        self.macLocationCoordinator = macLocationCoordinator
        self.presentsResetConfirmationDialog = presentsResetConfirmationDialog
    }

    #if DEBUG
    init(
        simulationStore: SimulationStore? = nil,
        macLocationCoordinator: MacLocationCoordinator = MacLocationCoordinator(),
        model: LocationMapModel = LocationMapModel(),
        favoritesStore: FavoritesStore,
        initialQuery: String = "",
        initialRoundTrip: Bool = false,
        presentsResetConfirmationDialog: Bool = true,
        onSearchCancellationRequested: @escaping () -> Void,
        onPreviewAddressCancellationRequested: @escaping () -> Void
    ) {
        self.init(
            simulationStore: simulationStore,
            macLocationCoordinator: macLocationCoordinator,
            model: model,
            favoritesStore: favoritesStore,
            initialQuery: initialQuery,
            initialRoundTrip: initialRoundTrip,
            presentsResetConfirmationDialog: presentsResetConfirmationDialog
        )
        self.onSearchCancellationRequested = onSearchCancellationRequested
        self.onPreviewAddressCancellationRequested =
            onPreviewAddressCancellationRequested
    }
    #endif

    var body: some View {
        HStack(spacing: 0) {
            controls
                .frame(width: 320)

            Divider()

            mapCanvas
        }
        .onAppear(perform: synchronizeMacLocation)
        .onChange(
            of: macLocationCoordinator.coordinateGeneration
        ) { _ in
            synchronizeMacLocation()
        }
        .modifier(
            ResetConfirmationDialogModifier(
                isEnabled: presentsResetConfirmationDialog,
                confirmation: resetConfirmationContent,
                isPresented: $isResetConfirmationPresented,
                performReset: performReset
            )
        )
    }

    @ViewBuilder
    private var mapCanvas: some View {
        if let simulationStore {
            ObservedSimulationMapCanvas(
                simulationStore: simulationStore,
                preview: model.preview,
                previewCameraIntent: model.previewCameraIntent,
                endpointA: model.endpointA,
                endpointB: model.endpointB,
                route: model.routePreview?.polyline,
                routeCameraIdentity: model.routeCameraIdentity,
                macLocation: model.macLocationCoordinate,
                macInitialCenterIntent: model.macInitialCenterIntent,
                macRecenterIntent: model.macRecenterIntent,
                language: languageStore.language,
                onCoordinateSelected: selectMapCoordinate,
                onManualCameraInteraction: model.recordManualCameraInteraction
            )
        } else {
            LocationMapCanvas(
                preview: model.preview,
                previewCameraIntent: model.previewCameraIntent,
                endpointA: model.endpointA,
                endpointB: model.endpointB,
                route: model.routePreview?.polyline,
                routeCameraIdentity: model.routeCameraIdentity,
                macLocation: model.macLocationCoordinate,
                macInitialCenterIntent: model.macInitialCenterIntent,
                macRecenterIntent: model.macRecenterIntent,
                confirmedRouteMarkerCoordinate: nil,
                language: languageStore.language,
                onCoordinateSelected: selectMapCoordinate,
                onManualCameraInteraction: model.recordManualCameraInteraction
            )
        }
    }

    private var controls: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text(L10n.text(.mapAndRoute))
                    .font(.title2)

                VStack(alignment: .leading, spacing: 8) {
                    Button(L10n.text(.recenterMac)) {
                        do {
                            try model.requestMacRecenter()
                            message = nil
                        } catch {
                            show(error)
                        }
                    }
                    .disabled(!model.canRecenterOnMac)
                    .accessibilityIdentifier("mac-recenter-button")
                    .mapSidebarPrimaryActionLayout()
                    .testingLayoutRegion("sidebar-button-mac-recenter")

                    resetControl
                        .mapSidebarPrimaryActionLayout()
                        .testingLayoutRegion("sidebar-button-reset")
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                searchControls
                searchResults
                previewControls
                endpointControls
                routeControls
                if let simulationStore {
                    SimulationControls(
                        mapModel: model,
                        simulationStore: simulationStore,
                        roundTrip: $roundTrip,
                        message: $simulationMessage
                    )
                } else {
                    DisconnectedSimulationControls()
                }
                favoritesControls

                if let message {
                    Text(message)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .testingLayoutRegion("sidebar-workspace-message-region")
                }
                if let macLocationMessage = macLocationCoordinator.message {
                    Text(macLocationMessage)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .testingLayoutRegion("sidebar-device-status-region")
                }
            }
            .padding()
        }
        .background {
            ZStack {
                #if DEBUG
                TestingActionMarker(
                    identifier: "round-trip-state",
                    isEnabled: false,
                    isOn: roundTrip,
                    action: {}
                )
                .frame(width: 0, height: 0)
                .allowsHitTesting(false)
                TestingActionMarker(
                    identifier: "workspace-reset-confirmation-action",
                    isEnabled: isResetConfirmationPresented,
                    action: performConfirmedResetForTesting
                )
                .frame(width: 0, height: 0)
                .allowsHitTesting(false)
                #endif
            }
        }
    }

    private var searchControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField(L10n.text(.searchPlaceholder), text: $query)
                .textFieldStyle(.roundedBorder)
                .accessibilityIdentifier("workspace-search-query")
                .onSubmit(performSearch)

            HStack(spacing: 8) {
                Button(L10n.text(.search), action: performSearch)
                    .disabled(query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .testingLayoutRegion("sidebar-button-search")
                Button(L10n.text(.clear)) {
                    cancelSearch()
                    cancelPreviewAddressLookup()
                    query = ""
                    do {
                        try model.clearSearch()
                        message = nil
                    } catch {
                        show(error)
                    }
                }
                .testingLayoutRegion("sidebar-button-clear-search")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private var searchResults: some View {
        if !model.searchResults.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                Text(L10n.text(.searchResults))
                    .font(.headline)
                ForEach(
                    Array(model.searchResults.enumerated()),
                    id: \.offset
                ) { offset, place in
                    Button {
                        selectSearchResult(place)
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(place.address ?? L10n.text(.unnamedPlace))
                            Text(coordinateText(place.coordinate))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                    .testingLayoutRegion("sidebar-button-search-result-\(offset)")
                    .background {
                        #if DEBUG
                        TestingActionMarker(
                            identifier: "search-result-selection-action-\(offset)",
                            isEnabled: true
                        ) {
                            selectSearchResult(place)
                        }
                        .frame(width: 0, height: 0)
                        .allowsHitTesting(false)
                        #endif
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var previewControls: some View {
        if let preview = model.preview {
            GroupBox(L10n.text(.currentPreview)) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(preview.address ?? L10n.text(.mapPoint))
                    Text(coordinateText(preview.coordinate))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(L10n.text(.previewNotice))
                        .font(.caption)

                    HStack(spacing: 8) {
                        Button {
                            favoritesStore.toggle(preview)
                        } label: {
                            Text(favoriteToggleTitle(for: preview))
                                .accessibilityIdentifier(
                                    "favorite-toggle-rendered-title-"
                                        + favoriteToggleTitle(for: preview)
                                )
                        }
                        .accessibilityLabel(favoriteToggleTitle(for: preview))
                        .accessibilityIdentifier(favoriteToggleIdentifier(for: preview))
                        .testingLayoutRegion("sidebar-button-favorite-toggle")
                        .background {
                            #if DEBUG
                            TestingActionMarker(
                                identifier: favoritesStore.isFavorite(preview.coordinate)
                                    ? "favorite-toggle-remove-action"
                                    : "favorite-toggle-add-action",
                                isEnabled: true
                            ) {
                                favoritesStore.toggle(preview)
                            }
                            .frame(width: 0, height: 0)
                            .allowsHitTesting(false)
                            #endif
                        }
                        Button(L10n.text(.setA)) {
                            assignPreview(to: .a)
                        }
                        .testingLayoutRegion("sidebar-button-endpoint-a")
                        Button(L10n.text(.setB)) {
                            assignPreview(to: .b)
                        }
                        .testingLayoutRegion("sidebar-button-endpoint-b")
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .overlay(alignment: .topLeading) {
                        FavoriteToggleAccessibilityView(
                            title: favoriteToggleTitle(for: preview)
                        )
                        .frame(width: 1, height: 1)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    /// A row measures 16pt and rows sit 6pt apart, so five rows fill 104pt.
    /// Past that the list scrolls internally instead of growing the sidebar.
    private static let favoritesVisibleRowLimit = 5
    private static let favoritesListMaxHeight: CGFloat = 104

    @ViewBuilder
    private var favoritesControls: some View {
        if !favoritesStore.favorites.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                Divider()
                Text(L10n.text(.favorites))
                    .font(.headline)
                if favoritesStore.favorites.count > Self.favoritesVisibleRowLimit {
                    ScrollView {
                        favoriteRows
                    }
                    .frame(height: Self.favoritesListMaxHeight)
                } else {
                    favoriteRows
                }
            }
            .testingLayoutRegion("sidebar-favorites-list")
        }
    }

    private var favoriteRows: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(favoritesStore.favorites) { favorite in
                favoriteRow(favorite)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func favoriteRow(_ favorite: FavoritePlace) -> some View {
        Group {
            if editingFavoriteID == favorite.id {
                TextField(L10n.text(.name), text: $favoriteDraft)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityIdentifier("favorite-name-editor-\(favorite.id.uuidString)")
                    .focused($favoriteFieldIsFocused)
                    .onSubmit {
                        favoritesStore.rename(id: favorite.id, to: favoriteDraft)
                        editingFavoriteID = nil
                        favoriteFieldIsFocused = false
                    }
                    .onExitCommand {
                        editingFavoriteID = nil
                        favoriteFieldIsFocused = false
                    }
                    .onChange(of: favoriteFieldIsFocused) { focused in
                        if !focused, editingFavoriteID == favorite.id {
                            editingFavoriteID = nil
                        }
                    }
                    .background {
                        #if DEBUG
                        ZStack {
                            TestingActionMarker(identifier: "favorite-submit-rename-action-\(favorite.id.uuidString)", isEnabled: true) {
                                favoritesStore.rename(id: favorite.id, to: "辦公室")
                                editingFavoriteID = nil
                            }
                            TestingActionMarker(identifier: "favorite-submit-blank-rename-action-\(favorite.id.uuidString)", isEnabled: true) {
                                favoritesStore.rename(id: favorite.id, to: "   ")
                                editingFavoriteID = nil
                            }
                        }
                        .frame(width: 0, height: 0)
                        .allowsHitTesting(false)
                        #endif
                    }
            } else {
                Button {
                    selectFavorite(favorite)
                } label: {
                    Text(favorite.name)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .testingLayoutRegion("favorite-row-name-\(favorite.name)")
                }
                .buttonStyle(.plain)
                .background {
                    #if DEBUG
                    ZStack {
                        TestingActionMarker(identifier: "favorite-selection-action-\(favorite.id.uuidString)", isEnabled: true) {
                            selectFavorite(favorite)
                        }
                        TestingActionMarker(identifier: "favorite-rename-action-\(favorite.id.uuidString)", isEnabled: true) {
                            beginFavoriteRename(favorite)
                        }
                        TestingActionMarker(identifier: "favorite-blank-rename-action-\(favorite.id.uuidString)", isEnabled: true) {
                            beginFavoriteRename(favorite)
                        }
                        TestingActionMarker(identifier: "favorite-delete-action-\(favorite.id.uuidString)", isEnabled: true) {
                            favoritesStore.remove(id: favorite.id)
                        }
                    }
                    .frame(width: 0, height: 0)
                    .allowsHitTesting(false)
                    #endif
                }
                .contextMenu {
                    Button(L10n.text(.rename)) {
                        beginFavoriteRename(favorite)
                    }
                    Button(L10n.text(.delete), role: .destructive) {
                        favoritesStore.remove(id: favorite.id)
                    }
                }
            }
        }
    }

    private func selectFavorite(_ favorite: FavoritePlace) {
        do {
            try model.selectFavorite(
                MapSearchPlace(
                    coordinate: favorite.coordinate,
                    address: favorite.address
                )
            )
            cancelSearch()
            cancelPreviewAddressLookup()
            searchRequest = nil
            message = nil
        } catch {
            show(error)
        }
    }

    private func beginFavoriteRename(_ favorite: FavoritePlace) {
        favoriteDraft = favorite.name
        editingFavoriteID = favorite.id
        favoriteFieldIsFocused = true
    }

    private func favoriteToggleIdentifier(for preview: MapSearchPlace) -> String {
        "favorite-toggle-label-"
            + favoriteToggleTitle(for: preview)
    }

    private func favoriteToggleTitle(for preview: MapSearchPlace) -> String {
        favoritesStore.isFavorite(preview.coordinate)
            ? L10n.text(.favoriteRemove)
            : L10n.text(.favoriteAdd)
    }

    private var endpointControls: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(L10n.text(.walkingEndpoints))
                .font(.headline)
            endpointRow(label: "A", place: model.endpointA)
            endpointRow(label: "B", place: model.endpointB)

            Button(L10n.text(.createWalkingRoute), action: performDirections)
                .disabled(model.endpointSnapshot == nil)
                .mapSidebarPrimaryActionLayout()
                .testingLayoutRegion("sidebar-button-directions")
        }
    }

    private var routeControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(L10n.text(.speed))
                Spacer()
                Text(L10n.format(.speedValue, model.walkingSpeedKilometersPerHour))
                    .monospacedDigit()
            }
            .testingLayoutRegion("sidebar-speed-region")
            Slider(
                value: Binding(
                    get: { model.walkingSpeedKilometersPerHour },
                    set: { newValue in
                        do {
                            try model.setWalkingSpeed(
                                kilometersPerHour: newValue
                            )
                            if let simulationStore,
                               let route = simulationStore.routeSnapshot,
                               route.phase == .running || route.phase == .paused
                            {
                                try simulationStore.setSpeed(
                                    newValue,
                                    at: ProcessInfo.processInfo.systemUptime
                                )
                            }
                        } catch {
                            show(error)
                        }
                    }
                ),
                in: LocationMapModel.walkingSpeedRange,
                step: 0.5
            )

            switch model.routeStatus {
            case .idle:
                EmptyView()
            case .loading:
                ProgressView(L10n.text(.gettingWalkingRoute))
            case .routeAvailable:
                if let route = model.routePreview {
                    Text(
                        "\(distanceText(route.distance))・\(durationText(route.estimatedTime))"
                    )
                    .font(.headline)
                    Text(L10n.text(.routeReady))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            case .noPedestrianRoute:
                Text(L10n.text(.noWalkingRoute))
                    .foregroundStyle(.red)
            case .cancelled:
                Text(L10n.text(.routeCancelled))
                    .foregroundStyle(.secondary)
            case .transientFailure(let message):
                Text(message)
                    .foregroundStyle(.red)
                    .testingLayoutRegion("sidebar-route-error-region")
                Button(L10n.text(.retry), action: performDirections)
                    .mapSidebarPrimaryActionLayout()
                    .testingLayoutRegion("sidebar-button-directions-retry")
            }
        }
    }

    private func endpointRow(
        label: String,
        place: MapSearchPlace?
    ) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .font(.headline)
                .frame(width: 20)
            if let place {
                Text(place.address ?? coordinateText(place.coordinate))
                    .lineLimit(2)
            } else {
                Text(L10n.text(.notSelected))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func performSearch() {
        cancelSearch()
        cancelPreviewAddressLookup()
        do {
            let request = try model.beginSearch(query: query)
            searchRequest = request

            let mapRequest = MKLocalSearch.Request()
            mapRequest.naturalLanguageQuery = request.query
            let search = MKLocalSearch(request: mapRequest)
            activeSearch = search
            message = nil

            Task { @MainActor in
                do {
                    let response = try await search.start()
                    let places = response.mapItems.compactMap { item in
                        mapPlace(from: item)
                    }
                    _ = model.receiveSearchResults(places, for: request)
                } catch is CancellationError {
                    return
                } catch {
                    guard request.generation == model.mapSearchGeneration else {
                        return
                    }
                    message = L10n.format(
                        .searchFailed,
                        error.localizedDescription
                    )
                }
                if activeSearch === search {
                    activeSearch = nil
                }
            }
        } catch {
            show(error)
        }
    }

    private func selectSearchResult(_ place: MapSearchPlace) {
        do {
            try model.selectSearchResult(place)
            cancelSearch()
            cancelPreviewAddressLookup()
            searchRequest = nil
            message = nil
        } catch {
            show(error)
        }
    }

    private func selectMapCoordinate(_ coordinate: MapCoordinate) {
        cancelSearch()
        cancelPreviewAddressLookup()
        do {
            let request = try model.selectMapCoordinate(coordinate)
            searchRequest = nil
            message = nil
            lookupAddress(for: request)
        } catch {
            show(error)
        }
    }

    private func assignPreview(to endpoint: MapEndpoint) {
        cancelDirections()
        do {
            try model.assignPreview(to: endpoint)
            message = nil
        } catch {
            show(error)
        }
    }

    private func performDirections() {
        cancelDirections()
        do {
            let request = try model.beginDirections()
            let mapRequest = MKDirections.Request()
            mapRequest.source = mapItem(for: request.snapshot.a)
            mapRequest.destination = mapItem(for: request.snapshot.b)
            mapRequest.transportType = .walking

            let directions = MKDirections(request: mapRequest)
            activeDirections = directions
            message = nil

            Task { @MainActor in
                let response: PedestrianDirectionsResponse
                do {
                    let result = try await directions.calculate()
                    if let route = result.routes.first,
                       let coordinates = mapCoordinates(from: route.polyline)
                    {
                        response = .routeAvailable(
                            coordinates,
                            distance: route.distance
                        )
                    } else {
                        response = .noPedestrianRoute
                    }
                } catch is CancellationError {
                    response = .cancelled
                } catch {
                    response = directionsResponse(for: error)
                }

                do {
                    _ = try model.receiveDirections(response, for: request)
                } catch {
                    show(error)
                }
                if activeDirections === directions {
                    activeDirections = nil
                }
            }
        } catch {
            show(error)
        }
    }

    private func cancelSearch() {
        #if DEBUG
        onSearchCancellationRequested()
        #endif
        activeSearch?.cancel()
        activeSearch = nil
    }

    private func lookupAddress(for request: MapPreviewAddressRequest) {
        let geocoder = CLGeocoder()
        activeGeocoder = geocoder
        let location = CLLocation(
            latitude: request.coordinate.latitude,
            longitude: request.coordinate.longitude
        )

        Task { @MainActor in
            do {
                let placemarks = try await geocoder.reverseGeocodeLocation(location)
                if let placemark = placemarks.first {
                    let address = [
                        placemark.name,
                        placemark.locality,
                        placemark.administrativeArea,
                    ]
                    .compactMap { $0 }
                    .reduce(into: [String]()) { parts, part in
                        if !parts.contains(part) {
                            parts.append(part)
                        }
                    }
                    .joined(separator: " ")
                    if !address.isEmpty {
                        _ = model.receivePreviewAddress(address, for: request)
                    }
                }
            } catch is CancellationError {
                return
            } catch {
                guard request.generation == model.mapSearchGeneration else {
                    return
                }
                message = L10n.format(
                    .addressLookupFailed,
                    error.localizedDescription
                )
            }
            if activeGeocoder === geocoder {
                activeGeocoder = nil
            }
        }
    }

    private func cancelPreviewAddressLookup() {
        #if DEBUG
        onPreviewAddressCancellationRequested()
        #endif
        activeGeocoder?.cancelGeocode()
        activeGeocoder = nil
    }

    private func cancelDirections() {
        activeDirections?.cancel()
        activeDirections = nil
    }

    private func mapPlace(from item: MKMapItem) -> MapSearchPlace? {
        guard let coordinate = try? MapCoordinate(
            latitude: item.placemark.coordinate.latitude,
            longitude: item.placemark.coordinate.longitude
        ) else {
            return nil
        }
        return MapSearchPlace(
            coordinate: coordinate,
            address: item.name ?? item.placemark.title
        )
    }

    private func mapItem(for coordinate: MapCoordinate) -> MKMapItem {
        let placemark = MKPlacemark(
            coordinate: CLLocationCoordinate2D(
                latitude: coordinate.latitude,
                longitude: coordinate.longitude
            )
        )
        return MKMapItem(placemark: placemark)
    }

    private func mapCoordinates(from polyline: MKPolyline) -> [MapCoordinate]? {
        var coordinates = Array(
            repeating: CLLocationCoordinate2D(),
            count: polyline.pointCount
        )
        polyline.getCoordinates(
            &coordinates,
            range: NSRange(location: 0, length: polyline.pointCount)
        )
        let converted = coordinates.compactMap {
            try? MapCoordinate(
                latitude: $0.latitude,
                longitude: $0.longitude
            )
        }
        return converted.count >= 2 ? converted : nil
    }

    private func directionsResponse(
        for error: Error
    ) -> PedestrianDirectionsResponse {
        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain,
           nsError.code == NSURLErrorCancelled
        {
            return .cancelled
        }
        if nsError.domain == MKError.errorDomain,
           nsError.code == MKError.Code.directionsNotFound.rawValue
        {
            return .noPedestrianRoute
        }
        return .transientFailure(message: error.localizedDescription)
    }

    private func coordinateText(_ coordinate: MapCoordinate) -> String {
        String(
            format: "%.6f, %.6f",
            coordinate.latitude,
            coordinate.longitude
        )
    }

    private func distanceText(_ meters: Double) -> String {
        if meters >= 1_000 {
            return L10n.format(.distanceKilometers, meters / 1_000)
        }
        return L10n.format(.distanceMeters, meters)
    }

    private func durationText(_ seconds: TimeInterval) -> String {
        L10n.format(.durationMinutes, seconds / 60)
    }

    private func show(_ error: Error) {
        message = error.localizedDescription
    }

    private func performReset() {
        cancelSearch()
        cancelPreviewAddressLookup()
        cancelDirections()
        do {
            try model.resetWorkspace()
            query = ""
            searchRequest = nil
            message = nil
            simulationMessage = nil
            roundTrip = false
        } catch {
            show(error)
            return
        }

        guard let simulationStore,
              simulationHasCleanupOwnership(simulationStore.state)
        else {
            return
        }
        Task { @MainActor in
            await simulationStore.stop()
            if case .stopping(_, let failure) = simulationStore.state,
               let failure
            {
                simulationMessage = simulationFailureText(failure)
            }
        }
    }

    private func presentResetConfirmation() {
        resetConfirmationContent = ResetConfirmationContent.make(
            hasCleanupOwnership: simulationStore.map {
                simulationHasCleanupOwnership($0.state)
            } ?? false
        )
        isResetConfirmationPresented = true
    }

    #if DEBUG
    private func performConfirmedResetForTesting() {
        guard isResetConfirmationPresented else {
            return
        }
        isResetConfirmationPresented = false
        performReset()
    }
    #endif

    @ViewBuilder
    private var resetControl: some View {
        if let simulationStore {
            ObservedWorkspaceResetButton(
                simulationStore: simulationStore,
                presentConfirmation: presentResetConfirmation
            )
        } else {
            Button(L10n.text(.reset), role: .destructive) {
                presentResetConfirmation()
            }
            .background {
                #if DEBUG
                TestingActionMarker(
                    identifier: "workspace-reset-button",
                    isEnabled: true,
                    action: presentResetConfirmation
                )
                .frame(width: 0, height: 0)
                .allowsHitTesting(false)
                #endif
            }
            .accessibilityIdentifier("workspace-reset-button")
        }
    }

    private func synchronizeMacLocation() {
        guard
            let coordinate = macLocationCoordinator.coordinate,
            let generation = macLocationCoordinator.coordinateGeneration
        else {
            return
        }
        model.updateMacLocation(coordinate, for: generation)
    }
}

private struct ObservedWorkspaceResetButton: View {
    @ObservedObject var simulationStore: SimulationStore
    let presentConfirmation: () -> Void

    var body: some View {
        Button(L10n.text(.reset), role: .destructive) {
            presentConfirmation()
        }
        .disabled(simulationIsBusy(simulationStore.state))
        .background {
            ZStack {
                #if DEBUG
                TestingActionMarker(
                    identifier: "workspace-reset-button",
                    isEnabled: !simulationIsBusy(simulationStore.state),
                    action: presentConfirmation
                )
                .frame(width: 0, height: 0)
                .allowsHitTesting(false)
                #endif
                if case .stopping(_, .some) = simulationStore.state {
                    AccessibilityIdentifierMarker(
                        identifier: "simulation-cleanup-failure"
                    )
                    AccessibilityIdentifierMarker(
                        identifier: "simulation-cleanup-retry"
                    )
                }
            }
        }
        .accessibilityIdentifier("workspace-reset-button")
    }
}

private struct DisconnectedSimulationControls: View {
    @State private var roundTrip = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Divider()
            Text(L10n.text(.iPhoneLocation))
                .font(.headline)
            Button(L10n.text(.setLocation)) {}
                .disabled(true)
                .mapSidebarPrimaryActionLayout()
                .testingLayoutRegion("sidebar-button-set-location")
            Toggle(L10n.text(.roundTrip), isOn: $roundTrip)
                .disabled(true)
            Button(L10n.text(.startWalkingRoute)) {}
                .disabled(true)
                .mapSidebarPrimaryActionLayout()
                .testingLayoutRegion("sidebar-button-start-route")
            Text(L10n.text(.deviceReadyForLocationControl))
                .font(.callout)
                .foregroundStyle(.secondary)
                .testingLayoutRegion("sidebar-device-status-region")
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("simulation-controls-disconnected")
        .background(
            AccessibilityIdentifierMarker(
                identifier: "simulation-controls-disconnected"
            )
        )
    }
}

private struct SimulationControls: View {
    private enum PendingMutation {
        case point(MapCoordinate)
        case route(MapRoutePreview)
        case stop
    }

    @ObservedObject var mapModel: LocationMapModel
    @ObservedObject var simulationStore: SimulationStore
    @Binding var roundTrip: Bool
    @Binding var message: String?
    @State private var pendingMutation: PendingMutation?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Divider()

            Text(L10n.text(.iPhoneLocation))
                .font(.headline)

            if mapModel.preview != nil {
                Button(L10n.text(.setLocation)) {
                    guard let coordinate = mapModel.preview?.coordinate else {
                        return
                    }
                    pendingMutation = .point(coordinate)
                }
                .disabled(isBusy)
                .mapSidebarPrimaryActionLayout()
                .testingLayoutRegion("sidebar-button-set-location")
            }

            Toggle(L10n.text(.roundTrip), isOn: $roundTrip)
                .disabled(!mapModel.canStartRoute || isBusy)
                .accessibilityIdentifier("round-trip-toggle")
                .background {
                    #if DEBUG
                    TestingActionMarker(
                        identifier: "round-trip-toggle",
                        isEnabled: mapModel.canStartRoute && !isBusy,
                        isOn: roundTrip
                    ) {
                        roundTrip.toggle()
                    }
                    .frame(width: 0, height: 0)
                    .allowsHitTesting(false)
                    #endif
                }

            Button(L10n.text(.startWalkingRoute)) {
                do {
                    pendingMutation = .route(
                        try mapModel.confirmRoutePreview()
                    )
                } catch {
                    show(error)
                }
            }
            .disabled(!mapModel.canStartRoute || isBusy)
            .mapSidebarPrimaryActionLayout()
            .testingLayoutRegion("sidebar-button-start-route")

            routeActionButtons

            simulationStatus
                .testingLayoutRegion("sidebar-simulation-status-region")

            if let message {
                Text(message)
                    .font(.callout)
                    .foregroundStyle(.red)
                    .testingLayoutRegion("sidebar-simulation-message-region")
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("simulation-controls-connected")
        .background(
            AccessibilityIdentifierMarker(
                identifier: "simulation-controls-connected"
            )
        )
        .confirmationDialog(
            confirmationTitle,
            isPresented: Binding(
                get: { pendingMutation != nil },
                set: { isPresented in
                    if !isPresented {
                        pendingMutation = nil
                    }
                }
            ),
            titleVisibility: .visible
        ) {
            Button(confirmationButtonTitle) {
                performConfirmedMutation()
            }
            Button(L10n.text(.cancel), role: .cancel) {
                pendingMutation = nil
            }
        } message: {
            Text(confirmationMessage)
        }
    }

    @ViewBuilder
    private var routeActionButtons: some View {
        if let route = simulationStore.routeSnapshot {
            HStack(spacing: 8) {
                switch route.phase {
                case .running:
                    Button(L10n.text(.pause)) {
                        do {
                            try simulationStore.pause()
                            message = nil
                        } catch {
                            show(error)
                        }
                    }
                    .testingLayoutRegion("sidebar-button-pause-route")
                case .paused:
                    Button(L10n.text(.resume)) {
                        do {
                            try simulationStore.resume(
                                at: ProcessInfo.processInfo.systemUptime
                            )
                            message = nil
                        } catch {
                            show(error)
                        }
                    }
                    .testingLayoutRegion("sidebar-button-resume-route")
                default:
                    EmptyView()
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }

        if hasCleanupOwnership {
            Button(L10n.text(.stopSimulation), role: .destructive) {
                pendingMutation = .stop
            }
            .disabled(isStoppingWithoutFailure)
            .mapSidebarPrimaryActionLayout()
            .testingLayoutRegion("sidebar-button-stop-simulation")
        }
    }

    @ViewBuilder
    private var simulationStatus: some View {
        switch simulationStore.state {
        case .idle:
            Text(L10n.text(.notSimulating))
                .foregroundStyle(.secondary)
        case .starting(let mode, _):
            ProgressView(
                mode == .point
                    ? L10n.text(.settingLocation)
                    : L10n.text(.startingRoute)
            )
        case .reconnecting:
            ProgressView(L10n.text(.preparingDeviceAgain))
                .testingLayoutRegion("sidebar-simulation-reconnecting-region")
        case .replacing:
            ProgressView(L10n.text(.replacingSimulation))
        case .pointActive(let point):
            Label(
                String(
                    format: L10n.text(.pointLocation),
                    point.coordinate.latitude,
                    point.coordinate.longitude
                ),
                systemImage: "location.fill"
            )
        case .route(let route, let failure):
            VStack(alignment: .leading, spacing: 4) {
                Text(routePhaseText(route.phase))
                Text(
                    String(
                        format: L10n.text(.confirmedProgress),
                        route.confirmedDistance,
                        route.speedKilometersPerHour
                    )
                )
                .font(.caption)
                .foregroundStyle(.secondary)
                if let failure {
                    Text(failureText(failure))
                        .font(.callout)
                        .foregroundStyle(.red)
                        .testingLayoutRegion("sidebar-simulation-error-region")
                }
            }
        case .interrupted(_, let interruption, let failure):
            VStack(alignment: .leading, spacing: 4) {
                Text(L10n.text(.simulationInterrupted))
                    .foregroundStyle(.red)
                Text(interruption.positionKnowledge == .unknown
                    ? L10n.text(.phoneLocationUnknown)
                    : L10n.text(.phoneLocationKnown))
                Text(failureText(failure))
                    .font(.caption)
            }
            .testingLayoutRegion("sidebar-simulation-error-region")
        case .stopping(_, let failure):
            if let failure {
                VStack(alignment: .leading, spacing: 4) {
                    Text(L10n.text(.clearFailedNotRestored))
                        .foregroundStyle(.red)
                    Text(failureText(failure))
                        .font(.caption)
                }
                .testingLayoutRegion("sidebar-simulation-error-region")
            } else {
                ProgressView(L10n.text(.clearingSimulation))
            }
        }
    }

    private var isBusy: Bool {
        simulationIsBusy(simulationStore.state)
    }

    private var hasCleanupOwnership: Bool {
        simulationHasCleanupOwnership(simulationStore.state)
    }

    private var isStoppingWithoutFailure: Bool {
        if case .stopping(_, nil) = simulationStore.state {
            return true
        }
        return false
    }

    private var confirmationTitle: String {
        switch pendingMutation {
        case .point, .route:
            RiskNotice.simulationStart.title
        case .stop:
            L10n.text(.confirmStopClearTitle)
        case nil:
            L10n.text(.confirmation)
        }
    }

    private var confirmationButtonTitle: String {
        switch pendingMutation {
        case .stop:
            L10n.text(.stopAndClear)
        case .point, .route:
            RiskNotice.simulationStart.confirmationTitle
        case nil:
            L10n.text(.confirmation)
        }
    }

    private var confirmationMessage: String {
        switch pendingMutation {
        case .point, .route:
            RiskNotice.simulationStart.message
        case .stop:
            L10n.text(.resetStopMessage)
        case nil:
            ""
        }
    }

    private func performConfirmedMutation() {
        guard let pendingMutation else {
            return
        }
        self.pendingMutation = nil

        Task { @MainActor in
            switch pendingMutation {
            case .point(let coordinate):
                do {
                    try await confirmPoint(coordinate)
                    message = nil
                } catch {
                    show(error)
                }
            case .route(let mapPreview):
                do {
                    try await simulationStore.startRoute(
                        preview: try RoutePreview(mapPreview: mapPreview),
                        speedKilometersPerHour:
                            mapModel.walkingSpeedKilometersPerHour,
                        roundTrip: roundTrip,
                        riskAccepted: true
                    )
                    message = nil
                } catch {
                    show(error)
                }
            case .stop:
                await simulationStore.stop()
                if case .stopping(_, let failure) = simulationStore.state,
                   let failure {
                    message = failureText(failure)
                } else {
                    message = nil
                }
            }
        }
    }

    private func confirmPoint(_ coordinate: MapCoordinate) async throws {
        let deviceCoordinate = try DeviceCoordinate(
            latitude: coordinate.latitude,
            longitude: coordinate.longitude
        )
        await simulationStore.confirmPoint(
            deviceCoordinate,
            riskAccepted: true
        )
    }

    private func routePhaseText(_ phase: RouteSessionPhase) -> String {
        switch phase {
        case .idle:
            L10n.text(.routeNotStarted)
        case .preview:
            L10n.text(.routePreview)
        case .running:
            L10n.text(.routeMoving)
        case .pausing:
            L10n.text(.confirmingPauseLocation)
        case .paused:
            L10n.text(.routePaused)
        case .completed:
            L10n.text(.oneWayCompleted)
        case .interrupted:
            L10n.text(.routeInterrupted)
        case .stopping:
            L10n.text(.stoppingRoute)
        }
    }

    private func failureText(_ failure: DeviceLocationError) -> String {
        simulationFailureText(failure)
    }

    private func show(_ error: Error) {
        message = error.localizedDescription
    }
}

private func simulationIsBusy(_ state: SimulationStoreState) -> Bool {
    switch state {
    case .starting, .reconnecting, .replacing:
        true
    case .stopping(_, nil):
        true
    default:
        false
    }
}

private func simulationHasCleanupOwnership(
    _ state: SimulationStoreState
) -> Bool {
    switch state {
    case .pointActive, .route, .interrupted, .stopping:
        true
    case .idle, .starting, .reconnecting, .replacing:
        false
    }
}

private func simulationFailureText(_ failure: DeviceLocationError) -> String {
    let presentation = DeviceFailurePresentation.make(for: failure)
    return L10n.format(
        .failureSummary,
        presentation.title,
        presentation.message
    )
}

private extension View {
    func mapSidebarPrimaryActionLayout() -> some View {
        frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    func testingLayoutRegion(_ identifier: String) -> some View {
        #if DEBUG
        background(
            TestingLayoutRegionMarker(identifier: identifier)
                .allowsHitTesting(false)
        )
        #else
        self
        #endif
    }
}

extension RoutePreview {
    init(mapPreview: MapRoutePreview) throws {
        guard mapPreview.polyline.count >= 2,
              mapPreview.distance.isFinite,
              mapPreview.distance > 0
        else {
            throw LocationMapError.invalidRoute
        }

        var retainedCoordinates = [MapCoordinate]()
        var rawCumulativeDistances = [Double]()
        var cumulativeDistance = 0.0

        for coordinate in mapPreview.polyline {
            if let previous = retainedCoordinates.last {
                let distance = CLLocation(
                    latitude: previous.latitude,
                    longitude: previous.longitude
                ).distance(
                    from: CLLocation(
                        latitude: coordinate.latitude,
                        longitude: coordinate.longitude
                    )
                )
                guard distance > 0 else {
                    continue
                }
                cumulativeDistance += distance
            }
            retainedCoordinates.append(coordinate)
            rawCumulativeDistances.append(cumulativeDistance)
        }

        guard retainedCoordinates.count >= 2, cumulativeDistance > 0 else {
            throw LocationMapError.invalidRoute
        }

        let scale = mapPreview.distance / cumulativeDistance
        let points = zip(retainedCoordinates, rawCumulativeDistances).map {
            coordinate, rawDistance in
            RoutePoint(
                coordinate: RouteCoordinate(
                    latitude: coordinate.latitude,
                    longitude: coordinate.longitude
                ),
                cumulativeDistance: rawDistance * scale
            )
        }
        try self.init(points: points)
    }
}

private struct AccessibilityIdentifierMarker: NSViewRepresentable {
    let identifier: String

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        view.setAccessibilityIdentifier(identifier)
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        nsView.setAccessibilityIdentifier(identifier)
    }
}

private struct FavoriteToggleAccessibilityView: NSViewRepresentable {
    let title: String

    func makeNSView(context: Context) -> NSView {
        let view = NSButton()
        view.title = title
        view.isBordered = false
        view.isEnabled = false
        view.alphaValue = 0
        view.setAccessibilityElement(true)
        return view
    }

    func updateNSView(_ view: NSView, context: Context) {
        guard let button = view as? NSButton else { return }
        button.title = title
    }
}

#if DEBUG
final class TestingActionButton: NSButton {
    override var intrinsicContentSize: NSSize {
        .zero
    }

    override var acceptsFirstResponder: Bool {
        false
    }
}

final class TestingLayoutRegionView: NSView {
    override var intrinsicContentSize: NSSize {
        .zero
    }

    override var acceptsFirstResponder: Bool {
        false
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }
}

private struct TestingLayoutRegionMarker: NSViewRepresentable {
    let identifier: String

    func makeNSView(context: Context) -> TestingLayoutRegionView {
        let view = TestingLayoutRegionView()
        view.setAccessibilityElement(false)
        view.setAccessibilityIdentifier(identifier)
        return view
    }

    func updateNSView(
        _ view: TestingLayoutRegionView,
        context: Context
    ) {
        view.setAccessibilityIdentifier(identifier)
    }
}

private struct TestingActionMarker: NSViewRepresentable {
    let identifier: String
    let isEnabled: Bool
    var isOn: Bool?
    let action: () -> Void

    init(
        identifier: String,
        isEnabled: Bool,
        isOn: Bool? = nil,
        action: @escaping () -> Void
    ) {
        self.identifier = identifier
        self.isEnabled = isEnabled
        self.isOn = isOn
        self.action = action
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(action: action)
    }

    func makeNSView(context: Context) -> TestingActionButton {
        let button = TestingActionButton()
        button.title = ""
        button.isBordered = false
        button.focusRingType = .none
        button.alphaValue = 0
        button.refusesFirstResponder = true
        button.setAccessibilityElement(false)
        button.target = context.coordinator
        button.action = #selector(Coordinator.performAction)
        return button
    }

    func updateNSView(
        _ button: TestingActionButton,
        context: Context
    ) {
        context.coordinator.action = action
        button.setAccessibilityIdentifier(identifier)
        button.isEnabled = isEnabled
        button.state = isOn == true ? .on : .off
    }

    final class Coordinator: NSObject {
        var action: () -> Void

        init(action: @escaping () -> Void) {
            self.action = action
        }

        @objc
        func performAction() {
            action()
        }
    }
}
#endif

@MainActor
final class LocationMapCameraEffects {
    private var appliedPreviewIdentity: MapSearchGeneration?
    private var appliedRouteCameraIdentity: RouteRequestGeneration?
    private var appliedMacCenterGeneration: DeviceSessionGeneration?
    private var appliedMacRecenterGeneration: MacRecenterGeneration?
    private var isApplyingProgrammaticCamera = false

    @discardableResult
    func applyPreview(
        _ intent: MapPreviewCameraIntent,
        update: () -> Void
    ) -> Bool {
        guard intent.identity != appliedPreviewIdentity else {
            return false
        }
        appliedPreviewIdentity = intent.identity
        applyProgrammatic(update)
        return true
    }

    func consumePreview(_ identity: MapSearchGeneration) {
        appliedPreviewIdentity = identity
    }

    @discardableResult
    func applyRoute(
        _ identity: RouteRequestGeneration,
        update: () -> Void
    ) -> Bool {
        guard identity != appliedRouteCameraIdentity else {
            return false
        }
        appliedRouteCameraIdentity = identity
        applyProgrammatic(update)
        return true
    }

    func applyMacCenter(
        _ generation: DeviceSessionGeneration,
        update: () -> Void
    ) {
        guard generation != appliedMacCenterGeneration else {
            return
        }
        appliedMacCenterGeneration = generation
        applyProgrammatic(update)
    }

    func applyMacRecenter(
        _ generation: MacRecenterGeneration,
        update: () -> Void
    ) {
        guard generation != appliedMacRecenterGeneration else {
            return
        }
        appliedMacRecenterGeneration = generation
        applyProgrammatic(update)
    }

    func regionWillChange(
        hasActiveGesture: Bool,
        onManualCameraInteraction: () -> Void
    ) {
        guard hasActiveGesture, !isApplyingProgrammaticCamera else {
            return
        }
        onManualCameraInteraction()
    }

    private func applyProgrammatic(_ update: () -> Void) {
        isApplyingProgrammaticCamera = true
        defer {
            isApplyingProgrammaticCamera = false
        }
        update()
    }
}

private struct ObservedSimulationMapCanvas: View {
    @ObservedObject var simulationStore: SimulationStore
    let preview: MapSearchPlace?
    let previewCameraIntent: MapPreviewCameraIntent?
    let endpointA: MapSearchPlace?
    let endpointB: MapSearchPlace?
    let route: [MapCoordinate]?
    let routeCameraIdentity: RouteRequestGeneration?
    let macLocation: MapCoordinate?
    let macInitialCenterIntent: MacInitialCenterIntent?
    let macRecenterIntent: MacRecenterIntent?
    let language: AppLanguage
    let onCoordinateSelected: (MapCoordinate) -> Void
    let onManualCameraInteraction: () -> Void

    var body: some View {
        LocationMapCanvas(
            preview: preview,
            previewCameraIntent: previewCameraIntent,
            endpointA: endpointA,
            endpointB: endpointB,
            route: route,
            routeCameraIdentity: routeCameraIdentity,
            macLocation: macLocation,
            macInitialCenterIntent: macInitialCenterIntent,
            macRecenterIntent: macRecenterIntent,
            confirmedRouteMarkerCoordinate: mapCoordinate(
                from: simulationStore.confirmedRouteMarkerCoordinate
            ),
            language: language,
            onCoordinateSelected: onCoordinateSelected,
            onManualCameraInteraction: onManualCameraInteraction
        )
    }

    private func mapCoordinate(
        from coordinate: RouteCoordinate?
    ) -> MapCoordinate? {
        guard let coordinate else {
            return nil
        }
        return try? MapCoordinate(
            latitude: coordinate.latitude,
            longitude: coordinate.longitude
        )
    }
}

struct LocationMapCanvas: NSViewRepresentable {
    let preview: MapSearchPlace?
    let previewCameraIntent: MapPreviewCameraIntent?
    let endpointA: MapSearchPlace?
    let endpointB: MapSearchPlace?
    let route: [MapCoordinate]?
    let routeCameraIdentity: RouteRequestGeneration?
    let macLocation: MapCoordinate?
    let macInitialCenterIntent: MacInitialCenterIntent?
    let macRecenterIntent: MacRecenterIntent?
    let confirmedRouteMarkerCoordinate: MapCoordinate?
    let language: AppLanguage
    let onCoordinateSelected: (MapCoordinate) -> Void
    let onManualCameraInteraction: () -> Void

    init(
        preview: MapSearchPlace?,
        previewCameraIntent: MapPreviewCameraIntent?,
        endpointA: MapSearchPlace?,
        endpointB: MapSearchPlace?,
        route: [MapCoordinate]?,
        routeCameraIdentity: RouteRequestGeneration?,
        macLocation: MapCoordinate?,
        macInitialCenterIntent: MacInitialCenterIntent?,
        macRecenterIntent: MacRecenterIntent? = nil,
        confirmedRouteMarkerCoordinate: MapCoordinate?,
        language: AppLanguage = .defaultLanguage,
        onCoordinateSelected: @escaping (MapCoordinate) -> Void,
        onManualCameraInteraction: @escaping () -> Void
    ) {
        self.preview = preview
        self.previewCameraIntent = previewCameraIntent
        self.endpointA = endpointA
        self.endpointB = endpointB
        self.route = route
        self.routeCameraIdentity = routeCameraIdentity
        self.macLocation = macLocation
        self.macInitialCenterIntent = macInitialCenterIntent
        self.macRecenterIntent = macRecenterIntent
        self.confirmedRouteMarkerCoordinate = confirmedRouteMarkerCoordinate
        self.language = language
        self.onCoordinateSelected = onCoordinateSelected
        self.onManualCameraInteraction = onManualCameraInteraction
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(
            onCoordinateSelected: onCoordinateSelected,
            onManualCameraInteraction: onManualCameraInteraction
        )
    }

    func makeNSView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        context.coordinator.mapView = mapView
        let click = NSClickGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.mapClicked(_:))
        )
        mapView.addGestureRecognizer(click)
        return mapView
    }

    func updateNSView(_ mapView: MKMapView, context: Context) {
        context.coordinator.onCoordinateSelected = onCoordinateSelected
        context.coordinator.onManualCameraInteraction =
            onManualCameraInteraction
        context.coordinator.language = language
        context.coordinator.update(
            preview: preview,
            previewCameraIntent: previewCameraIntent,
            endpointA: endpointA,
            endpointB: endpointB,
            route: route,
            routeCameraIdentity: routeCameraIdentity,
            macLocation: macLocation,
            macInitialCenterIntent: macInitialCenterIntent,
            macRecenterIntent: macRecenterIntent,
            confirmedRouteMarkerCoordinate: confirmedRouteMarkerCoordinate,
            language: language
        )
    }

    final class Coordinator: NSObject, MKMapViewDelegate {
        private enum AnnotationRole: Hashable {
            case preview
            case endpointA
            case endpointB
            case macLocation
            case confirmedRouteMarker
        }

        weak var mapView: MKMapView?
        var onCoordinateSelected: (MapCoordinate) -> Void
        var onManualCameraInteraction: () -> Void
        var language: AppLanguage = .defaultLanguage
        private let cameraEffects = LocationMapCameraEffects()
        private var annotations: [AnnotationRole: MKPointAnnotation] = [:]
        private var routeCoordinates: [MapCoordinate]?
        private var routeOverlay: MKPolyline?

        init(
            onCoordinateSelected: @escaping (MapCoordinate) -> Void,
            onManualCameraInteraction: @escaping () -> Void
        ) {
            self.onCoordinateSelected = onCoordinateSelected
            self.onManualCameraInteraction = onManualCameraInteraction
        }

        @objc
        func mapClicked(_ recognizer: NSClickGestureRecognizer) {
            guard recognizer.state == .ended, let mapView else {
                return
            }
            let point = recognizer.location(in: mapView)
            let coordinate = mapView.convert(
                point,
                toCoordinateFrom: mapView
            )
            guard let mapCoordinate = try? MapCoordinate(
                latitude: coordinate.latitude,
                longitude: coordinate.longitude
            ) else {
                return
            }
            onCoordinateSelected(mapCoordinate)
        }

        func update(
            preview: MapSearchPlace?,
            previewCameraIntent: MapPreviewCameraIntent?,
            endpointA: MapSearchPlace?,
            endpointB: MapSearchPlace?,
            route: [MapCoordinate]?,
            routeCameraIdentity: RouteRequestGeneration?,
            macLocation: MapCoordinate?,
            macInitialCenterIntent: MacInitialCenterIntent?,
            macRecenterIntent: MacRecenterIntent? = nil,
            confirmedRouteMarkerCoordinate: MapCoordinate?,
            language: AppLanguage = .defaultLanguage
        ) {
            guard let mapView else {
                return
            }
            syncAnnotation(
                role: .preview,
                coordinate: preview?.coordinate,
                title: L10n.text(.previewAnnotation, language: language),
                subtitle: preview?.address
            )
            syncAnnotation(
                role: .endpointA,
                coordinate: endpointA?.coordinate,
                title: "A",
                subtitle: endpointA?.address
            )
            syncAnnotation(
                role: .endpointB,
                coordinate: endpointB?.coordinate,
                title: "B",
                subtitle: endpointB?.address
            )
            syncAnnotation(
                role: .macLocation,
                coordinate: macLocation,
                title: L10n.text(.macCurrentLocation, language: language)
            )
            syncAnnotation(
                role: .confirmedRouteMarker,
                coordinate: confirmedRouteMarkerCoordinate,
                title: L10n.text(.simulatedIPhoneLocation, language: language)
            )
            syncRoute(route)

            let didApplyRoute: Bool
            if let routeOverlay, let routeCameraIdentity {
                didApplyRoute = cameraEffects.applyRoute(routeCameraIdentity) {
                    mapView.setVisibleMapRect(
                        routeOverlay.boundingMapRect,
                        edgePadding: NSEdgeInsets(
                            top: 40,
                            left: 40,
                            bottom: 40,
                            right: 40
                        ),
                        animated: true
                    )
                }
            } else {
                didApplyRoute = false
            }

            let didApplyPreview: Bool
            if didApplyRoute {
                if let previewCameraIntent {
                    cameraEffects.consumePreview(previewCameraIntent.identity)
                }
                didApplyPreview = false
            } else if let previewCameraIntent {
                didApplyPreview = cameraEffects.applyPreview(
                    previewCameraIntent
                ) {
                    centerMap(on: previewCameraIntent.coordinate)
                }
            } else {
                didApplyPreview = false
            }

            if !didApplyRoute,
               !didApplyPreview,
               preview == nil,
               let macInitialCenterIntent
            {
                cameraEffects.applyMacCenter(
                    macInitialCenterIntent.generation
                ) {
                    centerMap(on: macInitialCenterIntent.coordinate)
                }
            }

            if let macRecenterIntent {
                cameraEffects.applyMacRecenter(
                    macRecenterIntent.generation
                ) {
                    centerMap(on: macRecenterIntent.coordinate)
                }
            }
        }

        func mapView(
            _ mapView: MKMapView,
            regionWillChangeAnimated animated: Bool
        ) {
            let hasActiveGesture = mapView.gestureRecognizers.contains {
                $0.state == .began || $0.state == .changed
            }
            cameraEffects.regionWillChange(
                hasActiveGesture: hasActiveGesture,
                onManualCameraInteraction: onManualCameraInteraction
            )
        }

        func mapView(
            _ mapView: MKMapView,
            rendererFor overlay: MKOverlay
        ) -> MKOverlayRenderer {
            guard let polyline = overlay as? MKPolyline else {
                return MKOverlayRenderer(overlay: overlay)
            }
            let renderer = MKPolylineRenderer(polyline: polyline)
            renderer.strokeColor = .systemBlue
            renderer.lineWidth = 5
            return renderer
        }

        func mapView(
            _ mapView: MKMapView,
            viewFor annotation: MKAnnotation
        ) -> MKAnnotationView? {
            let role = annotations.first {
                $0.value === annotation
            }?.key
            let isConfirmedRouteMarker = role == .confirmedRouteMarker
            let identifier = isConfirmedRouteMarker
                ? "iphone-route-marker"
                : "location-marker"
            let view = mapView.dequeueReusableAnnotationView(
                withIdentifier: identifier
            ) as? MKMarkerAnnotationView
                ?? MKMarkerAnnotationView(
                    annotation: annotation,
                    reuseIdentifier: identifier
                )
            view.annotation = annotation
            view.canShowCallout = true
            let avoidsCollision =
                role == .endpointA
                || role == .endpointB
                || role == .confirmedRouteMarker
            view.displayPriority = avoidsCollision ? .required : .defaultLow
            view.collisionMode = avoidsCollision ? .none : .rectangle
            if isConfirmedRouteMarker {
                view.glyphImage = NSImage(
                    systemSymbolName: "iphone",
                    accessibilityDescription: L10n.text(
                        .simulatedIPhoneLocation,
                        language: language
                    )
                )
                view.markerTintColor = .systemPurple
                view.setAccessibilityIdentifier("iphone-route-marker")
            }
            return view
        }

        private func syncAnnotation(
            role: AnnotationRole,
            coordinate: MapCoordinate?,
            title: String,
            subtitle: String? = nil
        ) {
            guard let mapView else {
                return
            }
            guard let coordinate else {
                if let annotation = annotations.removeValue(forKey: role) {
                    mapView.removeAnnotation(annotation)
                }
                return
            }

            let annotation = annotations[role] ?? MKPointAnnotation()
            annotation.coordinate = CLLocationCoordinate2D(
                latitude: coordinate.latitude,
                longitude: coordinate.longitude
            )
            annotation.title = title
            annotation.subtitle = subtitle
            if annotations[role] == nil {
                annotations[role] = annotation
                mapView.addAnnotation(annotation)
            }
        }

        private func syncRoute(_ route: [MapCoordinate]?) {
            guard let mapView else {
                return
            }
            let validRoute = route.flatMap { $0.count >= 2 ? $0 : nil }
            guard validRoute != routeCoordinates else {
                return
            }

            if let routeOverlay {
                mapView.removeOverlay(routeOverlay)
            }
            routeCoordinates = validRoute
            routeOverlay = nil

            guard let validRoute else {
                return
            }
            var coordinates = validRoute.map {
                CLLocationCoordinate2D(
                    latitude: $0.latitude,
                    longitude: $0.longitude
                )
            }
            let polyline = MKPolyline(
                coordinates: &coordinates,
                count: coordinates.count
            )
            routeOverlay = polyline
            mapView.addOverlay(polyline)
        }

        private func centerMap(on coordinate: MapCoordinate) {
            mapView?.setRegion(
                MKCoordinateRegion(
                    center: CLLocationCoordinate2D(
                        latitude: coordinate.latitude,
                        longitude: coordinate.longitude
                    ),
                    latitudinalMeters: 1_500,
                    longitudinalMeters: 1_500
                ),
                animated: true
            )
        }
    }
}

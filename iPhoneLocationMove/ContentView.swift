import SwiftUI

struct ContentView: View {
    @ObservedObject var appDelegate: AppDelegate
    @ObservedObject private var languageStore = AppLanguageStore.shared

    var body: some View {
        VStack(spacing: 0) {
            if let setupStore = appDelegate.setupStore {
                LocationWorkspaceView(
                    store: setupStore,
                    macLocationCoordinator:
                        appDelegate.macLocationCoordinator,
                    favoritesStore: appDelegate.favoritesStore
                )
            } else if let configurationFailure = appDelegate.configurationFailure {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 36))
                    Text(L10n.text(.configurationFailure))
                        .font(.title2)
                    Text(configurationFailure)
                        .foregroundStyle(.secondary)
                }
            } else {
                ProgressView(L10n.text(.checkingDeviceSupport))
            }
        }
        .frame(minWidth: 900, minHeight: 620)
        .toolbar {
            ToolbarItem(placement: .automatic) {
                LanguageMenu(languageStore: languageStore)
            }
        }
        .alert(
            appDelegate.riskNoticeStore.firstUseNotice.title,
            isPresented: Binding(
                get: {
                    appDelegate.riskNoticeStore
                        .needsFirstUseAcknowledgement
                },
                set: { _ in }
            )
        ) {
            Button(
                appDelegate.riskNoticeStore
                    .firstUseNotice.confirmationTitle
            ) {
                appDelegate.riskNoticeStore.acknowledgeFirstUse()
            }
        } message: {
            Text(appDelegate.riskNoticeStore.firstUseNotice.message)
        }
    }
}

struct LocationWorkspaceView: View {
    @ObservedObject var store: DeviceSetupStore
    @ObservedObject var macLocationCoordinator: MacLocationCoordinator
    @ObservedObject var favoritesStore: FavoritesStore = FavoritesStore(defaults: .standard)

    var body: some View {
        VStack(spacing: 0) {
            DeviceSetupView(store: store)
            Divider()
            LocationMapView(
                simulationStore: store.simulationStore,
                macLocationCoordinator: macLocationCoordinator,
                favoritesStore: favoritesStore
            )
        }
        .onAppear {
            macLocationCoordinator.updateReadyGeneration(readyGeneration)
        }
        .onChange(of: readyGeneration) { generation in
            macLocationCoordinator.updateReadyGeneration(generation)
        }
    }

    private var readyGeneration: DeviceSessionGeneration? {
        guard case .ready(let session) = store.state else {
            return nil
        }
        return session.generation
    }
}

private struct DeviceSetupView: View {
    @ObservedObject var store: DeviceSetupStore

    var body: some View {
        HStack(spacing: 12) {
            status
            Spacer()
            actions
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.bar)
    }

    @ViewBuilder
    private var status: some View {
        switch store.state {
        case .idle, .checkingRuntime:
            ProgressView(L10n.text(.checkingPymobiledevice3))
        case .runtimeInstallationRequired:
            Label(L10n.text(.runtimeInstallationRequired), systemImage: "shippingbox")
        case .pythonUnavailable(let version):
            Label(
                L10n.format(.pythonUnavailable, version),
                systemImage: "exclamationmark.triangle"
            )
        case .incompleteRuntime:
            Label(L10n.text(.runtimeIncomplete), systemImage: "arrow.clockwise")
        case .installing(let progress):
            ProgressView(installProgressText(progress))
        case .helperApprovalRequired:
            Label(L10n.text(.helperApprovalRequired), systemImage: "lock.shield")
        case .helperRequiresSystemApproval:
            Label(
                L10n.text(.helperRequiresSystemApproval),
                systemImage: "gearshape"
            )
        case .discoveringDevices:
            ProgressView(L10n.text(.discoveringDevices))
        case .noUSBDevice:
            Label(
                L10n.text(.noUSBDevice),
                systemImage: "cable.connector"
            )
        case .selectionRequired(let devices):
            Label(
                L10n.format(.selectionRequired, devices.count),
                systemImage: "iphone.gen3"
            )
        case .unsupported(let device):
            Label(
                L10n.format(.unsupportedDevice, device.name, versionText(device)),
                systemImage: "iphone.slash"
            )
        case .preparing(let device):
            ProgressView(
                device.map { L10n.format(.preparingDevice, $0.name) }
                    ?? L10n.text(.preparingDevice)
            )
        case .ready(let session):
            Label(
                L10n.format(
                    .readyDevice,
                    session.device.name,
                    versionText(session.device)
                ),
                systemImage: "checkmark.circle.fill"
            )
            .foregroundStyle(.green)
        case .failed(let failure):
            Label(failureText(failure), systemImage: "exclamationmark.triangle")
                .foregroundStyle(.red)
        case .configurationFailure(let message):
            Label(message, systemImage: "exclamationmark.triangle")
                .foregroundStyle(.red)
        }
    }

    @ViewBuilder
    private var actions: some View {
        switch store.state {
        case .runtimeInstallationRequired, .incompleteRuntime:
            Button(L10n.text(.installDeviceSupport)) {
                Task { await store.installRuntime() }
            }
        case .installing:
            Button(L10n.text(.cancel)) {
                Task { await store.cancelRuntimeInstallation() }
            }
        case .helperApprovalRequired:
            Button(L10n.text(.approveHelper)) {
                Task { await store.requestHelperApproval() }
            }
        case .helperRequiresSystemApproval, .noUSBDevice,
             .failed, .configurationFailure:
            Button(L10n.text(.retry)) {
                Task { await store.retry() }
            }
        case .selectionRequired(let devices):
            Menu(L10n.text(.chooseIPhone)) {
                ForEach(devices, id: \.id) { device in
                    Button(
                        L10n.format(
                            .selectIPhone,
                            device.name,
                            versionText(device)
                        )
                    ) {
                        Task { await store.selectDevice(device.id) }
                    }
                }
            }
        default:
            EmptyView()
        }
    }

    private func installProgressText(
        _ progress: RuntimeInstallProgress
    ) -> String {
        switch progress {
        case .checkingPython:
            L10n.text(.checkingPython)
        case .creatingEnvironment:
            L10n.text(.creatingEnvironment)
        case .installingPinnedPackage:
            L10n.text(.installingPinnedPackage)
        case .verifyingCapabilities:
            L10n.text(.verifyingCapabilities)
        }
    }

    private func versionText(_ device: USBDevice) -> String {
        let version = device.operatingSystemVersion
        return "\(version.majorVersion).\(version.minorVersion).\(version.patchVersion)"
    }

    private func failureText(_ failure: DeviceLocationError) -> String {
        let presentation = DeviceFailurePresentation.make(for: failure)
        return "\(presentation.title)：\(presentation.message)"
    }
}

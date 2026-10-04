import Foundation

struct DeviceCoordinate: Equatable, Hashable, Sendable {
    let latitude: Double
    let longitude: Double

    init(latitude: Double, longitude: Double) throws {
        guard latitude.isFinite,
              (-90 ... 90).contains(latitude),
              longitude.isFinite,
              (-180 ... 180).contains(longitude)
        else {
            throw DeviceLocationError.invalidCoordinate
        }
        self.latitude = latitude
        self.longitude = longitude
    }
}

struct SimulationSessionID: RawRepresentable, Equatable, Hashable, Sendable {
    let rawValue: UUID

    init() {
        rawValue = UUID()
    }

    init(rawValue: UUID) {
        self.rawValue = rawValue
    }
}

struct DeviceSessionGeneration: RawRepresentable, Comparable, Hashable, Sendable {
    let rawValue: UInt64

    func advanced() throws -> Self {
        guard rawValue < UInt64.max else {
            throw DeviceLocationError.identityExhausted
        }
        return Self(rawValue: rawValue + 1)
    }

    static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

struct DeviceTransportGeneration: RawRepresentable, Comparable, Hashable, Sendable {
    let rawValue: UInt64

    func advanced() throws -> Self {
        guard rawValue < UInt64.max else {
            throw DeviceLocationError.identityExhausted
        }
        return Self(rawValue: rawValue + 1)
    }

    static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

struct RecoveryOwnershipEpoch: RawRepresentable, Comparable, Hashable, Sendable {
    let rawValue: UInt64

    func advanced() throws -> Self {
        guard rawValue < UInt64.max else {
            throw DeviceLocationError.identityExhausted
        }
        return Self(rawValue: rawValue + 1)
    }

    static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

struct DeviceDVTSessionHandle: RawRepresentable, Equatable, Hashable, Sendable {
    let rawValue: UUID

    init() {
        rawValue = UUID()
    }

    init(rawValue: UUID) {
        self.rawValue = rawValue
    }
}

struct CandidateTransportIdentity: Equatable, Hashable, Sendable {
    let generation: DeviceTransportGeneration
    let leaseID: DeviceTunnelLeaseID
    let dvtHandle: DeviceDVTSessionHandle
}

enum DeviceBackendFailureCode: String, Equatable, Hashable, Sendable {
    case transportClosed = "transport-closed"
    case backendFailure = "backend-failure"
}

struct DeviceBackendFailure: Equatable, Hashable, Sendable {
    let code: DeviceBackendFailureCode
    let exceptionType: String
    let errorNumber: Int?
}

enum DeviceTunnelLeaseState: String, Equatable, Hashable, Sendable {
    case running
    case exited
}

struct DeviceTunnelDiagnostics: Equatable, Hashable, Sendable {
    let terminationStatus: Int32?
    let stderrTail: String
    let stderrByteCount: Int
}

struct DeviceTunnelStatus: Equatable, Sendable {
    let leaseID: DeviceTunnelLeaseID
    let deviceID: DeviceID
    let endpoint: DeviceTunnelEndpoint
    let state: DeviceTunnelLeaseState
    let diagnostics: DeviceTunnelDiagnostics
}

struct DeviceRequestID: RawRepresentable, Equatable, Hashable, Sendable {
    let rawValue: UUID

    init() {
        rawValue = UUID()
    }

    init(rawValue: UUID) {
        self.rawValue = rawValue
    }
}

struct DeviceID: Equatable, Hashable, Sendable {
    let rawValue: String

    init(_ rawValue: String) throws {
        let isValid = (1 ... 128).contains(rawValue.utf8.count)
            && rawValue.unicodeScalars.allSatisfy {
                CharacterSet.alphanumerics.contains($0) || $0 == "-"
            }
        guard isValid else {
            throw DeviceLocationError.invalidDeviceID
        }
        self.rawValue = rawValue
    }
}

enum DeviceSupport: Equatable, Sendable {
    case supported
    case unsupported(minimumMajorVersion: Int)
}

struct USBDevice: Equatable, Sendable {
    static let minimumSupportedMajorVersion = 17

    let id: DeviceID
    let name: String
    let operatingSystemVersion: OperatingSystemVersion
    let support: DeviceSupport

    init(
        id: DeviceID,
        name: String,
        operatingSystemVersion: OperatingSystemVersion
    ) throws {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            throw DeviceLocationError.invalidDeviceName
        }
        self.id = id
        self.name = trimmedName
        self.operatingSystemVersion = operatingSystemVersion
        support = operatingSystemVersion.majorVersion >= Self.minimumSupportedMajorVersion
            ? .supported
            : .unsupported(minimumMajorVersion: Self.minimumSupportedMajorVersion)
    }

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.id == rhs.id
            && lhs.name == rhs.name
            && lhs.operatingSystemVersion.majorVersion
                == rhs.operatingSystemVersion.majorVersion
            && lhs.operatingSystemVersion.minorVersion
                == rhs.operatingSystemVersion.minorVersion
            && lhs.operatingSystemVersion.patchVersion
                == rhs.operatingSystemVersion.patchVersion
            && lhs.support == rhs.support
    }
}

enum DevicePrerequisiteStage: String, CaseIterable, Equatable, Sendable {
    case runtime
    case usbSelection
    case trust
    case developerMode
    case developerDiskImage
    case tunnel
    case dvtHelper
}

enum PositionKnowledge: Equatable, Sendable {
    case known
    case unknown
}

enum InterruptionReason: Equatable, Sendable {
    case deviceMutationFailed
    case timeout
    case transportFailure
    case usbDisconnected
    case authorizationDenied
    case helperExited
    case tunnelEnded
}

struct DeviceInterruption: Equatable, Sendable {
    let reason: InterruptionReason
    let positionKnowledge: PositionKnowledge
}

struct PreparedDeviceSession: Equatable, Sendable {
    let device: USBDevice
    let generation: DeviceSessionGeneration
}

enum DeviceSessionState: Equatable, Sendable {
    case disconnected
    case discovering
    case selectionRequired([USBDevice])
    case preparing(device: USBDevice, stage: DevicePrerequisiteStage)
    case ready(PreparedDeviceSession)
    case interrupted(session: PreparedDeviceSession, interruption: DeviceInterruption)
    case cleanupPending(session: PreparedDeviceSession, failure: DeviceLocationError)
}

struct DeviceMutationContext: Equatable, Sendable {
    let requestID: DeviceRequestID
    let simulationSessionID: SimulationSessionID
    let generation: DeviceSessionGeneration

    init(
        requestID: DeviceRequestID = DeviceRequestID(),
        simulationSessionID: SimulationSessionID,
        generation: DeviceSessionGeneration
    ) {
        self.requestID = requestID
        self.simulationSessionID = simulationSessionID
        self.generation = generation
    }
}

struct DeviceCleanupContext: Equatable, Sendable {
    let requestID: DeviceRequestID
    let generation: DeviceSessionGeneration

    init(
        requestID: DeviceRequestID = DeviceRequestID(),
        generation: DeviceSessionGeneration
    ) {
        self.requestID = requestID
        self.generation = generation
    }
}

enum DeviceLocationError: Error, Equatable, Hashable, Sendable {
    case invalidCoordinate
    case invalidDeviceID
    case invalidDeviceName
    case identityExhausted
    case noUSBDevice
    case selectionRequired
    case deviceNotFound
    case unsupportedDevice
    case prerequisiteFailed(stage: DevicePrerequisiteStage, message: String)
    case timeout
    case usbDisconnected
    case authorizationDenied
    case deviceLocked
    case transportClosed(DeviceBackendFailure)
    case transportFailure(String)
    case helperFailure(String)
    case tunnelFailure(String)
    case clearFailed(String)
    case positionUnknown
    case responseMismatch
    case staleGeneration
}

enum DeviceRecoveryAction: Equatable, Sendable {
    case retry
    case reconnectUSB
    case approveTrust
    case unlockDevice
    case enableDeveloperMode
    case prepareDeveloperDiskImage
    case approveHelper
    case retryClear
}

struct DeviceFailurePresentation: Equatable, Sendable {
    let title: String
    let message: String
    let recoveryTitle: String
    let recoveryAction: DeviceRecoveryAction

    static func make(
        for failure: DeviceLocationError
    ) -> DeviceFailurePresentation {
        switch failure {
        case .timeout:
            Self(
                title: L10n.text(.deviceReplyTimeout),
                message: L10n.text(.deviceReplyTimeoutMessage),
                recoveryTitle: L10n.text(.retry),
                recoveryAction: .retry
            )
        case .usbDisconnected:
            Self(
                title: L10n.text(.usbDisconnected),
                message: L10n.text(.usbDisconnectedMessage),
                recoveryTitle: L10n.text(.reconnectUSB),
                recoveryAction: .reconnectUSB
            )
        case .authorizationDenied:
            Self(
                title: L10n.text(.authorizationDenied),
                message: L10n.text(.authorizationDeniedMessage),
                recoveryTitle: L10n.text(.finishAuthorizationAndRetry),
                recoveryAction: .approveTrust
            )
        case .deviceLocked:
            Self(
                title: L10n.text(.deviceLocked),
                message: L10n.text(.deviceLockedMessage),
                recoveryTitle: L10n.text(.unlockAndRetry),
                recoveryAction: .unlockDevice
            )
        case let .prerequisiteFailed(stage, message):
            prerequisitePresentation(stage: stage, detail: message)
        case let .tunnelFailure(detail):
            Self(
                title: L10n.text(.usbTunnelFailure),
                message: detail,
                recoveryTitle: L10n.text(.approveAgainAndRetry),
                recoveryAction: .approveHelper
            )
        case let .helperFailure(detail):
            Self(
                title: L10n.text(.dvtHelperFailure),
                message: L10n.format(.helperFailureMessage, detail),
                recoveryTitle: L10n.text(.prepareAgain),
                recoveryAction: .retry
            )
        case let .clearFailed(detail):
            Self(
                title: L10n.text(.clearLocationFailure),
                message: L10n.format(.clearFailureMessage, detail),
                recoveryTitle: L10n.text(.retryClear),
                recoveryAction: .retryClear
            )
        case .transportClosed:
            Self(
                title: L10n.text(.deviceConnectionInterrupted),
                message: L10n.text(.deviceConnectionInterruptedMessage),
                recoveryTitle: L10n.text(.retry),
                recoveryAction: .retry
            )
        case let .transportFailure(detail):
            Self(
                title: L10n.text(.deviceConnectionFailure),
                message: detail,
                recoveryTitle: L10n.text(.retry),
                recoveryAction: .retry
            )
        default:
            Self(
                title: L10n.text(.deviceNotReady),
                message: String(describing: failure),
                recoveryTitle: L10n.text(.retry),
                recoveryAction: .retry
            )
        }
    }

    private static func prerequisitePresentation(
        stage: DevicePrerequisiteStage,
        detail: String
    ) -> Self {
        switch stage {
        case .trust:
            Self(
                title: L10n.text(.iPhoneTrustRequired),
                message: L10n.format(.trustMessage, detail),
                recoveryTitle: L10n.text(.finishTrustAndRetry),
                recoveryAction: .approveTrust
            )
        case .developerMode:
            Self(
                title: L10n.text(.developerModeNotReady),
                message: L10n.format(.developerModeMessage, detail),
                recoveryTitle: L10n.text(.finishSetupAndRetry),
                recoveryAction: .enableDeveloperMode
            )
        case .developerDiskImage:
            Self(
                title: L10n.text(.developerDiskImageFailure),
                message: L10n.format(.developerDiskImageMessage, detail),
                recoveryTitle: L10n.text(.prepareDDIAgain),
                recoveryAction: .prepareDeveloperDiskImage
            )
        case .tunnel:
            Self(
                title: L10n.text(.tunnelPrerequisiteFailure),
                message: detail,
                recoveryTitle: L10n.text(.approveHelper),
                recoveryAction: .approveHelper
            )
        default:
            Self(
                title: L10n.text(.devicePrerequisiteFailure),
                message: L10n.format(
                    .prerequisiteFailureMessage,
                    stage.rawValue,
                    detail
                ),
                recoveryTitle: L10n.text(.retry),
                recoveryAction: .retry
            )
        }
    }
}

extension DeviceLocationError: LocalizedError {
    var errorDescription: String? {
        DeviceFailurePresentation.make(for: self).message
    }
}

protocol DeviceLocationClient: Sendable {
    func discoverUSBDevices() async throws -> [USBDevice]
    func prepare(deviceID: DeviceID) async throws -> PreparedDeviceSession
    /// Rebuilds the session for a device that was observed as disconnected,
    /// under a new generation and only after a successful clear.
    func reconnect() async throws -> PreparedDeviceSession
    func setLocation(
        _ coordinate: DeviceCoordinate,
        context: DeviceMutationContext
    ) async throws
    func clearLocation(context: DeviceCleanupContext) async throws
    func shutdown(generation: DeviceSessionGeneration) async
}

struct RuntimeInstallation: Equatable, Sendable {
    enum Source: Equatable, Sendable {
        case existing
        case appManaged
    }

    let executableURL: URL
    let source: Source
}

enum RuntimeAvailability: Equatable, Sendable {
    case ready(RuntimeInstallation)
    case installationRequired(pythonURL: URL)
    case pythonUnavailable(minimumVersion: String)
    case incompleteManagedEnvironment
    case configurationFailure(RuntimeManagerFailure)
}

enum RuntimeInstallProgress: Equatable, Sendable {
    case checkingPython
    case creatingEnvironment
    case installingPinnedPackage
    case verifyingCapabilities
}

enum RuntimeInstallResult: Equatable, Sendable {
    case ready(RuntimeInstallation)
    case cancelled
    case pythonUnavailable(minimumVersion: String)
    case failed(RuntimeManagerFailure)
}

enum RuntimeInstallStep: String, Equatable, Hashable, Sendable {
    case createEnvironment
    case installPinnedPackage
    case verifyCapabilities
}

enum RuntimeManagerFailure: Error, Equatable, Hashable, Sendable {
    case installationInProgress
    case invalidLockManifest
    case unsafeApplicationSupportDirectory
    case commandFailed(step: RuntimeInstallStep, message: String)
    case processLaunchFailed(step: RuntimeInstallStep, message: String)
    case fileSystem(message: String)
}

import Combine
import Foundation
import SwiftUI

enum AppLanguage: String, CaseIterable, Identifiable, Sendable {
    case english = "en"
    case thai = "th"

    static let defaultLanguage: Self = .english
    static let defaultsKey = "appLanguage"

    var id: String { rawValue }

    var locale: Locale {
        Locale(identifier: rawValue)
    }

    var displayName: String {
        switch self {
        case .english:
            "English"
        case .thai:
            "ไทย"
        }
    }

    static var current: Self {
        guard let rawValue = UserDefaults.standard.string(forKey: defaultsKey),
              let language = Self(rawValue: rawValue)
        else {
            return defaultLanguage
        }
        return language
    }
}

@MainActor
final class AppLanguageStore: ObservableObject {
    static let shared = AppLanguageStore()

    @Published private(set) var language: AppLanguage
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        language = AppLanguage(
            rawValue: defaults.string(forKey: AppLanguage.defaultsKey) ?? ""
        ) ?? .defaultLanguage
    }

    func setLanguage(_ language: AppLanguage) {
        guard self.language != language else {
            return
        }
        defaults.set(language.rawValue, forKey: AppLanguage.defaultsKey)
        self.language = language
    }
}

struct LanguageMenu: View {
    @ObservedObject var languageStore: AppLanguageStore

    var body: some View {
        Menu {
            Picker(
                L10n.text(.language, language: languageStore.language),
                selection: Binding(
                    get: { languageStore.language },
                    set: { languageStore.setLanguage($0) }
                )
            ) {
                ForEach(AppLanguage.allCases) { language in
                    Text(language.displayName).tag(language)
                }
            }
        } label: {
            Label(
                L10n.text(.language, language: languageStore.language),
                systemImage: "globe"
            )
        }
        .accessibilityIdentifier("language-menu")
    }
}

enum L10n {
    enum Key: String {
        case language
        case configurationFailure
        case checkingDeviceSupport
        case checkingPymobiledevice3
        case runtimeInstallationRequired
        case pythonUnavailable
        case runtimeIncomplete
        case helperApprovalRequired
        case helperRequiresSystemApproval
        case discoveringDevices
        case noUSBDevice
        case selectionRequired
        case unsupportedDevice
        case preparingDevice
        case readyDevice
        case installDeviceSupport
        case cancel
        case approveHelper
        case retry
        case chooseIPhone
        case selectIPhone
        case checkingPython
        case creatingEnvironment
        case installingPinnedPackage
        case verifyingCapabilities
        case mapAndRoute
        case recenterMac
        case resetStopTitle
        case resetStopMessage
        case resetSettingsTitle
        case resetSettingsMessage
        case reset
        case searchPlaceholder
        case search
        case clear
        case searchResults
        case unnamedPlace
        case currentPreview
        case mapPoint
        case previewNotice
        case setA
        case setB
        case favorites
        case name
        case rename
        case delete
        case favoriteRemove
        case favoriteAdd
        case walkingEndpoints
        case createWalkingRoute
        case speed
        case speedValue
        case gettingWalkingRoute
        case routeReady
        case noWalkingRoute
        case routeCancelled
        case transientRouteFailure
        case notSelected
        case searchFailed
        case addressLookupFailed
        case durationMinutes
        case distanceKilometers
        case distanceMeters
        case iPhoneLocation
        case setLocation
        case roundTrip
        case startWalkingRoute
        case deviceReadyForLocationControl
        case stopSimulation
        case pause
        case resume
        case notSimulating
        case settingLocation
        case startingRoute
        case preparingDeviceAgain
        case replacingSimulation
        case pointLocation
        case confirmedProgress
        case simulationInterrupted
        case phoneLocationUnknown
        case phoneLocationKnown
        case clearFailedNotRestored
        case clearingSimulation
        case confirmStopClearTitle
        case confirmation
        case stopAndClear
        case routeNotStarted
        case routePreview
        case routeMoving
        case confirmingPauseLocation
        case routePaused
        case oneWayCompleted
        case routeInterrupted
        case stoppingRoute
        case previewAnnotation
        case macCurrentLocation
        case simulatedIPhoneLocation
        case failureSummary
        case invalidCoordinate
        case invalidSearchQuery
        case invalidSpeed
        case invalidRoute
        case missingPreview
        case missingEndpoints
        case endpointsMustDiffer
        case staleSearchSelection
        case routePreviewUnavailable
        case macLocationUnavailable
        case identityExhausted
        case macLocationPermission
        case macLocationServicesDisabled
        case macLocationInvalid
        case macLocationRequestInProgress
        case macLocationCancelled
        case deviceReplyTimeout
        case deviceReplyTimeoutMessage
        case usbDisconnected
        case usbDisconnectedMessage
        case reconnectUSB
        case finishAuthorizationAndRetry
        case authorizationDeniedMessage
        case unlockAndRetry
        case deviceLockedMessage
        case approveAgainAndRetry
        case prepareAgain
        case helperFailureMessage
        case retryClear
        case clearFailureMessage
        case deviceConnectionInterruptedMessage
        case finishTrustAndRetry
        case trustMessage
        case finishSetupAndRetry
        case developerModeMessage
        case prepareDDIAgain
        case developerDiskImageMessage
        case prerequisiteFailureMessage
        case authorizationDenied
        case deviceLocked
        case usbTunnelFailure
        case dvtHelperFailure
        case clearLocationFailure
        case deviceConnectionInterrupted
        case deviceConnectionFailure
        case deviceNotReady
        case iPhoneTrustRequired
        case developerModeNotReady
        case developerDiskImageFailure
        case tunnelPrerequisiteFailure
        case devicePrerequisiteFailure
        case helperNotApproved
        case helperInstalledNotRegistered
        case authorizationSessionFailure
        case administratorAuthorizationFailure
        case smJobBlessFailure
        case firstUseRiskTitle
        case firstUseRiskMessage
        case firstUseRiskConfirmation
        case simulationRiskTitle
        case simulationRiskMessage
        case simulationRiskConfirmation
        case quitSimulationTitle
        case quitSimulationMessage
        case quitSimulationConfirm
        case quitCancel
        case cleanupFailureTitle
        case cleanupFailureMessage
        case forceQuit
        case forceQuitTitle
        case forceQuitMessage
        case forceQuitConfirm
        case openLocationControl
    }

    static func text(
        _ key: Key,
        language: AppLanguage = .current
    ) -> String {
        let table = language == .english ? english : thai
        return table[key] ?? key.rawValue
    }

    static func format(
        _ key: Key,
        language: AppLanguage = .current,
        _ arguments: CVarArg...
    ) -> String {
        String(
            format: text(key, language: language),
            locale: language.locale,
            arguments: arguments
        )
    }

    private static let english: [Key: String] = [
        .language: "Language",
        .configurationFailure: "Unable to create the device support environment",
        .checkingDeviceSupport: "Checking the device support environment…",
        .checkingPymobiledevice3: "Checking pymobiledevice3…",
        .runtimeInstallationRequired: "App-specific device support must be installed",
        .pythonUnavailable: "Python %@+ was not found. Install Python from python.org or Homebrew.",
        .runtimeIncomplete: "The app-specific environment is incomplete. You can safely retry the installation.",
        .helperApprovalRequired: "Administrator approval is required for the USB tunnel helper",
        .helperRequiresSystemApproval: "Allow the helper in System Settings → General → Login Items & Extensions.",
        .discoveringDevices: "Detecting USB iPhone…",
        .noUSBDevice: "No USB iPhone found. Unlock the phone, check the cable, and trust this Mac.",
        .selectionRequired: "%ld iPhones detected. Choose one.",
        .unsupportedDevice: "%@ · iOS %@ is not supported. iOS 17 or later is required.",
        .preparingDevice: "Preparing %@…",
        .readyDevice: "%@ · iOS %@ is ready",
        .installDeviceSupport: "Install Device Support",
        .cancel: "Cancel",
        .approveHelper: "Approve Helper",
        .retry: "Retry",
        .chooseIPhone: "Choose iPhone",
        .selectIPhone: "%@ · iOS %@",
        .checkingPython: "Checking Python…",
        .creatingEnvironment: "Creating the app-specific environment…",
        .installingPinnedPackage: "Installing the pinned pymobiledevice3 version…",
        .verifyingCapabilities: "Verifying device capabilities…",
        .mapAndRoute: "Map & Route",
        .recenterMac: "Go to Mac Location",
        .resetStopTitle: "Reset and stop simulation?",
        .resetStopMessage: "The app will only show the real location as restored after the phone confirms clear succeeded.",
        .resetSettingsTitle: "Reset settings?",
        .resetSettingsMessage: "This clears the search, A/B endpoints, and route settings.",
        .reset: "Reset",
        .searchPlaceholder: "Search for a place or address",
        .search: "Search",
        .clear: "Clear",
        .searchResults: "Search Results",
        .unnamedPlace: "Unnamed place",
        .currentPreview: "Current Preview",
        .mapPoint: "Map point",
        .previewNotice: "Selecting a point only updates the preview. Confirm it separately to change the iPhone location.",
        .setA: "Set A",
        .setB: "Set B",
        .favorites: "Favorites",
        .name: "Name",
        .rename: "Rename",
        .delete: "Delete",
        .favoriteRemove: "Remove Favorite",
        .favoriteAdd: "Add Favorite",
        .walkingEndpoints: "Walking Endpoints",
        .createWalkingRoute: "Create Walking Route",
        .speed: "Speed",
        .speedValue: "%.1f km/h",
        .gettingWalkingRoute: "Getting walking route…",
        .routeReady: "The route is ready to confirm and start.",
        .noWalkingRoute: "No walking route is available between A and B.",
        .routeCancelled: "The walking route request was cancelled.",
        .transientRouteFailure: "Walking route is temporarily unavailable",
        .notSelected: "Not selected",
        .searchFailed: "Search failed: %@",
        .addressLookupFailed: "Address lookup failed: %@",
        .durationMinutes: "%.0f min",
        .distanceKilometers: "%.2f km",
        .distanceMeters: "%.0f m",
        .iPhoneLocation: "iPhone Location",
        .setLocation: "Set Location",
        .roundTrip: "Round Trip",
        .startWalkingRoute: "Start Walking Route",
        .deviceReadyForLocationControl: "Location controls are available after device setup is complete.",
        .stopSimulation: "Stop Simulation",
        .pause: "Pause",
        .resume: "Resume",
        .notSimulating: "Simulation is not active",
        .settingLocation: "Setting location…",
        .startingRoute: "Starting route…",
        .preparingDeviceAgain: "Preparing the device again…",
        .replacingSimulation: "Safely replacing the current mode…",
        .pointLocation: "Point location %.6f, %.6f",
        .confirmedProgress: "Confirmed %.0f m · %.1f km/h",
        .simulationInterrupted: "Simulation interrupted",
        .phoneLocationUnknown: "The phone location cannot currently be confirmed.",
        .phoneLocationKnown: "The phone location can still be confirmed.",
        .clearFailedNotRestored: "Clearing the location failed; the real location has not been restored.",
        .clearingSimulation: "Clearing simulated location…",
        .confirmStopClearTitle: "Stop and clear the simulated location?",
        .confirmation: "Confirm",
        .stopAndClear: "Stop and Clear",
        .routeNotStarted: "Route not started",
        .routePreview: "Route preview",
        .routeMoving: "Route in progress",
        .confirmingPauseLocation: "Confirming pause location",
        .routePaused: "Route paused",
        .oneWayCompleted: "One-way route completed; staying at the destination",
        .routeInterrupted: "Route interrupted",
        .stoppingRoute: "Stopping route",
        .previewAnnotation: "Preview",
        .macCurrentLocation: "Mac Current Location",
        .simulatedIPhoneLocation: "Simulated iPhone Location",
        .failureSummary: "%@: %@",
        .invalidCoordinate: "Invalid coordinate.",
        .invalidSearchQuery: "Enter a place or address to search.",
        .invalidSpeed: "Walking speed must be between 1–7 km/h.",
        .invalidRoute: "MapKit returned invalid walking route data.",
        .missingPreview: "Preview a location on the map first.",
        .missingEndpoints: "Choose A and B first.",
        .endpointsMustDiffer: "A and B must be different locations.",
        .staleSearchSelection: "The search results are stale. Choose again.",
        .routePreviewUnavailable: "There is no walking route ready to confirm.",
        .macLocationUnavailable: "The Mac's current location has not been obtained.",
        .identityExhausted: "Request identifiers are exhausted. Restart the app.",
        .macLocationPermission: "Unable to get the Mac location. Allow this app to use Location Services in System Settings → Privacy & Security → Location Services.",
        .macLocationServicesDisabled: "macOS Location Services are currently disabled, so the Mac location is unavailable.",
        .macLocationInvalid: "A valid Mac location is not currently available.",
        .macLocationRequestInProgress: "A Mac location request is already in progress.",
        .macLocationCancelled: "The Mac location request was cancelled.",
        .deviceReplyTimeout: "Device response timed out",
        .deviceReplyTimeoutMessage: "The location result could not be confirmed. Updates stopped; check the USB connection and retry.",
        .usbDisconnected: "USB disconnected",
        .usbDisconnectedMessage: "The simulated iPhone location cannot currently be confirmed. Reconnect the same iPhone to clear it first.",
        .reconnectUSB: "Reconnect",
        .finishAuthorizationAndRetry: "Finish authorization and retry",
        .unlockAndRetry: "Unlock and retry",
        .approveAgainAndRetry: "Approve again and retry",
        .prepareAgain: "Prepare again",
        .retryClear: "Retry clear",
        .finishTrustAndRetry: "Finish trusting and retry",
        .finishSetupAndRetry: "Finish setup and retry",
        .prepareDDIAgain: "Prepare DDI again",
        .authorizationDenied: "Authorization denied",
        .authorizationDeniedMessage: "Unlock the iPhone, trust this Mac, and approve the required system helper.",
        .deviceLocked: "The iPhone screen is locked",
        .deviceLockedMessage: "Preparation cannot finish while the iPhone is locked. Unlock it, keep the screen on, and retry.",
        .usbTunnelFailure: "USB tunnel failed",
        .dvtHelperFailure: "DVT helper failed",
        .helperFailureMessage: "%@. Location updates stopped; prepare the device again.",
        .clearLocationFailure: "Simulated location has not been cleared",
        .clearFailureMessage: "%@. The real location cannot be declared restored; retry clear.",
        .deviceConnectionInterrupted: "Device connection interrupted",
        .deviceConnectionInterruptedMessage: "The DVT transport was interrupted and automatic recovery did not finish.",
        .deviceConnectionFailure: "Device connection failed",
        .deviceNotReady: "Device is not ready",
        .iPhoneTrustRequired: "The iPhone has not trusted this Mac",
        .trustMessage: "%@. Unlock the iPhone and complete the trust prompt.",
        .developerModeNotReady: "Developer Mode is not ready",
        .developerModeMessage: "%@. On the iPhone, open Settings → Privacy & Security → Developer Mode, enable it, and restart.",
        .developerDiskImageFailure: "Developer Disk Image could not be prepared",
        .developerDiskImageMessage: "%@. Confirm that Xcode supports this iOS version and retry.",
        .tunnelPrerequisiteFailure: "USB tunnel prerequisite is not ready",
        .devicePrerequisiteFailure: "Device prerequisite failed",
        .prerequisiteFailureMessage: "%@: %@",
        .helperNotApproved: "The privileged helper was not approved.",
        .helperInstalledNotRegistered: "The privileged helper was installed, but launchd has not registered the service.",
        .authorizationSessionFailure: "Unable to create an administrator authorization session (%d).",
        .administratorAuthorizationFailure: "Administrator authorization failed (%d).",
        .smJobBlessFailure: "SMJobBless did not provide an error message.",
        .firstUseRiskTitle: "Understand the risks before use",
        .firstUseRiskMessage: "Location simulation may be restricted by third-party service terms and may affect accounts. Check the rules of each service you use.",
        .firstUseRiskConfirmation: "I understand",
        .simulationRiskTitle: "Start location simulation?",
        .simulationRiskMessage: "This changes the simulated location of the connected iPhone. Third-party services may restrict this behavior; you accept the account risks.",
        .simulationRiskConfirmation: "Understand the risks and start",
        .quitSimulationTitle: "Stop simulation and quit?",
        .quitSimulationMessage: "The app will stop location updates, clear the simulated location, and then close DVT and the tunnel.",
        .quitSimulationConfirm: "Stop and Quit",
        .quitCancel: "Cancel",
        .cleanupFailureTitle: "Unable to safely finish cleanup",
        .cleanupFailureMessage: "The phone may still have a simulated location. Retry, or choose force quit.",
        .forceQuit: "Force Quit…",
        .forceQuitTitle: "Force quit?",
        .forceQuitMessage: "This does not mean the real location has been restored; the iPhone may still retain simulated coordinates.",
        .forceQuitConfirm: "Force Quit Anyway",
        .openLocationControl: "Open Location Controls",
    ]

    private static let thai: [Key: String] = [
        .language: "ภาษา",
        .configurationFailure: "ไม่สามารถสร้างสภาพแวดล้อมรองรับอุปกรณ์ได้",
        .checkingDeviceSupport: "กำลังตรวจสอบสภาพแวดล้อมรองรับอุปกรณ์…",
        .checkingPymobiledevice3: "กำลังตรวจสอบ pymobiledevice3…",
        .runtimeInstallationRequired: "ต้องติดตั้งการรองรับอุปกรณ์เฉพาะสำหรับแอป",
        .pythonUnavailable: "ไม่พบ Python %@ ขึ้นไป โปรดติดตั้ง Python จาก python.org หรือ Homebrew",
        .runtimeIncomplete: "สภาพแวดล้อมเฉพาะสำหรับแอปไม่สมบูรณ์ คุณสามารถลองติดตั้งอีกครั้งได้อย่างปลอดภัย",
        .helperApprovalRequired: "ต้องได้รับอนุญาตจากผู้ดูแลระบบสำหรับ USB tunnel helper",
        .helperRequiresSystemApproval: "อนุญาต helper ที่การตั้งค่าระบบ → ทั่วไป → รายการเข้าสู่ระบบและส่วนขยาย",
        .discoveringDevices: "กำลังค้นหา iPhone ผ่าน USB…",
        .noUSBDevice: "ไม่พบ iPhone ผ่าน USB โปรดปลดล็อกโทรศัพท์ ตรวจสอบสาย และกดเชื่อถือ Mac เครื่องนี้",
        .selectionRequired: "พบ iPhone %ld เครื่อง โปรดเลือกหนึ่งเครื่อง",
        .unsupportedDevice: "%@ · iOS %@ ไม่รองรับ ต้องใช้ iOS 17 ขึ้นไป",
        .preparingDevice: "กำลังเตรียม %@…",
        .readyDevice: "%@ · iOS %@ พร้อมใช้งาน",
        .installDeviceSupport: "ติดตั้งการรองรับอุปกรณ์",
        .cancel: "ยกเลิก",
        .approveHelper: "อนุญาต Helper",
        .retry: "ลองอีกครั้ง",
        .chooseIPhone: "เลือก iPhone",
        .selectIPhone: "%@ · iOS %@",
        .checkingPython: "กำลังตรวจสอบ Python…",
        .creatingEnvironment: "กำลังสร้างสภาพแวดล้อมเฉพาะสำหรับแอป…",
        .installingPinnedPackage: "กำลังติดตั้ง pymobiledevice3 เวอร์ชันที่กำหนด…",
        .verifyingCapabilities: "กำลังตรวจสอบความสามารถของอุปกรณ์…",
        .mapAndRoute: "แผนที่และเส้นทาง",
        .recenterMac: "ไปยังตำแหน่ง Mac",
        .resetStopTitle: "รีเซ็ตและหยุดการจำลองหรือไม่",
        .resetStopMessage: "แอปจะแสดงว่ากลับสู่ตำแหน่งจริงก็ต่อเมื่อโทรศัพท์ยืนยันว่า clear สำเร็จ",
        .resetSettingsTitle: "รีเซ็ตการตั้งค่าหรือไม่",
        .resetSettingsMessage: "การดำเนินการนี้จะล้างการค้นหา จุด A/B และการตั้งค่าเส้นทาง",
        .reset: "รีเซ็ต",
        .searchPlaceholder: "ค้นหาสถานที่หรือที่อยู่",
        .search: "ค้นหา",
        .clear: "ล้าง",
        .searchResults: "ผลการค้นหา",
        .unnamedPlace: "สถานที่ไม่มีชื่อ",
        .currentPreview: "ตัวอย่างปัจจุบัน",
        .mapPoint: "จุดบนแผนที่",
        .previewNotice: "การเลือกจุดจะอัปเดตเฉพาะตัวอย่าง ต้องยืนยันแยกต่างหากเพื่อเปลี่ยนตำแหน่ง iPhone",
        .setA: "กำหนด A",
        .setB: "กำหนด B",
        .favorites: "รายการโปรด",
        .name: "ชื่อ",
        .rename: "เปลี่ยนชื่อ",
        .delete: "ลบ",
        .favoriteRemove: "นำออกจากรายการโปรด",
        .favoriteAdd: "เพิ่มในรายการโปรด",
        .walkingEndpoints: "จุดปลายทางการเดิน",
        .createWalkingRoute: "สร้างเส้นทางเดิน",
        .speed: "ความเร็ว",
        .speedValue: "%.1f กม./ชม.",
        .gettingWalkingRoute: "กำลังขอเส้นทางเดิน…",
        .routeReady: "เส้นทางพร้อมให้ยืนยันและเริ่มแล้ว",
        .noWalkingRoute: "ไม่มีเส้นทางเดินระหว่าง A และ B",
        .routeCancelled: "ยกเลิกคำขอเส้นทางเดินแล้ว",
        .transientRouteFailure: "ไม่สามารถรับเส้นทางเดินได้ชั่วคราว",
        .notSelected: "ยังไม่ได้เลือก",
        .searchFailed: "ค้นหาไม่สำเร็จ: %@",
        .addressLookupFailed: "ค้นหาที่อยู่ไม่สำเร็จ: %@",
        .durationMinutes: "%.0f นาที",
        .distanceKilometers: "%.2f กม.",
        .distanceMeters: "%.0f ม.",
        .iPhoneLocation: "ตำแหน่ง iPhone",
        .setLocation: "กำหนดตำแหน่ง",
        .roundTrip: "ไปกลับ",
        .startWalkingRoute: "เริ่มเส้นทางเดิน",
        .deviceReadyForLocationControl: "การควบคุมตำแหน่งจะใช้งานได้หลังตั้งค่าอุปกรณ์เสร็จสิ้น",
        .stopSimulation: "หยุดการจำลอง",
        .pause: "หยุดชั่วคราว",
        .resume: "ดำเนินการต่อ",
        .notSimulating: "ยังไม่ได้เปิดใช้การจำลองตำแหน่ง",
        .settingLocation: "กำลังกำหนดตำแหน่ง…",
        .startingRoute: "กำลังเริ่มเส้นทาง…",
        .preparingDeviceAgain: "กำลังเตรียมอุปกรณ์อีกครั้ง…",
        .replacingSimulation: "กำลังแทนที่โหมดปัจจุบันอย่างปลอดภัย…",
        .pointLocation: "ตำแหน่งจุด %.6f, %.6f",
        .confirmedProgress: "ยืนยันแล้ว %.0f ม. · %.1f กม./ชม.",
        .simulationInterrupted: "การจำลองหยุดชะงัก",
        .phoneLocationUnknown: "ยังไม่สามารถยืนยันตำแหน่งบนโทรศัพท์ได้",
        .phoneLocationKnown: "ยังสามารถยืนยันตำแหน่งบนโทรศัพท์ได้",
        .clearFailedNotRestored: "ล้างตำแหน่งไม่สำเร็จ ตำแหน่งจริงยังไม่ถูกกู้คืน",
        .clearingSimulation: "กำลังล้างตำแหน่งจำลอง…",
        .confirmStopClearTitle: "หยุดและล้างตำแหน่งจำลองหรือไม่",
        .confirmation: "ยืนยัน",
        .stopAndClear: "หยุดและล้าง",
        .routeNotStarted: "ยังไม่ได้เริ่มเส้นทาง",
        .routePreview: "ตัวอย่างเส้นทาง",
        .routeMoving: "กำลังเคลื่อนที่ตามเส้นทาง",
        .confirmingPauseLocation: "กำลังยืนยันตำแหน่งหยุดชั่วคราว",
        .routePaused: "หยุดเส้นทางชั่วคราว",
        .oneWayCompleted: "เส้นทางเที่ยวเดียวเสร็จสิ้น อยู่ที่จุดหมายปลายทาง",
        .routeInterrupted: "เส้นทางหยุดชะงัก",
        .stoppingRoute: "กำลังหยุดเส้นทาง",
        .previewAnnotation: "ตัวอย่าง",
        .macCurrentLocation: "ตำแหน่งปัจจุบันของ Mac",
        .simulatedIPhoneLocation: "ตำแหน่ง iPhone จำลอง",
        .failureSummary: "%@: %@",
        .invalidCoordinate: "พิกัดไม่ถูกต้อง",
        .invalidSearchQuery: "กรอกสถานที่หรือที่อยู่เพื่อค้นหา",
        .invalidSpeed: "ความเร็วเดินต้องอยู่ระหว่าง 1–7 กม./ชม.",
        .invalidRoute: "MapKit ส่งข้อมูลเส้นทางเดินที่ไม่ถูกต้อง",
        .missingPreview: "โปรดแสดงตัวอย่างตำแหน่งบนแผนที่ก่อน",
        .missingEndpoints: "โปรดเลือก A และ B ก่อน",
        .endpointsMustDiffer: "A และ B ต้องเป็นคนละตำแหน่ง",
        .staleSearchSelection: "ผลการค้นหาหมดอายุแล้ว โปรดเลือกใหม่",
        .routePreviewUnavailable: "ยังไม่มีเส้นทางเดินที่พร้อมยืนยัน",
        .macLocationUnavailable: "ยังไม่ได้รับตำแหน่งปัจจุบันของ Mac",
        .identityExhausted: "รหัสคำขอหมดแล้ว โปรดเปิดแอปใหม่",
        .macLocationPermission: "ไม่สามารถรับตำแหน่ง Mac ได้ อนุญาตให้แอปนี้ใช้บริการตำแหน่งที่ การตั้งค่าระบบ → ความเป็นส่วนตัวและความปลอดภัย → บริการตำแหน่ง",
        .macLocationServicesDisabled: "บริการตำแหน่งของ macOS ปิดอยู่ จึงไม่สามารถรับตำแหน่ง Mac ได้",
        .macLocationInvalid: "ขณะนี้ไม่มีตำแหน่ง Mac ที่ถูกต้อง",
        .macLocationRequestInProgress: "กำลังขอตำแหน่ง Mac อยู่แล้ว",
        .macLocationCancelled: "ยกเลิกคำขอตำแหน่ง Mac แล้ว",
        .deviceReplyTimeout: "อุปกรณ์ไม่ตอบสนองภายในเวลาที่กำหนด",
        .deviceReplyTimeoutMessage: "ไม่สามารถยืนยันผลตำแหน่งได้ หยุดการอัปเดตแล้ว โปรดตรวจสอบการเชื่อมต่อ USB และลองใหม่",
        .usbDisconnected: "USB ถูกตัดการเชื่อมต่อ",
        .usbDisconnectedMessage: "ยังไม่สามารถยืนยันตำแหน่งจำลองของ iPhone ได้ เชื่อมต่อ iPhone เครื่องเดิมอีกครั้งเพื่อล้างข้อมูลก่อน",
        .reconnectUSB: "เชื่อมต่อใหม่",
        .finishAuthorizationAndRetry: "อนุญาตให้เสร็จแล้วลองอีกครั้ง",
        .unlockAndRetry: "ปลดล็อกแล้วลองอีกครั้ง",
        .approveAgainAndRetry: "อนุญาตอีกครั้งแล้วลองใหม่",
        .prepareAgain: "เตรียมใหม่",
        .retryClear: "ลองล้างอีกครั้ง",
        .finishTrustAndRetry: "เชื่อถือให้เสร็จแล้วลองใหม่",
        .finishSetupAndRetry: "ตั้งค่าให้เสร็จแล้วลองใหม่",
        .prepareDDIAgain: "เตรียม DDI ใหม่",
        .authorizationDenied: "การอนุญาตถูกปฏิเสธ",
        .authorizationDeniedMessage: "ปลดล็อก iPhone เชื่อถือ Mac เครื่องนี้ และอนุญาต system helper ที่จำเป็น",
        .deviceLocked: "หน้าจอ iPhone ถูกล็อก",
        .deviceLockedMessage: "ไม่สามารถเตรียมอุปกรณ์ขณะ iPhone ถูกล็อก โปรดปลดล็อก เปิดหน้าจอไว้ แล้วลองใหม่",
        .usbTunnelFailure: "USB tunnel ล้มเหลว",
        .dvtHelperFailure: "DVT helper ล้มเหลว",
        .helperFailureMessage: "%@ หยุดการอัปเดตตำแหน่งแล้ว โปรดเตรียมอุปกรณ์ใหม่",
        .clearLocationFailure: "ยังไม่ได้ล้างตำแหน่งจำลอง",
        .clearFailureMessage: "%@ ยังไม่สามารถยืนยันว่ากู้คืนตำแหน่งจริงแล้ว โปรดลอง clear อีกครั้ง",
        .deviceConnectionInterrupted: "การเชื่อมต่ออุปกรณ์หยุดชะงัก",
        .deviceConnectionInterruptedMessage: "การขนส่ง DVT หยุดชะงัก และการกู้คืนอัตโนมัติยังไม่เสร็จ",
        .deviceConnectionFailure: "การเชื่อมต่ออุปกรณ์ล้มเหลว",
        .deviceNotReady: "อุปกรณ์ยังไม่พร้อม",
        .iPhoneTrustRequired: "iPhone ยังไม่ได้เชื่อถือ Mac เครื่องนี้",
        .trustMessage: "%@ ปลดล็อก iPhone และทำตามคำขอให้เชื่อถือให้เสร็จ",
        .developerModeNotReady: "Developer Mode ยังไม่พร้อม",
        .developerModeMessage: "%@ เปิดการตั้งค่า → ความเป็นส่วนตัวและความปลอดภัย → Developer Mode บน iPhone แล้วเปิดใช้งานและรีสตาร์ท",
        .developerDiskImageFailure: "ไม่สามารถเตรียม Developer Disk Image ได้",
        .developerDiskImageMessage: "%@ ตรวจสอบว่า Xcode รองรับ iOS เวอร์ชันนี้แล้วลองใหม่",
        .tunnelPrerequisiteFailure: "ข้อกำหนดเบื้องต้นของ USB tunnel ยังไม่พร้อม",
        .devicePrerequisiteFailure: "ข้อกำหนดเบื้องต้นของอุปกรณ์ล้มเหลว",
        .prerequisiteFailureMessage: "%@: %@",
        .helperNotApproved: "ผู้ใช้ยังไม่ได้อนุมัติ privileged helper",
        .helperInstalledNotRegistered: "ติดตั้ง privileged helper แล้ว แต่ launchd ยังไม่ได้ลงทะเบียนบริการ",
        .authorizationSessionFailure: "ไม่สามารถสร้างเซสชันอนุญาตของผู้ดูแลระบบได้ (%d)",
        .administratorAuthorizationFailure: "การอนุญาตของผู้ดูแลระบบล้มเหลว (%d)",
        .smJobBlessFailure: "SMJobBless ไม่ได้ระบุข้อความผิดพลาด",
        .firstUseRiskTitle: "โปรดทำความเข้าใจความเสี่ยงก่อนใช้งาน",
        .firstUseRiskMessage: "การจำลองตำแหน่งอาจถูกจำกัดโดยข้อกำหนดของบริการภายนอกและอาจส่งผลต่อบัญชี โปรดตรวจสอบกฎของแต่ละบริการที่ใช้",
        .firstUseRiskConfirmation: "ฉันเข้าใจแล้ว",
        .simulationRiskTitle: "เริ่มการจำลองตำแหน่งหรือไม่",
        .simulationRiskMessage: "การดำเนินการนี้จะเปลี่ยนตำแหน่งจำลองของ iPhone ที่เชื่อมต่อ บริการภายนอกอาจจำกัดการใช้งานนี้ คุณยอมรับความเสี่ยงต่อบัญชีด้วยตนเอง",
        .simulationRiskConfirmation: "เข้าใจความเสี่ยงและเริ่ม",
        .quitSimulationTitle: "หยุดการจำลองและออกจากแอปหรือไม่",
        .quitSimulationMessage: "แอปจะหยุดการอัปเดตตำแหน่ง ล้างตำแหน่งจำลอง แล้วปิด DVT และ tunnel",
        .quitSimulationConfirm: "หยุดและออก",
        .quitCancel: "ยกเลิก",
        .cleanupFailureTitle: "ไม่สามารถล้างข้อมูลให้เสร็จอย่างปลอดภัย",
        .cleanupFailureMessage: "โทรศัพท์อาจยังมีตำแหน่งจำลองอยู่ ลองอีกครั้งหรือเลือกบังคับออก",
        .forceQuit: "บังคับออก…",
        .forceQuitTitle: "บังคับออกหรือไม่",
        .forceQuitMessage: "ไม่ได้หมายความว่ากู้คืนตำแหน่งจริงแล้ว iPhone อาจยังคงพิกัดจำลองไว้",
        .forceQuitConfirm: "บังคับออกต่อไป",
        .openLocationControl: "เปิดการควบคุมตำแหน่ง",
    ]
}

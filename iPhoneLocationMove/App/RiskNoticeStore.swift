import Combine
import Foundation

struct RiskNotice: Equatable, Sendable {
    let title: String
    let message: String
    let confirmationTitle: String

    static var firstUse: Self {
        firstUse(for: .current)
    }

    static var simulationStart: Self {
        simulationStart(for: .current)
    }

    static func firstUse(for language: AppLanguage) -> Self {
        Self(
            title: L10n.text(.firstUseRiskTitle, language: language),
            message: L10n.text(.firstUseRiskMessage, language: language),
            confirmationTitle: L10n.text(
                .firstUseRiskConfirmation,
                language: language
            )
        )
    }

    static func simulationStart(for language: AppLanguage) -> Self {
        Self(
            title: L10n.text(.simulationRiskTitle, language: language),
            message: L10n.text(.simulationRiskMessage, language: language),
            confirmationTitle: L10n.text(
                .simulationRiskConfirmation,
                language: language
            )
        )
    }
}

@MainActor
final class RiskNoticeStore: ObservableObject {
    static let acknowledgedKey =
        "hasAcknowledgedThirdPartyLocationSimulationRisk"

    @Published private(set) var needsFirstUseAcknowledgement: Bool
    var firstUseNotice: RiskNotice {
        RiskNotice.firstUse
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        needsFirstUseAcknowledgement = !defaults.bool(
            forKey: Self.acknowledgedKey
        )
    }

    func acknowledgeFirstUse() {
        defaults.set(true, forKey: Self.acknowledgedKey)
        needsFirstUseAcknowledgement = false
    }

    func noticeForSimulationStart() -> RiskNotice {
        RiskNotice.simulationStart
    }
}

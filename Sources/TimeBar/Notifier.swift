import Foundation
import UserNotifications

/// macOS bildirimleri. Geri sayım bitince "+5 dk", mesai hedefi dolunca "Bitir" butonu çıkar.
@MainActor
final class Notifier: NSObject, UNUserNotificationCenterDelegate {
    static let shared = Notifier()

    enum Kind: String { case countdownFinished, shiftTarget, pomodoroPhase }

    weak var model: Model?
    private var center: UNUserNotificationCenter? {
        // Paket dışında (swift run) çalışırken UNUserNotificationCenter çöker
        Bundle.main.bundleURL.pathExtension == "app" ? .current() : nil
    }

    func setup(model: Model) {
        self.model = model
        guard let center else { return }
        center.delegate = self
        let snooze = UNNotificationAction(identifier: "snooze", title: "+5 dk")
        let finish = UNNotificationAction(identifier: "finish", title: "Bitir")
        center.setNotificationCategories([
            UNNotificationCategory(identifier: Kind.countdownFinished.rawValue, actions: [snooze], intentIdentifiers: []),
            UNNotificationCategory(identifier: Kind.shiftTarget.rawValue, actions: [finish], intentIdentifiers: []),
        ])
    }

    /// İzin ilk sayaç başlatılınca istenir, açılışta değil.
    func requestPermission(then done: @escaping @MainActor () -> Void = {}) {
        center?.requestAuthorization(options: [.alert]) { _, _ in
            DispatchQueue.main.async { MainActor.assumeIsolated { done() } }
        }
    }

    func authorizationStatus() async -> UNAuthorizationStatus? {
        guard let center else { return nil }
        return await center.notificationSettings().authorizationStatus
    }

    func post(_ kind: Kind, title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.categoryIdentifier = kind.rawValue
        // Ses bildirimden değil, Ayarlar'da seçilen sesten gelir
        center?.add(UNNotificationRequest(identifier: kind.rawValue, content: content, trigger: nil))
    }

    func clear() {
        center?.removeAllDeliveredNotifications()
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification,
                                            withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .list])
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse,
                                            withCompletionHandler completionHandler: @escaping () -> Void) {
        let action = response.actionIdentifier
        let kind = response.notification.request.content.categoryIdentifier
        DispatchQueue.main.async {
            MainActor.assumeIsolated {
                guard let model = Notifier.shared.model else { return }
                switch (action, kind) {
                case ("snooze", _): model.addFiveMinutes()
                case ("finish", _), (UNNotificationDefaultActionIdentifier, Kind.shiftTarget.rawValue): model.finish()
                case (UNNotificationDefaultActionIdentifier, _): model.acknowledgeAlert()
                default: break
                }
            }
        }
        completionHandler()
    }
}

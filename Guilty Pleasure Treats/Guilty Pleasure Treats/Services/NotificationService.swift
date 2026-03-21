//
//  NotificationService.swift
//  Guilty Pleasure Treats
//
//  Local notifications and APNs registration for owner new-order push (no Firebase).
//

import Combine
import Foundation
import UserNotifications
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

/// Action to perform when user taps a push (e.g. open Admin → Messages).
enum PendingPushAction: Equatable {
    case openAdminMessages(messageId: String?)
    case openAdminOrder(orderId: String?)
    case openAdminInventory
    /// Customer: open Orders tab and show this order.
    case openOrder(orderId: String?)
    /// Customer: open Home tab so events section is visible.
    case openEvents
    /// Customer: Account tab → Messages from store (`admin_message` push).
    case openContactReplies
}

final class NotificationService: NSObject, ObservableObject {
    static let shared = NotificationService()

    /// When non-nil, UI should open Admin and navigate (e.g. to Messages tab). Cleared after handling.
    @Published private(set) var pendingPushAction: PendingPushAction?

    /// When set, Orders tab should open this order (customer order-status push). Cleared after opening.
    @Published private(set) var pendingOrderIdToOpen: String?

    /// Bumped to tell `ProfileView` to navigate to Contact Replies (customer `admin_message` push).
    @Published private(set) var contactRepliesDeepLinkToken: UInt64 = 0

    /// Device token from APNs (hex string). Set by AppDelegate when remote notifications register.
    private(set) var deviceToken: String?

    /// In-app notification center (bell). Persisted so it survives app restart.
    @Published private(set) var inAppNotifications: [AppNotification] = [] {
        didSet {
            saveInAppNotifications()
        }
    }

    private static let inAppNotificationsKey = "NotificationService.inAppNotifications"
    private static let inAppNotificationsMaxCount = 100

    private override init() {
        super.init()
        loadInAppNotifications()
    }

    private func loadInAppNotifications() {
        guard let data = UserDefaults.standard.data(forKey: Self.inAppNotificationsKey),
              let decoded = try? JSONDecoder().decode([AppNotification].self, from: data) else { return }
        inAppNotifications = decoded
    }

    private func saveInAppNotifications() {
        guard let data = try? JSONEncoder().encode(inAppNotifications) else { return }
        UserDefaults.standard.set(data, forKey: Self.inAppNotificationsKey)
    }

    /// Add a notification to the center (e.g. when a push is received or when new order is detected in app).
    func addInAppNotification(_ notification: AppNotification) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            var list = self.inAppNotifications
            list.insert(notification, at: 0)
            if list.count > Self.inAppNotificationsMaxCount {
                list = Array(list.prefix(Self.inAppNotificationsMaxCount))
            }
            self.inAppNotifications = list
        }
    }

    /// Add from push payload (title, body, type, orderId, messageId, eventId).
    func addInAppNotificationFromPush(title: String, body: String, type: String?, orderId: String?, messageId: String?, eventId: String? = nil) {
        let notifType: AppNotificationType
        if type == "new_order" {
            notifType = .newOrder
        } else if type == "new_message" {
            notifType = .newMessage
        } else if type == "order_status" {
            notifType = .orderStatus
        } else if type == "low_inventory" {
            notifType = .lowInventory
        } else if type == "new_event" {
            notifType = .newEvent
        } else if type == "admin_message" {
            notifType = .storeMessage
        } else {
            notifType = .newOrder
        }
        let n = AppNotification(
            type: notifType,
            title: title,
            body: body,
            orderId: orderId,
            messageId: messageId,
            eventId: eventId
        )
        addInAppNotification(n)
    }

    func markInAppNotificationRead(id: String) {
        guard let idx = inAppNotifications.firstIndex(where: { $0.id == id }) else { return }
        var list = inAppNotifications
        list[idx].read = true
        inAppNotifications = list
    }

    func removeInAppNotification(id: String) {
        inAppNotifications.removeAll { $0.id == id }
    }

    func clearAllInAppNotifications() {
        inAppNotifications = []
    }

    /// Call when Admin loads orders: add a "New order" to the center if this order is recent and not already listed (e.g. push failed).
    func addNewOrderInAppIfNeeded(orderId: String, customerName: String, total: Double, orderCreatedAt: Date) {
        let twoMinutesAgo = Date().addingTimeInterval(-120)
        guard orderCreatedAt >= twoMinutesAgo else { return }
        if inAppNotifications.contains(where: { $0.orderId == orderId && $0.type == .newOrder }) { return }
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale.current
        let totalStr = formatter.string(from: NSNumber(value: total)) ?? "$0"
        let n = AppNotification(
            type: .newOrder,
            title: "New order",
            body: "\(customerName) · \(totalStr)",
            orderId: orderId
        )
        addInAppNotification(n)
    }

    /// Unread count for bell badge.
    var unreadInAppNotificationCount: Int {
        inAppNotifications.filter { !$0.read }.count
    }

    /// Called by AppDelegate when device token is received. Registers with backend if user is signed in.
    func setDeviceToken(_ token: String) {
        deviceToken = token
        Task { @MainActor in
            await registerPushTokenWithBackend()
        }
    }

    /// Register current device token with backend. Call when signed in (admin = new-order/new-message push; customer = order-status push).
    @MainActor
    func registerPushTokenWithBackend() async {
        guard let token = deviceToken, !token.isEmpty,
              AuthService.shared.currentUser != nil,
              VercelService.isConfigured else { return }
        do {
            try await VercelService.shared.registerPushToken(deviceToken: token)
        } catch {
            #if DEBUG
            print("[Push] register failed:", error)
            #endif
        }
    }

    /// Request notification permission and register for remote (APNs) notifications.
    func requestPermissionAndRegister() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
            DispatchQueue.main.async {
                guard granted else { return }
                #if os(iOS)
                UIApplication.shared.registerForRemoteNotifications()
                #elseif os(macOS)
                NSApplication.shared.registerForRemoteNotifications()
                #endif
            }
        }
        UNUserNotificationCenter.current().delegate = self
    }
    
    /// Schedule a local notification when order status changes.
    func scheduleOrderStatusNotification(orderId: String, status: String) {
        let content = UNMutableNotificationContent()
        content.title = "Guilty Pleasure Treats"
        content.body = "Your order status: \(status)"
        content.sound = .default
        content.userInfo = ["type": "order_status", "orderId": orderId]

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: "order-\(orderId)", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    /// Schedule a local notification for low inventory. Replaces any previous low-inventory alert (same identifier).
    func scheduleLowStockNotification(count: Int, firstProductName: String?) {
        let content = UNMutableNotificationContent()
        content.title = "Low inventory"
        if count == 1, let name = firstProductName, !name.isEmpty {
            content.body = "\(name) is low in stock. Tap to view Inventory."
        } else {
            content.body = "\(count) items are low in stock. Tap to view Inventory."
        }
        content.sound = .default
        content.userInfo = ["type": "low_inventory"]
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 2, repeats: false)
        let request = UNNotificationRequest(identifier: "low-inventory-alert", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }
}

extension NotificationService: UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        let content = notification.request.content
        let userInfo = content.userInfo
        let type = userInfo["type"] as? String
        let orderId = userInfo["orderId"] as? String
        let messageId = userInfo["messageId"] as? String
        let eventId = userInfo["eventId"] as? String
        addInAppNotificationFromPush(
            title: content.title,
            body: content.body,
            type: type,
            orderId: orderId,
            messageId: messageId,
            eventId: eventId
        )
        #if os(macOS)
        if #available(macOS 11.0, *) {
            completionHandler([.banner, .sound, .badge])
        } else {
            completionHandler([.sound, .badge])
        }
        #else
        completionHandler([.banner, .sound, .badge])
        #endif
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let content = response.notification.request.content
        let userInfo = content.userInfo
        let type = (userInfo["type"] as? String) ?? (userInfo["aps"] as? [String: Any]).flatMap { $0["type"] as? String }
        let messageId = userInfo["messageId"] as? String
        let orderId = userInfo["orderId"] as? String
        let eventId = userInfo["eventId"] as? String

        addInAppNotificationFromPush(
            title: content.title,
            body: content.body,
            type: type,
            orderId: orderId,
            messageId: messageId,
            eventId: eventId
        )

        if type == "new_message" {
            DispatchQueue.main.async { [weak self] in
                self?.pendingPushAction = .openAdminMessages(messageId: messageId?.isEmpty == true ? nil : messageId)
            }
        } else if type == "new_order" {
            DispatchQueue.main.async { [weak self] in
                let oid = orderId?.isEmpty == true ? nil : orderId
                self?.pendingPushAction = .openAdminOrder(orderId: oid)
            }
        } else if type == "order_status" {
            DispatchQueue.main.async { [weak self] in
                let oid = orderId?.isEmpty == true ? nil : orderId
                self?.pendingPushAction = .openOrder(orderId: oid)
                self?.pendingOrderIdToOpen = oid
            }
        } else if type == "low_inventory" {
            DispatchQueue.main.async { [weak self] in
                self?.pendingPushAction = .openAdminInventory
            }
        } else if type == "new_event" {
            DispatchQueue.main.async { [weak self] in
                self?.pendingPushAction = .openEvents
            }
        } else if type == "admin_message" {
            DispatchQueue.main.async { [weak self] in
                self?.pendingPushAction = .openContactReplies
            }
        }
        completionHandler()
    }

    /// Call after handling pendingPushAction (e.g. after switching to Messages tab).
    func clearPendingPushAction() {
        pendingPushAction = nil
    }

    /// Set pending action (e.g. when user taps a notification in the notification center).
    func setPendingPushAction(_ action: PendingPushAction?) {
        pendingPushAction = action
    }

    /// Call after opening the order from Orders tab (customer order-status push).
    func clearPendingOrderIdToOpen() {
        pendingOrderIdToOpen = nil
    }

    /// Set when opening Orders from notification center so the order detail is shown.
    func setPendingOrderIdToOpen(_ orderId: String?) {
        pendingOrderIdToOpen = orderId
    }

    /// Customer: deep link to Account → Messages from store.
    func requestNavigateToContactReplies() {
        contactRepliesDeepLinkToken &+= 1
    }
}

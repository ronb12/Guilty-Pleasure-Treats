//
//  NotificationService.swift
//  Guilty Pleasure Treats
//
//  Push notifications for order status updates (Firebase Cloud Messaging).
//

import Foundation
import UserNotifications
import FirebaseMessaging

final class NotificationService: NSObject, ObservableObject {
    static let shared = NotificationService()
    @Published var fcmToken: String?
    
    private override init() {
        super.init()
    }
    
    /// Request notification permission and register for remote notifications.
    func requestPermissionAndRegister() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
            DispatchQueue.main.async {
                if granted {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            }
        }
        UNUserNotificationCenter.current().delegate = self
        Messaging.messaging().delegate = self
    }
    
    /// Schedule a local notification (e.g. when order status changes, if not using FCM).
    func scheduleOrderStatusNotification(orderId: String, status: String) {
        let content = UNMutableNotificationContent()
        content.title = "Guilty Pleasure Treats"
        content.body = "Your order status: \(status)"
        content.sound = .default
        content.userInfo = ["orderId": orderId]
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: "order-\(orderId)", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }
}

extension NotificationService: UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .badge])
    }
}

extension NotificationService: MessagingDelegate {
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        DispatchQueue.main.async {
            self.fcmToken = fcmToken
        }
        // Send token to your server if needed for targeted push.
    }
}

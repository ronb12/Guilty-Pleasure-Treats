//
//  AppDelegate.swift
//  Guilty Pleasure Treats
//
//  Push is built in: iOS gives the app a device token; the app sends it to our backend automatically.
//  No user action needed. Admin gets new-order/new-message push; customers get order-status push.
//

#if !os(macOS)
import UIKit

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        NotificationService.shared.requestPermissionAndRegister()
        return true
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        let hex = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        NotificationService.shared.setDeviceToken(hex)
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        #if DEBUG
        print("[Push] register failed:", error.localizedDescription)
        #endif
    }
}
#endif

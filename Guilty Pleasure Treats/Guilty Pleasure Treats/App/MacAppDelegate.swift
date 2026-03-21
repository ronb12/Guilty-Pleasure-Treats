//
//  MacAppDelegate.swift
//  Guilty Pleasure Treats
//
//  Remote push on macOS: register with APNs and forward the device token to NotificationService
//  (same hex flow as iOS AppDelegate). Enable Push Notifications for the Mac target in Xcode.
//

#if os(macOS)
import AppKit

final class MacAppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NotificationService.shared.requestPermissionAndRegister()
    }

    func application(_ application: NSApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let hex = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        NotificationService.shared.setDeviceToken(hex)
    }

    func application(_ application: NSApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        #if DEBUG
        print("[Push] register failed:", error.localizedDescription)
        #endif
    }
}
#endif

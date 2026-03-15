//
//  GuiltyPleasureTreatsApp.swift
//  Guilty Pleasure Treats
//
//  App entry point. Configures Firebase, Stripe, and notifications.
//

import SwiftUI
import FirebaseCore
import FirebaseMessaging

@main
struct GuiltyPleasureTreatsApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    
    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}

/// Handles Firebase and push notification setup.
class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        FirebaseApp.configure()
        NotificationService.shared.requestPermissionAndRegister()
        // Configure Stripe with your publishable key (from Stripe Dashboard).
        // StripeService.configure(publishableKey: "pk_test_...")
        return true
    }
    
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Messaging.messaging().apnsToken = deviceToken
    }
}

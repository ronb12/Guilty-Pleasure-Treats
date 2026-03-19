//
//  SettingsView.swift
//  Guilty Pleasure Treats
//
//  App settings: notifications, legal, about, sign out.
//

import SwiftUI

struct SettingsView: View {
    @StateObject private var auth = AuthService.shared
    @AppStorage("settings.notificationsEnabled") private var notificationsEnabled = true
    @AppStorage("settings.appearance") private var appearanceRaw = AppAppearance.system.rawValue
    @State private var showContactForm = false
    @State private var showDeleteAccountConfirmation = false
    @State private var isDeletingAccount = false
    @State private var deleteAccountError: String?
    
    private var appearance: AppAppearance {
        get { AppAppearance(rawValue: appearanceRaw) ?? .system }
        set { appearanceRaw = newValue.rawValue }
    }
    
    var body: some View {
        List {
            appearanceSection
            notificationsSection
            contactSection
            legalSection
            aboutSection
            if auth.currentUser != nil {
                signOutSection
            }
        }
        .macOSConstrainedContent()
        .navigationTitle("Settings")
        .inlineNavigationTitle()
        .background(AppConstants.Colors.secondary)
    }
    
    private var appearanceSection: some View {
        Section("Appearance") {
            Picker("Theme", selection: Binding(
                get: { AppAppearance(rawValue: appearanceRaw) ?? .system },
                set: { appearanceRaw = $0.rawValue }
            )) {
                ForEach(AppAppearance.allCases) { mode in
                    Label(mode.displayName, systemImage: mode.icon)
                        .tag(mode)
                }
            }
            .pickerStyle(.menu)
            .tint(AppConstants.Colors.accent)
        }
    }
    
    private var notificationsSection: some View {
        Section {
            Toggle("Order updates & promotions", isOn: $notificationsEnabled)
                .tint(AppConstants.Colors.accent)
                .onChange(of: notificationsEnabled) { _, new in
                    if new {
                        NotificationService.shared.requestPermissionAndRegister()
                    }
                }
        } header: {
            Text("Notifications")
        } footer: {
            Text("Receive push notifications for order status and special offers.")
        }
    }

    private var contactSection: some View {
        Section("Contact") {
            if let url = URL(string: "mailto:\(AppConstants.contactEmailString)") {
                Link(destination: url) {
                    HStack {
                        Text("Email us")
                        Spacer()
                        Image(systemName: "arrow.up.right.square")
                            .font(.caption)
                            .foregroundStyle(AppConstants.Colors.textSecondary)
                    }
                }
                .foregroundStyle(AppConstants.Colors.textPrimary)
            }
            if let url = URL(string: AppConstants.instagramURLString) {
                Link(destination: url) {
                    HStack {
                        Text("Message via Instagram")
                        Spacer()
                        Image(systemName: "arrow.up.right.square")
                            .font(.caption)
                            .foregroundStyle(AppConstants.Colors.textSecondary)
                    }
                }
                .foregroundStyle(AppConstants.Colors.textPrimary)
            }
            Button {
                showContactForm = true
            } label: {
                HStack {
                    Text("Send a message in app")
                    Spacer()
                    Image(systemName: "bubble.left.and.bubble.right")
                        .font(.caption)
                        .foregroundStyle(AppConstants.Colors.textSecondary)
                }
            }
            .foregroundStyle(AppConstants.Colors.textPrimary)
        }
        .sheet(isPresented: $showContactForm) {
            ContactView()
        }
    }
    
    private var legalSection: some View {
        Section("Legal") {
            NavigationLink("Privacy Policy") {
                DocumentView(title: "Privacy Policy", markdown: LegalContent.privacyPolicyMarkdown)
            }
            NavigationLink("Terms of Service") {
                DocumentView(title: "Terms of Service", markdown: LegalContent.termsOfServiceMarkdown)
            }
        }
    }
    
    private var aboutSection: some View {
        Section {
            Text("Guilty Pleasure Treats is a bakery offering handmade cupcakes, cookies, cakes, and brownies. We focus on fresh, quality ingredients and friendly service for pickup and delivery.")
                .font(.subheadline)
                .foregroundStyle(AppConstants.Colors.textSecondary)
                .padding(.vertical, 4)
            HStack {
                Text("Version")
                Spacer()
                Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                    .foregroundStyle(AppConstants.Colors.textSecondary)
            }
            if let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
                HStack {
                    Text("Build")
                    Spacer()
                    Text(build)
                        .foregroundStyle(AppConstants.Colors.textSecondary)
                }
            }
            if let url = URL(string: AppConstants.supportURLString) {
                Link(destination: url) {
                    HStack {
                        Text("Support")
                        Spacer()
                        Image(systemName: "arrow.up.right.square")
                            .font(.caption)
                            .foregroundStyle(AppConstants.Colors.textSecondary)
                    }
                }
                .foregroundStyle(AppConstants.Colors.textPrimary)
            }
            if let url = URL(string: AppConstants.instagramURLString) {
                Link(destination: url) {
                    HStack {
                        Text("Instagram")
                        Spacer()
                        Image(systemName: "arrow.up.right.square")
                            .font(.caption)
                            .foregroundStyle(AppConstants.Colors.textSecondary)
                    }
                }
                .foregroundStyle(AppConstants.Colors.textPrimary)
            }
            HStack {
                Text("Built by Ronell Bradley")
                    .foregroundStyle(AppConstants.Colors.textSecondary)
            }
            HStack {
                Text("Product of Bradley, Virtual Solutions, LLC")
                    .foregroundStyle(AppConstants.Colors.textSecondary)
            }
        } header: {
            Text("About")
        }
    }
    
    private var signOutSection: some View {
        Section {
            Button(role: .destructive) {
                try? auth.signOut()
            } label: {
                HStack {
                    Spacer()
                    Text("Sign Out")
                    Spacer()
                }
            }
        }
    }

    private var deleteAccountSection: some View {
        Section {
            Button(role: .destructive) {
                showDeleteAccountConfirmation = true
            } label: {
                HStack {
                    Spacer()
                    if isDeletingAccount {
                        ProgressView()
                            .scaleEffect(0.9)
                            .tint(.white)
                    } else {
                        Text("Delete account")
                    }
                    Spacer()
                }
            }
            .disabled(isDeletingAccount)
        } footer: {
            Text("Permanently delete your account and data. Required by App Store policy; you can do this anytime from Settings.")
        }
    }

    private func deleteAccount() async {
        isDeletingAccount = true
        deleteAccountError = nil
        defer { isDeletingAccount = false }
        do {
            try await auth.deleteAccount()
            showDeleteAccountConfirmation = false
        } catch {
            deleteAccountError = FriendlyErrorMessage.message(for: error)
        }
    }
}

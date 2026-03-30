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
    @State private var marketingEmailOptIn = true
    @State private var marketingPrefLoaded = false
    @State private var marketingSaving = false
    @State private var marketingPrefError: String?
    @State private var allergyDraft = ""
    @State private var allergySaving = false
    @State private var allergyError: String?
    
    private var appearance: AppAppearance {
        get { AppAppearance(rawValue: appearanceRaw) ?? .system }
        set { appearanceRaw = newValue.rawValue }
    }
    
    var body: some View {
        List {
            appearanceSection
            notificationsSection
            if auth.currentUser != nil {
                emailMarketingSection
                foodAllergiesSection
            }
            contactSection
            helpSection
            legalSection
            aboutSection
            if auth.currentUser != nil {
                signOutSection
                deleteAccountSection
            }
        }
        .macOSConstrainedContent()
        .navigationTitle("Settings")
        .inlineNavigationTitle()
        .background(AppConstants.Colors.secondary)
        .onAppear {
            syncMarketingPrefFromProfile()
            syncAllergyDraftFromProfile()
        }
        .onChange(of: auth.userProfile?.foodAllergies) { _, new in
            guard !allergySaving else { return }
            let next = new ?? ""
            if next != allergyDraft { allergyDraft = next }
        }
        .onChange(of: auth.userProfile?.marketingEmailOptIn) { _, new in
            guard !marketingSaving, let new else { return }
            if new != marketingEmailOptIn { marketingEmailOptIn = new }
        }
        .confirmationDialog("Delete account", isPresented: $showDeleteAccountConfirmation, titleVisibility: .visible) {
            Button("Delete account", role: .destructive) {
                Task { await deleteAccount() }
            }
            Button("Cancel", role: .cancel) {
                showDeleteAccountConfirmation = false
            }
        } message: {
            Text("This will permanently delete your account and data. This action cannot be undone.")
        }
        .alert("Error", isPresented: .constant(deleteAccountError != nil)) {
            Button("OK") { deleteAccountError = nil }
        } message: {
            if let msg = deleteAccountError { Text(msg) }
        }
        .alert("Couldn’t update email preference", isPresented: .constant(marketingPrefError != nil)) {
            Button("OK") { marketingPrefError = nil }
        } message: {
            if let msg = marketingPrefError { Text(msg) }
        }
        .alert("Couldn’t save allergies", isPresented: .constant(allergyError != nil)) {
            Button("OK") { allergyError = nil }
        } message: {
            if let msg = allergyError { Text(msg) }
        }
    }
    
    private var emailMarketingSection: some View {
        Section {
            Toggle("Email newsletters & offers", isOn: $marketingEmailOptIn)
                .tint(AppConstants.Colors.accent)
                .disabled(marketingSaving)
                .onChange(of: marketingEmailOptIn) { _, new in
                    guard marketingPrefLoaded else { return }
                    Task { await saveMarketingEmailPref(new) }
                }
        } header: {
            Text("Email")
        } footer: {
            Text("Occasional updates from the bakery. Order-related messages may still be sent. You can turn this off anytime, or tap Unsubscribe in any newsletter email.")
        }
    }
    
    private func syncMarketingPrefFromProfile() {
        marketingPrefLoaded = false
        marketingEmailOptIn = auth.userProfile?.marketingEmailOptIn ?? true
        marketingPrefLoaded = true
    }
    
    private var foodAllergiesSection: some View {
        Section {
            TextField("e.g. peanuts, tree nuts, dairy", text: $allergyDraft, axis: .vertical)
                #if os(iOS)
                .lineLimit(4...8)
                #endif
            Button(allergySaving ? "Saving…" : "Save food allergies") {
                Task { await saveFoodAllergiesDraft() }
            }
            .disabled(allergySaving)
        } header: {
            Text("Food allergies")
        } footer: {
            Text("Optional. Shown on your orders for the kitchen. We can’t guarantee an allergen-free environment.")
        }
    }
    
    private func syncAllergyDraftFromProfile() {
        allergyDraft = auth.userProfile?.foodAllergies ?? ""
    }
    
    private func saveFoodAllergiesDraft() async {
        allergySaving = true
        allergyError = nil
        defer { allergySaving = false }
        do {
            let trimmed = allergyDraft.trimmingCharacters(in: .whitespacesAndNewlines)
            try await auth.saveFoodAllergies(trimmed.isEmpty ? nil : trimmed)
        } catch {
            allergyError = error.localizedDescription
        }
    }
    
    private func saveMarketingEmailPref(_ enabled: Bool) async {
        marketingSaving = true
        marketingPrefError = nil
        defer { marketingSaving = false }
        do {
            try await VercelService.shared.updateMarketingEmailOptIn(enabled)
            await auth.refreshProfile()
        } catch {
            marketingPrefError = error.localizedDescription
            marketingEmailOptIn = !enabled
        }
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

    private var helpSection: some View {
        Section("Help") {
            NavigationLink("Rewards & points") {
                DocumentView(title: "Rewards & points", markdown: LegalContent.rewardsHelpMarkdown)
            }
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
            Button {
                showContactForm = true
            } label: {
                HStack {
                    Text("Support")
                    Spacer()
                    Image(systemName: "bubble.left.and.bubble.right")
                        .font(.caption)
                        .foregroundStyle(AppConstants.Colors.textSecondary)
                }
            }
            .foregroundStyle(AppConstants.Colors.textPrimary)
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

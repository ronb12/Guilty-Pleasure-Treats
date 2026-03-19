//
//  ProfileView.swift
//  Guilty Pleasure Treats
//
//  Shows sign-in prompt or user info and sign out.
//

import SwiftUI

struct ProfileView: View {
    @StateObject private var auth = AuthService.shared
    @State private var showLogin = false
    @State private var showAdmin = false

    var body: some View {
        Group {
            switch auth.authState {
            case .loading:
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .signedIn(let user):
                signedInView(user: user)
            case .signedOut:
                signedOutView
            }
        }
        .background(AppConstants.Colors.secondary)
        .macOSConstrainedContent()
        .navigationTitle("Account")
        .inlineNavigationTitle()
        .toolbar {
            ToolbarItem(placement: toolbarTrailingPlacement) {
                NavigationLink {
                    SettingsView()
                } label: {
                    Image(systemName: "gearshape.fill")
                        .foregroundStyle(AppConstants.Colors.accent)
                }
            }
        }
        .sheet(isPresented: $showLogin) {
            LoginView()
        }
        .onChange(of: auth.authState) { _, newState in
            // Dismiss login when auth succeeds (sheet doesn’t auto-close; avoids stale error banner over a signed-in session).
            if case .signedIn = newState {
                showLogin = false
            }
        }
        #if os(iOS)
        .fullScreenCover(isPresented: $showAdmin) { AdminView() }
        #else
        .sheet(isPresented: $showAdmin) {
            AdminView()
                .frame(minWidth: 720, maxWidth: 880, minHeight: 600, maxHeight: 800)
        }
        #endif
    }
    
    private var signedOutView: some View {
        ScrollView {
            VStack(spacing: 0) {
                signInCard
                legalLinksCard
            }
            .padding(.horizontal, AppConstants.Layout.screenHorizontalPadding)
            .padding(.top, 32)
            .padding(.bottom, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var signInCard: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .fill(AppConstants.Colors.accent.opacity(0.12))
                    .frame(width: 100, height: 100)
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 72))
                    .foregroundStyle(AppConstants.Colors.accent.opacity(0.9))
            }
            VStack(spacing: 8) {
                Text("Your Account")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundStyle(AppConstants.Colors.textPrimary)
                Text("Sign in to see your orders, rewards, and more.")
                    .font(.subheadline)
                    .foregroundStyle(AppConstants.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            PrimaryButton(title: "Sign In") {
                showLogin = true
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.vertical, 32)
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity)
        .background(AppConstants.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppConstants.Layout.cardCornerRadius))
    }

    private var legalLinksCard: some View {
        VStack(spacing: 0) {
            NavigationLink {
                SettingsView()
            } label: {
                rowLabel("Settings", systemImage: "gearshape.fill")
            }
            Divider()
                .padding(.leading, 44)
            NavigationLink {
                DocumentView(title: "Privacy Policy", markdown: LegalContent.privacyPolicyMarkdown)
            } label: {
                rowLabel("Privacy Policy", systemImage: "lock.shield")
            }
            Divider()
                .padding(.leading, 44)
            NavigationLink {
                DocumentView(title: "Terms of Service", markdown: LegalContent.termsOfServiceMarkdown)
            } label: {
                rowLabel("Terms of Service", systemImage: "doc.text")
            }
        }
        .padding(.vertical, 8)
        .background(AppConstants.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppConstants.Layout.cardCornerRadius))
        .padding(.top, 20)
    }

    private func rowLabel(_ title: String, systemImage: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.subheadline)
                .foregroundStyle(AppConstants.Colors.accent)
                .frame(width: 24, alignment: .center)
            Text(title)
                .font(.subheadline)
                .foregroundStyle(AppConstants.Colors.textPrimary)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppConstants.Colors.textSecondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
    
    private func signedInView(user: VercelUser) -> some View {
        ScrollView {
            VStack(spacing: 0) {
                VStack(spacing: 20) {
                    ZStack {
                        Circle()
                            .fill(AppConstants.Colors.accent.opacity(0.12))
                            .frame(width: 100, height: 100)
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 72))
                            .foregroundStyle(AppConstants.Colors.accent.opacity(0.9))
                    }
                    VStack(spacing: 6) {
                        Text(user.displayName ?? user.email ?? "Signed in")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundStyle(AppConstants.Colors.textPrimary)
                        if let email = user.email {
                            Text(email)
                                .font(.subheadline)
                                .foregroundStyle(AppConstants.Colors.textSecondary)
                        }
                        if let rawPhone = auth.userProfile?.phone ?? user.phone {
                            let phoneShown = rawPhone.trimmingCharacters(in: .whitespacesAndNewlines)
                            if !phoneShown.isEmpty {
                                Text(phoneShown)
                                    .font(.subheadline)
                                    .foregroundStyle(AppConstants.Colors.textSecondary)
                            }
                        }
                    }
                    if auth.isAdmin {
                        Button {
                            showAdmin = true
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "shield.checkered")
                                Text("Admin Dashboard")
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(AppConstants.Colors.accent.opacity(0.15))
                            .foregroundStyle(AppConstants.Colors.accent)
                            .clipShape(RoundedRectangle(cornerRadius: AppConstants.Layout.buttonCornerRadius))
                        }
                        .buttonStyle(.plain)
                    }
                    PrimaryButton(title: "Sign Out") {
                        try? auth.signOut()
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding(.vertical, 28)
                .padding(.horizontal, 24)
                .frame(maxWidth: .infinity)
                .background(AppConstants.Colors.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: AppConstants.Layout.cardCornerRadius))

                NavigationLink {
                    ContactRepliesView()
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "envelope.badge")
                            .font(.subheadline)
                            .foregroundStyle(AppConstants.Colors.accent)
                            .frame(width: 24, alignment: .center)
                        Text("Messages")
                            .font(.subheadline)
                            .foregroundStyle(AppConstants.Colors.textPrimary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AppConstants.Colors.textSecondary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                }
                .padding(.top, 20)
                .background(AppConstants.Colors.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: AppConstants.Layout.cardCornerRadius))

                legalLinksCard
                    .padding(.top, 20)
            }
            .padding(.horizontal, AppConstants.Layout.screenHorizontalPadding)
            .padding(.top, 32)
            .padding(.bottom, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

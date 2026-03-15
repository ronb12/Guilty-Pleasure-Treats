//
//  ProfileView.swift
//  Guilty Pleasure Treats
//
//  Shows sign-in prompt or user info and sign out.
//

import SwiftUI
import FirebaseAuth

struct ProfileView: View {
    @StateObject private var auth = AuthService.shared
    @State private var showLogin = false
    
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
        .navigationTitle("Account")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
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
    }
    
    private var signedOutView: some View {
        VStack(spacing: 20) {
            Image(systemName: "person.circle")
                .font(.system(size: 60))
                .foregroundStyle(AppConstants.Colors.textSecondary)
            Text("Sign in to see your orders")
                .font(.subheadline)
                .foregroundStyle(AppConstants.Colors.textSecondary)
            PrimaryButton(title: "Sign In") {
                showLogin = true
            }
            .frame(maxWidth: 280)
            legalLinks
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func signedInView(user: FirebaseAuth.User) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "person.circle.fill")
                .font(.system(size: 60))
                .foregroundStyle(AppConstants.Colors.accent)
            Text(user.displayName ?? user.email ?? "Signed in")
                .font(.headline)
                .foregroundStyle(AppConstants.Colors.textPrimary)
            if let email = user.email {
                Text(email)
                    .font(.subheadline)
                    .foregroundStyle(AppConstants.Colors.textSecondary)
            }
            PrimaryButton(title: "Sign Out") {
                try? auth.signOut()
            }
            .frame(maxWidth: 280)
            legalLinks
            Spacer()
        }
        .padding(.top, 40)
    }

    private var legalLinks: some View {
        VStack(spacing: 12) {
            NavigationLink {
                SettingsView()
            } label: {
                Label("Settings", systemImage: "gearshape.fill")
                    .font(.subheadline)
                    .foregroundStyle(AppConstants.Colors.accent)
            }
            .padding(.top, 4)
            NavigationLink("Privacy Policy") {
                DocumentView(title: "Privacy Policy", markdown: LegalContent.privacyPolicyMarkdown)
            }
            .font(.subheadline)
            .foregroundStyle(AppConstants.Colors.accent)
            NavigationLink("Terms of Service") {
                DocumentView(title: "Terms of Service", markdown: LegalContent.termsOfServiceMarkdown)
            }
            .font(.subheadline)
            .foregroundStyle(AppConstants.Colors.accent)
        }
        .padding(.top, 8)
    }
}

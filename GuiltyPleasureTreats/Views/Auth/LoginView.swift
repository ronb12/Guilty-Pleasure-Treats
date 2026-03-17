//
//  LoginView.swift
//  Guilty Pleasure Treats
//
//  Email/password sign in and sign up. Professional layout: header, form card.
//

import SwiftUI

struct LoginView: View {
    @State private var email = ""
    @State private var password = ""
    @State private var displayName = ""
    @State private var isSignUp = false
    @State private var isLoading = false
    @State private var errorMessage: String?
    @Environment(\.dismiss) private var dismiss

    private let auth = AuthService.shared

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    headerSection
                    if let msg = errorMessage {
                        ErrorMessageBanner(message: msg) { errorMessage = nil }
                    }
                    formCard
                    toggleAuthModeLink
                }
                .padding(.horizontal, AppConstants.Layout.screenHorizontalPadding)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(AppConstants.Colors.secondary)
            .navigationTitle(isSignUp ? "Sign Up" : "Sign In")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .fontWeight(.medium)
                    .foregroundStyle(AppConstants.Colors.accent)
                }
            }
        }
    }

    private var headerSection: some View {
        VStack(spacing: 8) {
            Image("HomeLogo")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 64, height: 64)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            Text("Guilty Pleasure Treats")
                .font(.title2.weight(.semibold))
                .foregroundStyle(AppConstants.Colors.textPrimary)
            Text(isSignUp ? "Create your account to save orders and earn rewards." : "Sign in to view orders, rewards, and more.")
                .font(.subheadline)
                .foregroundStyle(AppConstants.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 16)
    }

    private var formCard: some View {
        VStack(alignment: .leading, spacing: 20) {
            emailField
            passwordField
            if isSignUp {
                displayNameField
            }
            PrimaryButton(
                title: isSignUp ? "Create Account" : "Sign In",
                action: { Task { await submit() } },
                isLoading: isLoading
            )
        }
        .padding(AppConstants.Layout.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppConstants.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppConstants.Layout.cardCornerRadius))
        .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
    }

    private var emailField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Email")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(AppConstants.Colors.textPrimary)
            TextField("you@example.com", text: $email)
                .textFieldStyle(LoginTextFieldStyle())
                .textInputAutocapitalization(.never)
                .keyboardType(.emailAddress)
                .textContentType(.emailAddress)
        }
    }

    private var passwordField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Password")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(AppConstants.Colors.textPrimary)
            SecureField(isSignUp ? "At least 6 characters" : "Password", text: $password)
                .textFieldStyle(LoginTextFieldStyle())
                .textContentType(isSignUp ? .newPassword : .password)
        }
    }

    private var displayNameField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Display name (optional)")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(AppConstants.Colors.textPrimary)
            TextField("How we'll greet you", text: $displayName)
                .textFieldStyle(LoginTextFieldStyle())
        }
    }

    private var toggleAuthModeLink: some View {
        Button {
            isSignUp.toggle()
            errorMessage = nil
        } label: {
            (Text(isSignUp ? "Already have an account? " : "Need an account? ")
                .foregroundStyle(AppConstants.Colors.textSecondary)
             + Text(isSignUp ? "Sign in" : "Sign up")
                .foregroundStyle(AppConstants.Colors.accent)
                .fontWeight(.semibold)
             + Text(isSignUp ? "" : " to create an account.")
                .foregroundStyle(AppConstants.Colors.textSecondary))
        }
        .font(.subheadline)
    }

    private func submit() async {
        guard !email.isEmpty, !password.isEmpty else {
            errorMessage = "Enter email and password."
            return
        }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            if isSignUp {
                try await auth.signUp(email: email, password: password, displayName: displayName.isEmpty ? nil : displayName)
            } else {
                try await auth.signIn(email: email, password: password)
            }
            dismiss()
        } catch {
            let msg = error.localizedDescription
            if msg == "Invalid email or password" {
                errorMessage = msg + " No account? Tap \"Need an account? Sign up\" to create one."
            } else {
                errorMessage = msg
            }
        }
    }
}

// MARK: - Login form text field style
private struct LoginTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

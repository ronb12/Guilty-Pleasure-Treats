//
//  LoginView.swift
//  Guilty Pleasure Treats
//
//  Email/password sign in and sign up; Sign in with Apple (App Store Guideline 4.8).
//  Professional layout: header, form card, Sign in with Apple.
//

import SwiftUI
import AuthenticationServices
import CryptoKit

struct LoginView: View {
    @State private var email = ""
    @State private var password = ""
    @State private var displayName = ""
    @State private var phone = ""
    @State private var isSignUp = false
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var currentNonce: String?
    @State private var showForgotPassword = false
    @State private var resetToken: String?
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
                    orDivider
                    appleSignInSection
                    toggleAuthModeLink
                }
                .padding(.horizontal, AppConstants.Layout.screenHorizontalPadding)
                .padding(.top, 8)
                .padding(.bottom, 32)
                .macOSSheetTopPadding()
            }
            .scrollDismissesKeyboard(.interactively)
            .background(AppConstants.Colors.secondary)
            .navigationTitle(isSignUp ? "Sign Up" : "Sign In")
            .inlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .fontWeight(.medium)
                    .foregroundStyle(AppConstants.Colors.accent)
                }
            }
            .sheet(isPresented: $showForgotPassword) {
                if let token = resetToken {
                    ResetPasswordView(token: token) {
                        resetToken = nil
                        showForgotPassword = false
                    }
                } else {
                    ForgotPasswordView(
                        onToken: { resetToken = $0 },
                        onDismiss: { showForgotPassword = false }
                    )
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
            if !isSignUp {
                Text("Email & password")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(AppConstants.Colors.textSecondary)
            }
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
            if !isSignUp {
                Button("Forgot password?") {
                    showForgotPassword = true
                    resetToken = nil
                }
                .font(.subheadline)
                .foregroundStyle(AppConstants.Colors.accent)
            }
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
                #if os(iOS)
                .textInputAutocapitalization(.never)
                .keyboardType(.emailAddress)
                #endif
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

    private var nameField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Your name")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(AppConstants.Colors.textPrimary)
            TextField("e.g. Jordan Smith", text: $displayName)
                .textFieldStyle(LoginTextFieldStyle())
                #if os(iOS)
                .textContentType(.name)
                .textInputAutocapitalization(.words)
                #endif
        }
    }

    private var phoneField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Phone number")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(AppConstants.Colors.textPrimary)
            TextField("(555) 123-4567", text: $phone)
                .textFieldStyle(LoginTextFieldStyle())
                #if os(iOS)
                .keyboardType(.phonePad)
                .textContentType(.telephoneNumber)
                #endif
        }
    }

    private var orDivider: some View {
        HStack(spacing: 12) {
            Rectangle()
                .fill(AppConstants.Colors.textSecondary.opacity(0.3))
                .frame(height: 1)
            Text("or")
                .font(.caption.weight(.medium))
                .foregroundStyle(AppConstants.Colors.textSecondary)
            Rectangle()
                .fill(AppConstants.Colors.textSecondary.opacity(0.3))
                .frame(height: 1)
        }
    }

    private var appleSignInSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SignInWithAppleButton(.signIn) { request in
                currentNonce = randomNonceString()
                request.requestedScopes = [.fullName, .email]
                request.nonce = sha256(currentNonce!)
            } onCompletion: { result in
                Task { await handleSignInWithApple(result) }
            }
            .signInWithAppleButtonStyle(.black)
            .frame(height: 52)
            Text("Use the same account with either email/password or Sign in with Apple.")
                .font(.caption)
                .foregroundStyle(AppConstants.Colors.textSecondary)
        }
    }

    private var toggleAuthModeLink: some View {
        Button {
            isSignUp.toggle()
            errorMessage = nil
            if !isSignUp { phone = "" }
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
    
    private func handleSignInWithApple(_ result: Result<ASAuthorization, Error>) async {
        switch result {
        case .success(let authorization):
            guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential,
                  let idTokenData = appleIDCredential.identityToken,
                  let idToken = String(data: idTokenData, encoding: .utf8),
                  let rawNonce = currentNonce else {
                let msg = "Unable to get Apple credentials."
                debugLog("[Auth] Sign in with Apple: \(msg)")
                errorMessage = msg
                return
            }
            do {
                try await auth.signInWithApple(idToken: idToken, rawNonce: rawNonce, fullName: appleIDCredential.fullName)
                dismiss()
            } catch {
                debugLog("[Auth] Sign in with Apple error: \(error)")
                if let apiErr = error as? VercelAPIError {
                    debugLog("[Auth]   statusCode=\(String(describing: apiErr.statusCode)) message=\(apiErr.message)")
                }
                errorMessage = FriendlyErrorMessage.message(for: error)
            }
        case .failure(let err):
            if (err as NSError).code != ASAuthorizationError.canceled.rawValue {
                debugLog("[Auth] Sign in with Apple failure: \(err)")
                errorMessage = FriendlyErrorMessage.message(for: err)
            }
        }
    }
    
    private func submit() async {
        guard !email.isEmpty, !password.isEmpty else {
            debugLog("[Auth] submit: email or password empty")
            errorMessage = "Enter email and password."
            return
        }
        if isSignUp {
            let nameOk = !displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            let phoneOk = !phone.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            guard nameOk, phoneOk else {
                errorMessage = "Enter your name and phone number."
                return
            }
        }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            if isSignUp {
                try await auth.signUp(
                    email: email,
                    password: password,
                    displayName: displayName.trimmingCharacters(in: .whitespacesAndNewlines),
                    phone: phone.trimmingCharacters(in: .whitespacesAndNewlines)
                )
            } else {
                try await auth.signIn(email: email, password: password)
            }
            dismiss()
        } catch {
            debugLog("[Auth] submit error: \(error)")
            errorMessage = FriendlyErrorMessage.message(for: error)
        }
    }
}

private func debugLog(_ message: String) {
    #if DEBUG
    print(message)
    #endif
}

// MARK: - Login form text field style (shared with ForgotPasswordView, ResetPasswordView)
struct LoginTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(platformSystemGrayBackground)
            .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

private func randomNonceString(length: Int = 32) -> String {
    precondition(length > 0)
    let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz")
    var result = ""
    var remaining = length
    while remaining > 0 {
        let randoms: [UInt8] = (0..<16).map { _ in UInt8.random(in: 0...255) }
        randoms.forEach { random in
            if remaining > 0, random < charset.count {
                result.append(charset[Int(random)])
                remaining -= 1
            }
        }
    }
    return result
}

private func sha256(_ input: String) -> String {
    let data = Data(input.utf8)
    let hash = SHA256.hash(data: data)
    return hash.compactMap { String(format: "%02x", $0) }.joined()
}

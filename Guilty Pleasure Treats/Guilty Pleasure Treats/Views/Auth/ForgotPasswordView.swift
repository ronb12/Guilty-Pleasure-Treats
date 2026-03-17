//
//  ForgotPasswordView.swift
//  Guilty Pleasure Treats
//
//  Enter email to receive a password reset (in-app; token used on next screen).
//

import SwiftUI

struct ForgotPasswordView: View {
    @State private var email = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var successMessage: String?
    @Environment(\.dismiss) private var dismiss

    var onToken: (String) -> Void = { _ in }
    var onDismiss: () -> Void = { }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    if let msg = errorMessage {
                        ErrorMessageBanner(message: msg) { errorMessage = nil }
                    }
                    if let msg = successMessage {
                        Text(msg)
                            .font(.subheadline)
                            .foregroundStyle(AppConstants.Colors.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding()
                    }
                    if successMessage != nil {
                        Button("Back to sign in") {
                            onDismiss()
                            dismiss()
                        }
                        .fontWeight(.medium)
                        .foregroundStyle(AppConstants.Colors.accent)
                    }
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Enter the email for your account. We’ll let you set a new password in the next step.")
                            .font(.subheadline)
                            .foregroundStyle(AppConstants.Colors.textSecondary)
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Email")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(AppConstants.Colors.textPrimary)
                            TextField("you@example.com", text: $email)
                                .textFieldStyle(AuthTextFieldStyle())
                                #if os(iOS)
                                .textInputAutocapitalization(.never)
                                .keyboardType(.emailAddress)
                                #endif
                                .textContentType(.emailAddress)
                        }
                        PrimaryButton(
                            title: "Continue",
                            action: { Task { await submit() } },
                            isLoading: isLoading
                        )
                    }
                    .padding(AppConstants.Layout.cardPadding)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(AppConstants.Colors.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: AppConstants.Layout.cardCornerRadius))
                }
                .padding(.horizontal, AppConstants.Layout.screenHorizontalPadding)
                .padding(.top, 24)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(AppConstants.Colors.secondary)
            .navigationTitle("Forgot password")
            .inlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onDismiss()
                        dismiss()
                    }
                    .fontWeight(.medium)
                    .foregroundStyle(AppConstants.Colors.accent)
                }
            }
        }
    }
}

private struct AuthTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(platformSystemGrayBackground)
            .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

private extension ForgotPasswordView {
    func submit() async {
        let trimmed = email.trimmingCharacters(in: .whitespaces).lowercased()
        guard !trimmed.isEmpty else {
            errorMessage = "Enter your email."
            return
        }
        isLoading = true
        errorMessage = nil
        successMessage = nil
        defer { isLoading = false }
        do {
            if let token = try await AuthService.shared.requestPasswordReset(email: trimmed) {
                onToken(token)
            } else {
                successMessage = "No password reset is available for this email. Try Sign in with Apple if you use that, or create a new account."
            }
        } catch {
            errorMessage = FriendlyErrorMessage.message(for: error)
        }
    }
}

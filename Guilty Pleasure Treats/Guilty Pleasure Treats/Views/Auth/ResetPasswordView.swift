//
//  ResetPasswordView.swift
//  Guilty Pleasure Treats
//
//  Set new password using the token from ForgotPasswordView.
//

import SwiftUI

struct ResetPasswordView: View {
    let token: String
    var onSuccess: () -> Void = { }

    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    if let msg = errorMessage {
                        ErrorMessageBanner(message: msg) { errorMessage = nil }
                    }
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Enter your new password. It must be at least 6 characters.")
                            .font(.subheadline)
                            .foregroundStyle(AppConstants.Colors.textSecondary)
                        VStack(alignment: .leading, spacing: 6) {
                            Text("New password")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(AppConstants.Colors.textPrimary)
                            SecureField("At least 6 characters", text: $newPassword)
                                .textFieldStyle(AuthTextFieldStyle())
                                .textContentType(.newPassword)
                        }
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Confirm password")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(AppConstants.Colors.textPrimary)
                            SecureField("Repeat new password", text: $confirmPassword)
                                .textFieldStyle(AuthTextFieldStyle())
                                .textContentType(.newPassword)
                        }
                        PrimaryButton(
                            title: "Set new password",
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
            .navigationTitle("Set new password")
            .inlineNavigationTitle()
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

private extension ResetPasswordView {
    func submit() async {
        guard newPassword.count >= 6 else {
            errorMessage = "Password must be at least 6 characters."
            return
        }
        guard newPassword == confirmPassword else {
            errorMessage = "Passwords don’t match."
            return
        }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            try await AuthService.shared.resetPassword(token: token, newPassword: newPassword)
            onSuccess()
            dismiss()
        } catch {
            errorMessage = FriendlyErrorMessage.message(for: error)
        }
    }
}

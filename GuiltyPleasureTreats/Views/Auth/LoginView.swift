//
//  LoginView.swift
//  Guilty Pleasure Treats
//
//  Email/password sign in and sign up.
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
                VStack(spacing: 20) {
                    if let msg = errorMessage {
                        ErrorMessageBanner(message: msg) { errorMessage = nil }
                    }
                    TextField("Email", text: $email)
                        .textFieldStyle(.roundedBorder)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                    SecureField("Password", text: $password)
                        .textFieldStyle(.roundedBorder)
                    if isSignUp {
                        TextField("Display name (optional)", text: $displayName)
                            .textFieldStyle(.roundedBorder)
                    }
                    PrimaryButton(
                        title: isSignUp ? "Create Account" : "Sign In",
                        action: { Task { await submit() } },
                        isLoading: isLoading
                    )
                    Button(isSignUp ? "Already have an account? Sign in" : "Need an account? Sign up") {
                        isSignUp.toggle()
                        errorMessage = nil
                    }
                    .font(.subheadline)
                    .foregroundStyle(AppConstants.Colors.accent)
                }
                .padding()
            }
            .background(AppConstants.Colors.secondary)
            .navigationTitle(isSignUp ? "Sign Up" : "Sign In")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
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
            errorMessage = error.localizedDescription
        }
    }
}

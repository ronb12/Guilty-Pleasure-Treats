//
//  AuthService.swift
//  Guilty Pleasure Treats
//
//  Vercel/Neon authentication. Same call pattern as Firebase: signIn/signUp with email and password,
//  single async throw, Firebase-style error messages.
//

import Foundation
import Combine
import AuthenticationServices

private let tokenKey = "com.guiltypleasuretreats.authToken"

/// Auth errors using Firebase-style messages (mirrors Firebase Auth error copy).
enum AuthError: LocalizedError {
    case invalidEmail
    case wrongPassword
    case userNotFound
    case emailAlreadyInUse
    case weakPassword
    case useAppleSignIn
    case network(underlying: Error)
    case server(String)

    var errorDescription: String? {
        switch self {
        case .invalidEmail:
            return "The email address is badly formatted."
        case .wrongPassword:
            return "The password is invalid or the user does not have a password."
        case .userNotFound:
            return "There is no user record corresponding to this identifier. The user may have been deleted."
        case .emailAlreadyInUse:
            return "The email address is already in use by another account."
        case .weakPassword:
            return "The password must be 6 characters long or more."
        case .useAppleSignIn:
            return "This account was created with Sign in with Apple. Use the \"Sign in with Apple\" button to sign in."
        case .network(let underlying):
            return (underlying as NSError).localizedDescription
        case .server(let message):
            return message.isEmpty ? "Something went wrong. Please try again." : message
        }
    }
}

/// Auth state for the app.
enum AuthState: Equatable {
    case loading
    case signedIn(VercelUser)
    case signedOut
}

final class AuthService: ObservableObject {
    static let shared = AuthService()
    @Published private(set) var authState: AuthState = .loading
    @Published private(set) var userProfile: UserProfile?

    var currentUser: VercelUser? {
        guard case .signedIn(let user) = authState else { return nil }
        return user
    }

    var isAdmin: Bool { userProfile?.isAdmin ?? false }

    private init() {
        Task { @MainActor in
            await restoreSession()
        }
    }

    /// Restore session from stored token.
    @MainActor
    private func restoreSession() async {
        guard VercelService.isConfigured else {
            debugLog("[Auth] restoreSession: Vercel not configured, signed out")
            authState = .signedOut
            userProfile = nil
            return
        }
        let token = UserDefaults.standard.string(forKey: tokenKey)
        guard let token = token else {
            debugLog("[Auth] restoreSession: no stored token, signed out")
            authState = .signedOut
            userProfile = nil
            return
        }
        VercelService.shared.authToken = token
        do {
            if let profile = try await VercelService.shared.fetchUserProfileWithToken(token) {
                debugLog("[Auth] restoreSession: success uid=\(profile.uid)")
                userProfile = profile
                authState = .signedIn(VercelUser(uid: profile.uid, email: profile.email, displayName: profile.displayName, phone: profile.phone))
            } else {
                debugLog("[Auth] restoreSession: fetchUserProfileWithToken returned nil (401 or invalid response)")
                UserDefaults.standard.removeObject(forKey: tokenKey)
                VercelService.shared.authToken = nil
                authState = .signedOut
                userProfile = nil
            }
        } catch {
            debugLog("[Auth] restoreSession error: \(error)")
            UserDefaults.standard.removeObject(forKey: tokenKey)
            VercelService.shared.authToken = nil
            authState = .signedOut
            userProfile = nil
        }
    }

    private func saveToken(_ token: String) {
        UserDefaults.standard.set(token, forKey: tokenKey)
        VercelService.shared.authToken = token
    }

    private func clearToken() {
        UserDefaults.standard.removeObject(forKey: tokenKey)
        VercelService.shared.authToken = nil
    }

    /// Sign in with email and password. Same pattern as Firebase: one async call, throws on failure with Firebase-style error messages.
    @MainActor
    func signIn(email: String, password: String) async throws {
        guard let url = apiURL(pathComponents: "api", "auth", "login") else {
            debugLog("[Auth] signIn: vercelBaseURL nil")
            throw VercelNotConfiguredError()
        }
        debugLog("[Auth] signIn: POST \(url.absoluteString)")
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONEncoder().encode(["email": email, "password": password])
        let (data, res): (Data, URLResponse)
        do {
            (data, res) = try await URLSession.shared.data(for: req)
        } catch {
            debugLog("[Auth] signIn network error: \(error)")
            throw AuthError.server(Self.networkErrorMessage(for: error))
        }
        guard let http = res as? HTTPURLResponse else {
            debugLog("[Auth] signIn: response not HTTPURLResponse")
            throw AuthError.server("Invalid response")
        }
        guard (200...299).contains(http.statusCode) else {
            let err = (try? JSONDecoder().decode([String: String].self, from: data))?["error"] ?? "Sign in failed"
            let code = (try? JSONDecoder().decode([String: String].self, from: data))?["code"]
            let bodyPreview = String(data: data, encoding: .utf8).map { String($0.prefix(200)) } ?? "nil"
            debugLog("[Auth] signIn failed: status=\(http.statusCode) error=\(err) body=\(bodyPreview)")
            throw Self.authError(from: err, code: code, statusCode: http.statusCode)
        }
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let token = json?["token"] as? String, let user = json?["user"] as? [String: Any],
              let uid = parseUid(user["uid"]) else {
            let hasToken = (json?["token"] != nil)
            let hasUser = (json?["user"] != nil)
            let uidVal = (json?["user"] as? [String: Any])?["uid"]
            debugLog("[Auth] signIn: invalid response shape hasToken=\(hasToken) hasUser=\(hasUser) uid=\(String(describing: uidVal))")
            throw AuthError.server("Invalid response from server. Please try again.")
        }
        debugLog("[Auth] signIn success uid=\(uid)")
        saveToken(token)
        userProfile = UserProfile(
            uid: uid,
            email: user["email"] as? String,
            displayName: user["displayName"] as? String,
            phone: user["phone"] as? String,
            isAdmin: (user["isAdmin"] as? Bool) ?? false,
            points: (user["points"] as? Int) ?? 0,
            createdAt: Date(),
            completedOrderCount: 0,
            marketingEmailOptIn: true,
            foodAllergies: user["foodAllergies"] as? String
        )
        authState = .signedIn(VercelUser(uid: uid, email: user["email"] as? String, displayName: user["displayName"] as? String, phone: user["phone"] as? String))
        Task { @MainActor in
            await NotificationService.shared.registerPushTokenWithBackend()
            await refreshProfile()
        }
    }

    /// Create account with email and password. Same pattern as Firebase: one async call, throws on failure with Firebase-style error messages.
    func signUp(email: String, password: String, displayName: String?, phone: String, foodAllergies: String? = nil) async throws {
        guard let url = apiURL(pathComponents: "api", "auth", "signup") else {
            debugLog("[Auth] signUp: vercelBaseURL nil")
            throw VercelNotConfiguredError()
        }
        debugLog("[Auth] signUp: POST \(url.absoluteString)")
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        var body: [String: Any] = ["email": email, "password": password, "phone": phone]
        if let n = displayName { body["displayName"] = n }
        if let a = foodAllergies?.trimmingCharacters(in: .whitespacesAndNewlines), !a.isEmpty {
            body["foodAllergies"] = a
        }
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, res): (Data, URLResponse)
        do {
            (data, res) = try await URLSession.shared.data(for: req)
        } catch {
            debugLog("[Auth] signUp network error: \(error)")
            throw AuthError.server(Self.networkErrorMessage(for: error))
        }
        guard let http = res as? HTTPURLResponse else {
            debugLog("[Auth] signUp: response not HTTPURLResponse")
            throw AuthError.server("Invalid response")
        }
        guard (200...299).contains(http.statusCode) else {
            let err = (try? JSONDecoder().decode([String: String].self, from: data))?["error"] ?? "Sign up failed"
            let bodyPreview = String(data: data, encoding: .utf8).map { String($0.prefix(200)) } ?? "nil"
            debugLog("[Auth] signUp failed: status=\(http.statusCode) error=\(err) body=\(bodyPreview)")
            throw Self.authError(from: err, code: nil, statusCode: http.statusCode)
        }
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let token = json?["token"] as? String, let user = json?["user"] as? [String: Any],
              let uid = parseUid(user["uid"]) else {
            let hasToken = (json?["token"] != nil)
            let hasUser = (json?["user"] != nil)
            debugLog("[Auth] signUp: invalid response shape hasToken=\(hasToken) hasUser=\(hasUser)")
            throw AuthError.server("Invalid response from server. Please try again.")
        }
        debugLog("[Auth] signUp success uid=\(uid)")
        saveToken(token)
        userProfile = UserProfile(
            uid: uid,
            email: user["email"] as? String,
            displayName: user["displayName"] as? String,
            phone: user["phone"] as? String,
            isAdmin: false,
            points: 0,
            createdAt: Date(),
            completedOrderCount: 0,
            marketingEmailOptIn: true,
            foodAllergies: user["foodAllergies"] as? String
        )
        authState = .signedIn(VercelUser(uid: uid, email: user["email"] as? String, displayName: user["displayName"] as? String, phone: user["phone"] as? String))
        Task { @MainActor in await NotificationService.shared.registerPushTokenWithBackend() }
    }

    /// Request password reset for email. Returns reset token if account exists and has password; use with resetPassword(token:newPassword:).
    func requestPasswordReset(email: String) async throws -> String? {
        try await VercelService.shared.requestPasswordReset(email: email)
    }

    /// Set new password using token from requestPasswordReset. Then user can sign in with the new password.
    func resetPassword(token: String, newPassword: String) async throws {
        try await VercelService.shared.resetPassword(token: token, newPassword: newPassword)
    }

    /// Delete account and all associated data (App Store requirement). Signs out locally after.
    func deleteAccount() async throws {
        try await VercelService.shared.deleteAccount()
        clearToken()
        userProfile = nil
        authState = .signedOut
    }

    /// Sign out.
    func signOut() throws {
        if let url = apiURL(pathComponents: "api", "auth", "logout"), let token = VercelService.shared.authToken {
            var req = URLRequest(url: url)
            req.httpMethod = "POST"
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            URLSession.shared.dataTask(with: req) { _, _, _ in }.resume()
        }
        clearToken()
        userProfile = nil
        authState = .signedOut
    }

    /// Anonymous sign-in: create a guest session (optional; not implemented in Vercel auth).
    func signInAnonymously() async throws {
        authState = .signedOut
        userProfile = nil
    }

    /// Sign in with Apple: send identity token to Vercel.
    @MainActor
    func signInWithApple(idToken: String, rawNonce: String, fullName: PersonNameComponents?) async throws {
        guard let url = apiURL(pathComponents: "api", "auth", "apple") else {
            debugLog("[Auth] signInWithApple: vercelBaseURL nil")
            throw VercelNotConfiguredError()
        }
        debugLog("[Auth] signInWithApple: POST \(url.absoluteString)")
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        var body: [String: Any] = ["identityToken": idToken, "rawNonce": rawNonce]
        if let fn = fullName {
            body["fullName"] = ["givenName": fn.givenName ?? "", "familyName": fn.familyName ?? ""]
        }
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, res): (Data, URLResponse)
        do {
            (data, res) = try await URLSession.shared.data(for: req)
        } catch {
            debugLog("[Auth] signInWithApple network error: \(error)")
            throw VercelAPIError(message: Self.networkErrorMessage(for: error))
        }
        guard let http = res as? HTTPURLResponse else {
            debugLog("[Auth] signInWithApple: response not HTTPURLResponse")
            throw VercelAPIError(message: "Invalid response")
        }
        guard (200...299).contains(http.statusCode) else {
            let err = (try? JSONDecoder().decode([String: String].self, from: data))?["error"] ?? "Sign in with Apple failed"
            let bodyPreview = String(data: data, encoding: .utf8).map { String($0.prefix(200)) } ?? "nil"
            debugLog("[Auth] signInWithApple failed: status=\(http.statusCode) error=\(err) body=\(bodyPreview)")
            throw VercelAPIError(message: err, statusCode: http.statusCode)
        }
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let token = json?["token"] as? String, let user = json?["user"] as? [String: Any],
              let uid = parseUid(user["uid"]) else {
            let hasToken = (json?["token"] != nil)
            let hasUser = (json?["user"] != nil)
            debugLog("[Auth] signInWithApple: invalid response shape hasToken=\(hasToken) hasUser=\(hasUser)")
            throw VercelAPIError(message: "Invalid response from server. Please try again.")
        }
        debugLog("[Auth] signInWithApple success uid=\(uid)")
        saveToken(token)
        userProfile = UserProfile(
            uid: uid,
            email: user["email"] as? String,
            displayName: user["displayName"] as? String,
            phone: user["phone"] as? String,
            isAdmin: (user["isAdmin"] as? Bool) ?? false,
            points: (user["points"] as? Int) ?? 0,
            foodAllergies: user["foodAllergies"] as? String,
            createdAt: Date()
        )
        authState = .signedIn(VercelUser(uid: uid, email: user["email"] as? String, displayName: user["displayName"] as? String, phone: user["phone"] as? String))
        Task { @MainActor in await NotificationService.shared.registerPushTokenWithBackend() }
    }

    /// Update food allergies on the server and refresh local profile.
    func saveFoodAllergies(_ text: String?) async throws {
        guard var profile = userProfile else { return }
        let trimmed = text?.trimmingCharacters(in: .whitespacesAndNewlines)
        profile.foodAllergies = (trimmed?.isEmpty == false) ? trimmed : nil
        try await VercelService.shared.setUserProfile(profile)
        await refreshProfile()
    }

    /// Refresh user profile from API (e.g. after points change).
    func refreshProfile() async {
        guard case .signedIn(let user) = authState else { return }
        do {
            if let profile = try await VercelService.shared.fetchUserProfile(uid: user.uid) {
                userProfile = profile
                authState = .signedIn(VercelUser(uid: profile.uid, email: profile.email, displayName: profile.displayName, phone: profile.phone))
            } else {
                userProfile = nil
            }
        } catch {
            userProfile = nil
        }
    }

    private var vercelBaseURL: URL? {
        guard let s = AppConstants.vercelBaseURLString?.trimmingCharacters(in: .whitespaces), !s.isEmpty else { return nil }
        return URL(string: s.hasSuffix("/") ? String(s.dropLast()) : s)
    }

    /// Build API URL from path segments (e.g. "api", "auth", "login") so path is /api/auth/login, not /api%2Fauth%2Flogin.
    private func apiURL(pathComponents: String...) -> URL? {
        guard let base = vercelBaseURL else { return nil }
        return pathComponents.reduce(base) { $0.appendingPathComponent($1) }
    }

    /// Parse uid from API response (may be String or number).
    private func parseUid(_ value: Any?) -> String? {
        if let s = value as? String, !s.isEmpty { return s }
        if let n = value as? Int { return String(n) }
        if let n = value as? NSNumber { return n.stringValue }
        return nil
    }

    /// Map API error string and status to Firebase-style AuthError (same messages as Firebase Auth).
    private static func authError(from apiError: String, code: String?, statusCode: Int) -> AuthError {
        let lower = apiError.lowercased()
        if code == "USE_APPLE_SIGNIN" || lower.contains("sign in with apple") {
            return .useAppleSignIn
        }
        if statusCode == 401 {
            return .wrongPassword
        }
        if statusCode == 409 || lower.contains("already in use") || lower.contains("already exists") {
            return .emailAlreadyInUse
        }
        if lower.contains("6 character") || lower.contains("at least 6") || lower.contains("weak") {
            return .weakPassword
        }
        if statusCode == 400 && (lower.contains("valid email") || lower.contains("invalid email") || lower.contains("badly") || lower.contains("email format") || lower.contains("email address")) {
            return .invalidEmail
        }
        return .server(apiError)
    }

    private static func networkErrorMessage(for error: Error) -> String {
        let ns = error as NSError
        if ns.domain == NSURLErrorDomain {
            switch ns.code {
            case NSURLErrorNotConnectedToInternet, NSURLErrorNetworkConnectionLost:
                return "No internet connection. Check your network and try again."
            case NSURLErrorTimedOut:
                return "Request timed out. Please try again."
            case NSURLErrorCannotFindHost, NSURLErrorCannotConnectToHost:
                return "Cannot reach server. Check that the backend URL is correct and try again."
            default:
                break
            }
        }
        return "Connection error: \(error.localizedDescription)"
    }

    private func debugLog(_ message: String) {
        #if DEBUG
        print(message)
        #endif
    }
}

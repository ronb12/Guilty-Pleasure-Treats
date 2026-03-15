//
//  AuthService.swift
//  Guilty Pleasure Treats
//
//  Firebase Authentication and user session management.
//

import Foundation
import FirebaseAuth
import Combine

/// Auth state for the app (signed in, signed out, loading).
enum AuthState {
    case loading
    case signedIn(User)
    case signedOut
}

final class AuthService: ObservableObject {
    static let shared = AuthService()
    @Published private(set) var authState: AuthState = .loading
    @Published private(set) var userProfile: UserProfile?
    
    private var authStateListener: AuthStateDidChangeListenerHandle?
    
    var currentUser: User? {
        guard case .signedIn(let user) = authState else { return nil }
        return user
    }
    
    var isAdmin: Bool { userProfile?.isAdmin ?? false }
    
    private init() {
        setupAuthListener()
    }
    
    private func setupAuthListener() {
        authStateListener = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in
                if let user = user {
                    self?.authState = .signedIn(user)
                    await self?.loadUserProfile(uid: user.uid)
                } else {
                    self?.authState = .signedOut
                    self?.userProfile = nil
                }
            }
        }
    }
    
    @MainActor
    private func loadUserProfile(uid: String) async {
        do {
            userProfile = try await FirebaseService.shared.fetchUserProfile(uid: uid)
        } catch {
            userProfile = nil
        }
    }
    
    /// Sign in with email and password.
    func signIn(email: String, password: String) async throws {
        _ = try await Auth.auth().signIn(withEmail: email, password: password)
    }
    
    /// Create account with email and password.
    func signUp(email: String, password: String, displayName: String?) async throws {
        let result = try await Auth.auth().createUser(withEmail: email, password: password)
        if let name = displayName {
            let changeRequest = result.user.createProfileChangeRequest()
            changeRequest.displayName = name
            try await changeRequest.commitChanges()
        }
        let profile = UserProfile(uid: result.user.uid, email: email, displayName: displayName, isAdmin: false, createdAt: Date())
        try await FirebaseService.shared.setUserProfile(profile)
    }
    
    /// Sign out.
    func signOut() throws {
        try Auth.auth().signOut()
    }
    
    /// Anonymous sign-in for guest checkout (optional).
    func signInAnonymously() async throws {
        _ = try await Auth.auth().signInAnonymously()
    }
    
    deinit {
        if let handle = authStateListener {
            Auth.auth().removeStateDidChangeListener(handle)
        }
    }
}

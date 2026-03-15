//
//  AppConstants.swift
//  Guilty Pleasure Treats
//
//  Central constants for colors, strings, and Firebase/Stripe keys.
//

import SwiftUI

enum AppConstants {
    // MARK: - Firebase Collections
    enum Firestore {
        static let products = "products"
        static let orders = "orders"
        static let users = "users"
        static let customCakeOrders = "customCakeOrders"
        static let aiCakeDesigns = "aiCakeDesigns"
    }
    
    // MARK: - AI Image Generation (configure for your backend)
    /// Backend endpoint that accepts POST {"prompt": "..."} and returns image URL or base64.
    static let imageGenerationBaseURL = "https://your-image-api.com/generate"
    
    /// Support / contact URL for Settings and App Store Connect. Replace with your site or contact page.
    static let supportURLString = "https://www.bradleyvirtualsolutions.com"
    
    /// Business Instagram profile (instagram.com/gp_treats).
    static let instagramURLString = "https://instagram.com/gp_treats"
    
    // MARK: - Design (Soft pastel bakery aesthetic)
    enum Colors {
        static let primary = Color(red: 0.95, green: 0.85, blue: 0.90)
        static let secondary = Color(red: 0.98, green: 0.94, blue: 0.88)
        static let accent = Color(red: 0.75, green: 0.55, blue: 0.65)
        static let textPrimary = Color(red: 0.25, green: 0.20, blue: 0.25)
        static let textSecondary = Color(red: 0.45, green: 0.40, blue: 0.45)
        static let cardBackground = Color.white
        static let promotionBanner = Color(red: 0.90, green: 0.78, blue: 0.82)
    }
    
    // MARK: - Layout
    enum Layout {
        static let cardCornerRadius: CGFloat = 16
        static let buttonCornerRadius: CGFloat = 12
        static let cardPadding: CGFloat = 16
        static let screenHorizontalPadding: CGFloat = 20
    }
    
    // MARK: - Tax (example rate)
    static let taxRate: Double = 0.08
}

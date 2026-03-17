//
//  AppConstants.swift
//  Guilty Pleasure Treats
//
//  Central constants for colors, strings, and Stripe/Vercel.
//

import SwiftUI

enum AppConstants {
    // MARK: - Collection names (for reference; data lives in Neon via Vercel API)
    enum Firestore {
        static let products = "products"
        static let orders = "orders"
        static let users = "users"
        static let customCakeOrders = "customCakeOrders"
        static let aiCakeDesigns = "aiCakeDesigns"
        static let settings = "settings"
        static let promotions = "promotions"
    }
    
    /// Emails that get admin access (set isAdmin in profile on first sign-in). Add your owner email(s).
    /// Example: ["owner@yourbusiness.com"]
    static let ownerEmails: [String] = []
    
    // MARK: - Backend URLs (replace with your endpoints before production)
    /// Vercel deployment base URL. When set, the app uses Vercel for products, orders, and image uploads.
    static let vercelBaseURLString: String? = "https://guilty-pleasure-treats.vercel.app"
    /// Stripe: backend that creates PaymentIntents. Must implement POST /api/stripe/create-payment-intent.
    static let stripeBackendURLString = "https://guilty-pleasure-treats.vercel.app"
    /// Stripe publishable key (pk_test_... or pk_live_...). Required for in-app Payment Sheet. Set to your key from Stripe Dashboard → Developers → API keys; leave nil to disable.
    static let stripePublishableKey: String? = nil
    /// AI Cake Designer: uses Vercel API (DALL-E 3) when Vercel base URL is set. Set OPENAI_API_KEY in Vercel.
    static var imageGenerationBaseURL: String {
        guard let base = vercelBaseURLString?.trimmingCharacters(in: .whitespaces), !base.isEmpty else {
            return "https://your-image-api.com/generate"
        }
        let trimmed = base.hasSuffix("/") ? String(base.dropLast()) : base
        return "\(trimmed)/api/ai/generate-image"
    }
    
    /// Support URL for customers (App Store Connect + Settings). Use the bakery’s site or contact page, not the developer’s.
    static let supportURLString = "https://guilty-pleasure-treats.vercel.app/#contact"
    
    /// Privacy Policy URL. Required for App Store Connect; use a live web page URL.
    static let privacyPolicyURLString = "https://www.bradleyvirtualsolutions.com/privacy"
    
    /// Business contact email. Shown in Settings and used for mailto: links.
    static let contactEmailString = "info@guiltypleasuretreats.com"
    
    /// Business Instagram profile for DMs. Shown in Settings and Contact.
    static let instagramURLString = "https://www.instagram.com/gp_treats"
    
    // MARK: - Design (Pink bakery theme; light/dark via asset catalog)
    enum Colors {
        static let primary = Color("AppPrimary")
        static let secondary = Color("AppSecondary")
        static let accent = Color("AppAccent")
        static let textPrimary = Color("AppTextPrimary")
        static let textSecondary = Color("AppTextSecondary")
        static let cardBackground = Color("AppCardBackground")
        static let promotionBanner = Color("AppPromotionBanner")
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

    /// Minimum hours from now before a pickup/delivery/ship date can be selected. Prevents impossible last-minute requests.
    static let minimumOrderLeadTimeHours: Int = 24
}

//
//  LegalContent.swift
//  Guilty Pleasure Treats
//
//  Privacy Policy, Terms of Service, and Help articles for in-app display.
//  Update these when you update the .md files; replace [placeholders] with your URLs/email/state.
//

import Foundation

enum LegalContent {
    static let privacyPolicyMarkdown = """
    # Privacy Policy — Guilty Pleasure Treats

    **Last updated:** March 2026 | **Operator:** Guilty Pleasure Treats

    Guilty Pleasure Treats ("we," "our," or "us") respects your privacy. This policy describes what information we collect when you use our mobile app and how we use and protect it.

    ## 1. Information We Collect

    - **Account information:** If you create an account, we collect your email address and, if you provide it, your display name.
    - **Order information:** When you place an order, we collect your name, phone number, delivery or pickup preferences, and order details. We do not store your full payment card number; payment processing is handled by our payment provider (Stripe).
    - **Photos:** If you upload a photo (e.g., for a custom cake or AI design reference), we store that image to fulfill your order.
    - **Device and usage:** We may collect device identifiers and usage data for push notifications and to improve the app.

    ## 2. How We Use Your Information

    We use the information to create and manage your account, process orders, send order updates and push notifications (with consent), respond to support needs, improve the app, and comply with legal obligations.

    ## 3. Sharing of Information

    We may share information with service providers (hosting, analytics, payment processing) and when required by law or to protect rights and safety. We do not sell your personal information.

    ## 4. Data Retention & Your Rights

    We retain data as long as needed for services and legal obligations. You may request access, correction, or deletion of your data by contacting us. You can turn off push notifications in device settings.

    ## 5. Security & Children

    We use industry-standard measures to protect your information. Our app is not directed to children under 13; we do not knowingly collect their data.

    ## 6. Changes & Contact

    We may update this policy; continued use after changes means acceptance. For privacy questions or requests, use the Support URL or contact email in the app or on our website.

    Thank you for trusting Guilty Pleasure Treats.
    """

    static let termsOfServiceMarkdown = """
    # Terms of Service — Guilty Pleasure Treats

    **Last updated:** March 2026 | **Operator:** Guilty Pleasure Treats

    By using the Guilty Pleasure Treats app, you agree to these Terms. If you do not agree, do not use the app.

    ## 1. Use of the App

    You must be at least 13 (or the age of majority in your jurisdiction). You agree to provide accurate information, keep your account secure, and not use the app for any illegal or harmful purpose.

    ## 2. Orders and Payment

    Orders are offers to purchase; we may accept or decline them. Prices and availability may change. Payment is processed by our payment provider (e.g., Stripe). Pickup and delivery times are estimates; we are not liable for delays beyond our control.

    ## 3. Custom and AI-Designed Products

    You are responsible for ensuring design instructions and images do not infringe others' rights. We may refuse to produce inappropriate or infringing content.

    ## 4. Rewards and Promotions

    Loyalty points and promotions are offered at our discretion and may change. Points have no cash value unless stated.

    **How loyalty points work:** When you are signed in and place an order, you may earn points based on the order total. You earn **1 point per $1** of order total (rounded down to a whole number). **Points are credited after the store marks your order completed** in our system; they are not added at checkout when you pay. You may redeem points in the app for rewards we offer from time to time (for example, free items), subject to availability and these Terms.

    ## 5. Intellectual Property

    The app and its content are owned by us or our licensors. You may not copy or distribute our content without permission. You grant us a license to use your submitted content to provide and improve our services.

    ## 6. Disclaimers and Liability

    The app and products are provided "as is." We disclaim warranties to the fullest extent permitted by law. Our liability is limited to the amount you paid us in the 12 months before the claim (or $100 if greater).

    ## 7. Termination, Changes, and Contact

    We may suspend or terminate access at any time. We may update these Terms; continued use means acceptance. For questions, use the Support URL or contact email in the app or on our website.

    Thank you for using Guilty Pleasure Treats.
    """

    /// Help article: same loyalty mechanics as the Rewards screen and Terms §4, in plain language.
    static let rewardsHelpMarkdown = """
    # Rewards & points

    **Earn:** 1 point per $1 of order total.

    **When you get points:** Points are added after the store marks your order completed—not at checkout.

    **Redeem:** Open the **Rewards** tab and redeem for free treats. Current offers (for example, point costs for specific items) are listed there.

    The program is offered at our discretion and may change. Points have no cash value unless we say otherwise. For full terms, see **Terms of Service** in Settings.
    """
}

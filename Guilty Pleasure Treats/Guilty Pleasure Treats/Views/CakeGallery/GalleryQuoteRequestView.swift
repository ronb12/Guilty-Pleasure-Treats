//
//  GalleryQuoteRequestView.swift
//  Guilty Pleasure Treats
//
//  Request a quote for a gallery design: photo, structured optional fields, message to bakery.
//

import SwiftUI

struct GalleryQuoteRequestView: View {
    let item: GalleryCakeItem

    @Environment(\.dismiss) private var dismiss
    private let api = VercelService.shared
    private let auth = AuthService.shared

    @State private var name = ""
    @State private var email = ""
    @State private var phone = ""
    @State private var eventDateText = ""
    @State private var servingsText = ""
    @State private var notes = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var success = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if let msg = errorMessage {
                        ErrorMessageBanner(message: msg) { errorMessage = nil }
                    }
                    if success {
                        HStack(spacing: 12) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            Text("Request sent! We’ll get back to you with pricing and next steps.")
                                .font(.subheadline)
                                .foregroundStyle(.green)
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.green.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: AppConstants.Layout.cardCornerRadius))
                    } else {
                        itemImageSection
                        Text("Request a quote")
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundStyle(AppConstants.Colors.textPrimary)
                        Text("Tell us about your event and we’ll follow up.")
                            .font(.subheadline)
                            .foregroundStyle(AppConstants.Colors.textSecondary)

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Name")
                                .font(.subheadline.weight(.medium))
                            TextField("Your name", text: $name)
                                .textFieldStyle(.roundedBorder)
                                .textContentType(.name)
                        }
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Email")
                                .font(.subheadline.weight(.medium))
                            TextField("your@email.com", text: $email)
                                .textFieldStyle(.roundedBorder)
                                .textContentType(.emailAddress)
                                #if os(iOS)
                                .keyboardType(.emailAddress)
                                .autocapitalization(.none)
                                #endif
                        }
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Phone")
                                .font(.subheadline.weight(.medium))
                            TextField("Mobile number", text: $phone)
                                .textFieldStyle(.roundedBorder)
                                .textContentType(.telephoneNumber)
                                #if os(iOS)
                                .keyboardType(.phonePad)
                                #endif
                        }
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Event or pickup date (optional)")
                                .font(.subheadline.weight(.medium))
                            TextField("e.g. March 15 or Saturday 4/12", text: $eventDateText)
                                .textFieldStyle(.roundedBorder)
                        }
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Servings or cake size (optional)")
                                .font(.subheadline.weight(.medium))
                            TextField("e.g. 24 servings, 10 inch", text: $servingsText)
                                .textFieldStyle(.roundedBorder)
                        }
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Special requests or changes (optional)")
                                .font(.subheadline.weight(.medium))
                            TextEditor(text: $notes)
                                .frame(minHeight: 100)
                                .padding(8)
                                .background(platformSystemGrayBackground)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }

                        Button {
                            Task { await submit() }
                        } label: {
                            HStack {
                                if isLoading {
                                    ProgressView()
                                        .tint(.white)
                                } else {
                                    Text("Send quote request")
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(AppConstants.Colors.accent)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: AppConstants.Layout.buttonCornerRadius))
                        }
                        .disabled(isLoading || !canSubmitQuote)
                    }
                }
                .padding(AppConstants.Layout.screenHorizontalPadding)
                .padding(.vertical, 20)
                .macOSSheetTopPadding()
            }
            .background(AppConstants.Colors.secondary)
            .navigationTitle("Quote request")
            .inlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(AppConstants.Colors.accent)
                }
            }
            .onAppear {
                if email.isEmpty, let e = auth.currentUser?.email { email = e }
            }
        }
    }

    /// Name, email, and phone are required before sending.
    private var canSubmitQuote: Bool {
        let n = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let e = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let p = phone.trimmingCharacters(in: .whitespacesAndNewlines)
        return !n.isEmpty && !e.isEmpty && !p.isEmpty
    }

    @ViewBuilder
    private var itemImageSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let urlString = item.imageUrl, let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    default:
                        Rectangle()
                            .fill(AppConstants.Colors.cardBackground)
                            .overlay(ProgressView())
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 200)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: AppConstants.Layout.cardCornerRadius))
            }
            Text(item.title)
                .font(.headline)
                .foregroundStyle(AppConstants.Colors.textPrimary)
            if let cat = item.category, !cat.isEmpty {
                Text(cat)
                    .font(.caption)
                    .foregroundStyle(AppConstants.Colors.accent)
            }
            if let d = item.description, !d.isEmpty {
                Text(d)
                    .font(.caption)
                    .foregroundStyle(AppConstants.Colors.textSecondary)
            }
        }
    }

    private func submit() async {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedPhone = phone.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            errorMessage = "Please enter your name."
            return
        }
        guard !trimmedEmail.isEmpty else {
            errorMessage = "Please enter your email."
            return
        }
        guard !trimmedPhone.isEmpty else {
            errorMessage = "Please enter your phone number."
            return
        }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        let messageBody = Self.composedMessage(
            item: item,
            phone: trimmedPhone,
            eventDateText: eventDateText,
            servingsText: servingsText,
            notes: notes
        )
        do {
            try await api.submitContactMessage(
                name: trimmedName,
                email: trimmedEmail,
                subject: "Quote: \(item.title)",
                message: messageBody,
                userId: auth.currentUser?.uid,
                orderId: nil,
                source: "gallery_quote",
                galleryItemTitle: item.title
            )
            success = true
        } catch {
            errorMessage = FriendlyErrorMessage.message(for: error)
        }
    }

    /// Message text for the bakery (no gallery UUID; optional photo URL for staff who read email outside the app).
    private static func composedMessage(
        item: GalleryCakeItem,
        phone: String,
        eventDateText: String,
        servingsText: String,
        notes: String
    ) -> String {
        var lines: [String] = [
            "I’d like a quote for this gallery design.",
            "",
            "Design: \(item.title)",
            "Phone: \(phone)",
        ]
        if let d = item.description, !d.isEmpty {
            lines.append("Listing notes: \(d)")
        }
        let ev = eventDateText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !ev.isEmpty {
            lines.append("Event or pickup date: \(ev)")
        }
        let sv = servingsText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !sv.isEmpty {
            lines.append("Servings / size: \(sv)")
        }
        let n = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        if !n.isEmpty {
            lines.append("")
            lines.append("Details:")
            lines.append(n)
        }
        if let u = item.imageUrl, !u.isEmpty {
            lines.append("")
            lines.append("Design photo link (reference): \(u)")
        }
        return lines.joined(separator: "\n")
    }
}

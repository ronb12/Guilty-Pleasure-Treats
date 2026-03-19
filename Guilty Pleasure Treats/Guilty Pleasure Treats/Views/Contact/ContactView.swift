//
//  ContactView.swift
//  Guilty Pleasure Treats
//
//  In-app contact form: name, email, subject, message. Submits to API; owner sees in Admin.
//

import SwiftUI

struct ContactView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var email = ""
    @State private var subject = ""
    @State private var message = ""
    /// Empty = general inquiry; otherwise order id for "regarding this order".
    @State private var selectedOrderIdForMessage: String = ""
    @State private var userOrders: [Order] = []
    @State private var ordersLoading = false
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var success = false

    var initialSubject: String?
    var initialMessage: String?

    private let api = VercelService.shared
    private let auth = AuthService.shared

    private var regardingOptions: [(id: String, label: String)] {
        [("", "General inquiry (no order)")] + userOrders.compactMap { o in
            guard let id = o.id else { return nil }
            let dateStr = o.createdAt.map { $0.formatted(date: .abbreviated, time: .omitted) } ?? "Order"
            let shortRef = orderShortReference(from: id)
            return (id, "Order #\(shortRef) · \(dateStr) · \(o.total.currencyFormatted)")
        }
    }

    /// First 8 hex chars of UUID for a readable “order number” in the picker and for admin cross-reference.
    private func orderShortReference(from orderId: String) -> String {
        let compact = orderId.replacingOccurrences(of: "-", with: "")
        if compact.count >= 8 { return String(compact.prefix(8)).uppercased() }
        return String(orderId.prefix(12))
    }

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
                            Text("Message sent! We’ll get back to you soon.")
                                .font(.subheadline)
                                .foregroundStyle(.green)
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.green.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: AppConstants.Layout.cardCornerRadius))
                    } else {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Name (optional)")
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
                            Text("Subject (optional)")
                                .font(.subheadline.weight(.medium))
                            TextField("e.g. Order question", text: $subject)
                                .textFieldStyle(.roundedBorder)
                        }
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Regarding (optional)")
                                .font(.subheadline.weight(.medium))
                            Text("Link this message to an order so the bakery can look it up by order number.")
                                .font(.caption)
                                .foregroundStyle(AppConstants.Colors.textSecondary)
                            if ordersLoading {
                                ProgressView()
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            } else if regardingOptions.count > 1 {
                                Picker("", selection: $selectedOrderIdForMessage) {
                                    ForEach(regardingOptions, id: \.id) { opt in
                                        Text(opt.label).tag(opt.id)
                                    }
                                }
                                .pickerStyle(.menu)
                            }
                        }
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Message")
                                .font(.subheadline.weight(.medium))
                            TextEditor(text: $message)
                                .frame(minHeight: 120)
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
                                    Text("Send message")
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(AppConstants.Colors.accent)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: AppConstants.Layout.buttonCornerRadius))
                        }
                        .disabled(isLoading || email.trimmingCharacters(in: .whitespaces).isEmpty || message.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
                .padding(AppConstants.Layout.screenHorizontalPadding)
                .padding(.vertical, 20)
                .macOSSheetTopPadding()
            }
            .background(AppConstants.Colors.secondary)
            .navigationTitle("Contact us")
            .inlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(AppConstants.Colors.accent)
                }
            }
            .onAppear {
                if subject.isEmpty, let s = initialSubject { subject = s }
                if message.isEmpty, let m = initialMessage { message = m }
                if email.isEmpty, let e = auth.currentUser?.email { email = e }
            }
            .task { await loadUserOrders() }
        }
    }

    private func submit() async {
        let trimmedEmail = email.trimmingCharacters(in: .whitespaces)
        let trimmedMessage = message.trimmingCharacters(in: .whitespaces)
        guard !trimmedEmail.isEmpty, !trimmedMessage.isEmpty else {
            errorMessage = "Please enter your email and message."
            return
        }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            try await api.submitContactMessage(
                name: name.isEmpty ? nil : name.trimmingCharacters(in: .whitespaces),
                email: trimmedEmail,
                subject: subject.isEmpty ? nil : subject.trimmingCharacters(in: .whitespaces),
                message: trimmedMessage,
                userId: auth.currentUser?.uid,
                orderId: selectedOrderIdForMessage.isEmpty ? nil : selectedOrderIdForMessage
            )
            success = true
        } catch {
            errorMessage = FriendlyErrorMessage.message(for: error)
        }
    }

    private func loadUserOrders() async {
        guard let uid = auth.currentUser?.uid else { return }
        ordersLoading = true
        defer { ordersLoading = false }
        do {
            userOrders = try await api.fetchOrders(userId: uid)
        } catch {
            userOrders = []
        }
    }
}

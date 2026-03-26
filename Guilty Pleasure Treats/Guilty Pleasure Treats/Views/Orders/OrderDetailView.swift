//
//  OrderDetailView.swift
//  Guilty Pleasure Treats
//
//  Full order details when tapping an order from My Orders.
//

import SwiftUI

/// One step in the track-order status bar (Ordered → Confirmed → Preparing → Ready → Done).
private struct TrackOrderStep {
    let status: OrderStatus
    let label: String
    private static let order: [OrderStatus] = [.pending, .confirmed, .preparing, .ready, .completed]
    func reached(by current: OrderStatus?) -> Bool {
        guard let current = current, let stepIdx = Self.order.firstIndex(of: status),
              let currentIdx = Self.order.firstIndex(of: current) else { return false }
        return currentIdx >= stepIdx
    }
    func isCurrent(_ current: OrderStatus?) -> Bool { current == status }
}

struct OrderDetailView: View {
    let order: Order
    let isAdmin: Bool
    var onUpdateStatus: ((Order, OrderStatus) -> Void)?
    var onMarkAsPaid: ((String) -> Void)?
    var onSendPaymentLink: ((String) -> Void)?
    /// Called after admin saves parcel tracking so lists can refresh.
    var onParcelTrackingChanged: (() -> Void)? = nil

    @Environment(\.openURL) private var openURL
    @State private var liveOrder: Order?
    @State private var showStatusPicker = false
    /// After saving parcel info, apply this status (shipping orders must have tracking before "Ready for Pickup").
    @State private var pendingStatusAfterTracking: OrderStatus?
    @State private var showCancelRequestSheet = false
    @State private var showParcelEditor = false
    @State private var parcelCarrierDraft = ""
    @State private var parcelNumberDraft = ""
    @State private var parcelStatusDraft = ""
    @State private var parcelSaveError: String?
    @State private var isSavingParcel = false
    @State private var existingOrderReview: Review?
    @State private var reviewRating: Int = 5
    @State private var reviewText: String = ""
    @State private var isSubmittingReview = false
    @State private var reviewErrorMessage: String?

    private let api = VercelService.shared

    private var displayOrder: Order { liveOrder ?? order }

    private var isSampleOrder: Bool {
        order.id?.hasPrefix("sample-") ?? false
    }

    private var showParcelSection: Bool {
        guard !isSampleOrder else { return false }
        if isAdmin { return true }
        let o = displayOrder
        if let u = o.trackingUrl, !u.isEmpty { return true }
        if let d = o.trackingStatusDetail, !d.isEmpty { return true }
        return false
    }

    /// Title shown in nav bar; identifies which order when there are many.
    private var orderTitle: String {
        let name = displayOrder.customerName.trimmingCharacters(in: .whitespaces)
        if !name.isEmpty { return "Order · \(name)" }
        if let id = displayOrder.id, !id.isEmpty {
            return "Order \(OrderReference.displayCode(from: id))"
        }
        return "Order details"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                headerCard
                orderStatusBar
                fulfillmentCard
                if showParcelSection {
                    parcelTrackingCard
                }
                itemsCard
                totalsCard
                if !isAdmin, !isSampleOrder, displayOrder.statusEnum == .completed {
                    orderReviewCard
                }
                if isAdmin, !isSampleOrder {
                    adminActionsCard
                }
            }
            .padding(.horizontal, AppConstants.Layout.screenHorizontalPadding)
            .padding(.bottom, 24)
            .macOSSheetTopPadding()
        }
        .background(AppConstants.Colors.secondary)
        .navigationTitle(orderTitle)
        .inlineNavigationTitle()
        .confirmationDialog("Update status", isPresented: $showStatusPicker) {
            ForEach(OrderStatus.allCases, id: \.self) { status in
                Button(status.rawValue) {
                    proposeStatusUpdate(status)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Set order status")
        }
        .sheet(isPresented: $showCancelRequestSheet) {
            ContactView(
                initialSubject: displayOrder.id.map { "Cancel order \(OrderReference.displayCode(from: $0))" },
                initialMessage: "I would like to cancel this order. Please confirm."
            )
        }
        .sheet(isPresented: $showParcelEditor) {
            NavigationStack {
                Form {
                    Picker("Carrier", selection: $parcelCarrierDraft) {
                        Text("None").tag("")
                        Text("UPS").tag("ups")
                        Text("FedEx").tag("fedex")
                        Text("USPS").tag("usps")
                    }
                    TextField("Tracking number", text: $parcelNumberDraft)
                        #if os(iOS)
                        .textInputAutocapitalization(.never)
                        #endif
                    TextField("Carrier status (optional)", text: $parcelStatusDraft, axis: .vertical)
                        .lineLimit(3...6)
                    if let parcelSaveError {
                        Section {
                            Text(parcelSaveError)
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                    }
                }
                .navigationTitle("Parcel tracking")
                #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
                #endif
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            showParcelEditor = false
                            parcelSaveError = nil
                            pendingStatusAfterTracking = nil
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            Task { await saveParcelTrackingEdits() }
                        }
                        .disabled(isSavingParcel)
                    }
                }
            }
            #if os(iOS)
            .presentationDetents([.medium, .large])
            #endif
        }
        .task {
            await refreshOrderFromServer()
            if !isAdmin, displayOrder.id != nil, displayOrder.statusEnum == .completed {
                await loadOrderReview()
            }
        }
    }

    private func refreshOrderFromServer() async {
        guard let oid = order.id, !isSampleOrder else { return }
        if let fresh = try? await api.fetchOrder(orderId: oid) {
            liveOrder = fresh
        }
    }

    private func proposeStatusUpdate(_ status: OrderStatus) {
        if isAdmin, status == .ready, displayOrder.fulfillmentEnum == .shipping,
           !displayOrder.hasParcelTrackingForShipping {
            pendingStatusAfterTracking = status
            openParcelEditor()
            return
        }
        onUpdateStatus?(displayOrder, status)
    }

    private func openParcelEditor() {
        let o = displayOrder
        parcelCarrierDraft = o.trackingCarrier?.lowercased() ?? ""
        parcelNumberDraft = o.trackingNumber ?? ""
        parcelStatusDraft = o.trackingStatusDetail ?? ""
        parcelSaveError = nil
        showParcelEditor = true
    }

    private func saveParcelTrackingEdits() async {
        guard let oid = displayOrder.id else { return }
        isSavingParcel = true
        defer { isSavingParcel = false }
        parcelSaveError = nil
        let carrier = parcelCarrierDraft.isEmpty ? nil : parcelCarrierDraft
        let number = parcelNumberDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? nil
            : parcelNumberDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        let detail = parcelStatusDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? nil
            : parcelStatusDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            try await api.updateOrderParcelTracking(
                orderId: oid,
                trackingCarrier: carrier,
                trackingNumber: number,
                trackingStatusDetail: detail
            )
            await refreshOrderFromServer()
            showParcelEditor = false
            onParcelTrackingChanged?()
            if let pending = pendingStatusAfterTracking {
                pendingStatusAfterTracking = nil
                let o = liveOrder ?? displayOrder
                if o.hasParcelTrackingForShipping {
                    onUpdateStatus?(o, pending)
                }
            }
        } catch {
            parcelSaveError = FriendlyErrorMessage.message(for: error)
        }
    }

    /// DoorDash-style: rate your order after it’s completed (one review per order).
    private var orderReviewCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let review = existingOrderReview {
                Text("You rated this order")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppConstants.Colors.textPrimary)
                HStack(spacing: 2) {
                    ForEach(1...5, id: \.self) { star in
                        Image(systemName: (review.rating ?? 0) >= star ? "star.fill" : "star")
                            .font(.subheadline)
                            .foregroundStyle(AppConstants.Colors.accent)
                    }
                }
                if let text = review.text, !text.isEmpty {
                    Text(text)
                        .font(.caption)
                        .foregroundStyle(AppConstants.Colors.textSecondary)
                }
            } else {
                Text("Rate your order")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppConstants.Colors.textPrimary)
                Text("How was your experience?")
                    .font(.caption)
                    .foregroundStyle(AppConstants.Colors.textSecondary)
                HStack(spacing: 4) {
                    ForEach(1...5, id: \.self) { star in
                        Button {
                            reviewRating = star
                            reviewErrorMessage = nil
                        } label: {
                            Image(systemName: reviewRating >= star ? "star.fill" : "star")
                                .font(.title2)
                                .foregroundStyle(AppConstants.Colors.accent)
                        }
                        .buttonStyle(.plain)
                    }
                }
                TextEditor(text: $reviewText)
                    .frame(minHeight: 60)
                    .padding(8)
                    .background(platformSystemGrayBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(Group {
                        if reviewText.isEmpty {
                            Text("Add a comment (optional)")
                                #if os(iOS)
                                .foregroundStyle(Color(uiColor: .placeholderText))
                                #elseif os(macOS)
                                .foregroundStyle(Color(nsColor: .placeholderTextColor))
                                #else
                                .foregroundStyle(.secondary)
                                #endif
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                                .allowsHitTesting(false)
                        }
                    }, alignment: .topLeading)
                if let msg = reviewErrorMessage {
                    Text(msg)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
                Button {
                    Task { await submitOrderReview() }
                } label: {
                    if isSubmittingReview {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text("Submit review")
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(AppConstants.Colors.accent)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: AppConstants.Layout.buttonCornerRadius))
                .disabled(isSubmittingReview)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppConstants.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppConstants.Layout.cardCornerRadius))
    }

    private func loadOrderReview() async {
        guard let orderId = order.id else { return }
        do {
            existingOrderReview = try await api.fetchReviewForOrder(orderId: orderId)
        } catch {
            existingOrderReview = nil
        }
    }

    private func submitOrderReview() async {
        guard let orderId = order.id else { return }
        reviewErrorMessage = nil
        isSubmittingReview = true
        defer { isSubmittingReview = false }
        do {
            try await api.submitReview(orderId: orderId, rating: reviewRating, text: reviewText.isEmpty ? nil : reviewText)
            existingOrderReview = Review(
                id: "",
                authorName: nil,
                rating: reviewRating,
                text: reviewText.isEmpty ? nil : reviewText,
                createdAt: Date(),
                productId: nil,
                orderId: orderId,
                userId: nil
            )
            reviewText = ""
        } catch {
            reviewErrorMessage = FriendlyErrorMessage.message(for: error)
        }
    }

    private var requestCancellationCard: some View {
        Button {
            showCancelRequestSheet = true
        } label: {
            HStack {
                Image(systemName: "xmark.circle")
                    .foregroundStyle(AppConstants.Colors.accent)
                Text("Request cancellation")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(AppConstants.Colors.textPrimary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(AppConstants.Colors.textSecondary)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppConstants.Colors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppConstants.Layout.cardCornerRadius))
        }
        .buttonStyle(.plain)
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(displayOrder.id.map { OrderReference.displayCode(from: $0) } ?? "Sample order")
                    .font(.headline)
                    .foregroundStyle(AppConstants.Colors.textPrimary)
                Spacer()
                Text(displayOrder.status)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(statusColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(statusColor.opacity(0.2))
                    .clipShape(Capsule())
            }
            if let date = displayOrder.createdAt {
                Text("Placed \(date.dateAndTimeString)")
                    .font(.subheadline)
                    .foregroundStyle(AppConstants.Colors.textSecondary)
            }
            HStack {
                Text(displayOrder.customerName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(AppConstants.Colors.textPrimary)
                Spacer()
            }
            if !displayOrder.customerPhone.isEmpty {
                Text(displayOrder.customerPhone)
                    .font(.caption)
                    .foregroundStyle(AppConstants.Colors.textSecondary)
            }
            if let email = displayOrder.customerEmail, !email.isEmpty {
                Text(email)
                    .font(.caption)
                    .foregroundStyle(AppConstants.Colors.textSecondary)
            }
            if let addr = displayOrder.deliveryAddress, !addr.isEmpty {
                Text(addr.replacingOccurrences(of: "\n", with: ", "))
                    .font(.caption)
                    .foregroundStyle(AppConstants.Colors.textSecondary)
            }
            if isAdmin {
                if displayOrder.statusEnum == .cancelled {
                    Text("Payment: N/A (order cancelled)")
                        .font(.caption)
                        .foregroundStyle(AppConstants.Colors.textSecondary)
                } else {
                    Text(displayOrder.isPaid ? "Payment: Paid" : "Payment: Pending")
                        .font(.caption)
                        .foregroundStyle(displayOrder.isPaid ? .green : AppConstants.Colors.textSecondary)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppConstants.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppConstants.Layout.cardCornerRadius))
    }

    /// Track order status bar: Ordered → Confirmed → Preparing → Ready → Done (or Cancelled).
    private var orderStatusBar: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: isAdmin ? "list.bullet" : "location.circle.fill")
                    .font(.subheadline)
                    .foregroundStyle(isAdmin ? AppConstants.Colors.textSecondary : AppConstants.Colors.accent)
                Text(isAdmin ? "Order status" : "Track your order")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(AppConstants.Colors.textPrimary)
            }
            if !isAdmin, displayOrder.statusEnum != .cancelled {
                Text("See where your order is in the process.")
                    .font(.caption)
                    .foregroundStyle(AppConstants.Colors.textSecondary)
            }
            if !isAdmin {
                Text("Current status: \(displayOrder.status)")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(statusColor)
            }
            if displayOrder.statusEnum == .cancelled {
                HStack(spacing: 8) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.red)
                    Text("This order was cancelled")
                        .font(.subheadline)
                        .foregroundStyle(.red)
                }
                .padding(.vertical, 4)
            } else {
                HStack(alignment: .top, spacing: 0) {
                    ForEach(Array(Self.trackOrderSteps.enumerated()), id: \.offset) { index, step in
                        let isReached = step.reached(by: displayOrder.statusEnum)
                        let isCurrent = step.isCurrent(displayOrder.statusEnum)
                        HStack(spacing: 0) {
                            VStack(spacing: 4) {
                                ZStack {
                                    Circle()
                                        .fill(isReached ? (isCurrent ? statusColor : Color.green) : Color.gray.opacity(0.3))
                                        .frame(width: 28, height: 28)
                                    if isReached {
                                        Image(systemName: isCurrent ? "circle.fill" : "checkmark")
                                            .font(isCurrent ? .system(size: 10) : .caption.weight(.semibold))
                                            .foregroundStyle(.white)
                                    }
                                }
                                Text(step.label)
                                    .font(.caption2)
                                    .foregroundStyle(isReached ? AppConstants.Colors.textPrimary : AppConstants.Colors.textSecondary)
                                    .multilineTextAlignment(.center)
                                    .lineLimit(2)
                            }
                            .frame(width: 72)
                            if index < Self.trackOrderSteps.count - 1 {
                                Rectangle()
                                    .fill(isReached && !isCurrent ? Color.green.opacity(0.6) : Color.gray.opacity(0.25))
                                    .frame(height: 2)
                                    .padding(.top, 14)
                            }
                        }
                    }
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppConstants.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppConstants.Layout.cardCornerRadius))
    }

    private static let trackOrderSteps: [TrackOrderStep] = [
        TrackOrderStep(status: .pending, label: "Ordered"),
        TrackOrderStep(status: .confirmed, label: "Confirmed"),
        TrackOrderStep(status: .preparing, label: "Preparing"),
        TrackOrderStep(status: .ready, label: "Ready"),
        TrackOrderStep(status: .completed, label: "Done"),
    ]

    private var fulfillmentCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Fulfillment")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(AppConstants.Colors.textPrimary)
            HStack {
                Text(displayOrder.fulfillmentType)
                    .font(.subheadline)
                    .foregroundStyle(AppConstants.Colors.textSecondary)
                Spacer()
            }
            if let date = displayOrder.scheduledPickupDate {
                HStack {
                    Text(displayOrder.fulfillmentEnum == .shipping ? "Ship date" : (displayOrder.fulfillmentEnum == .delivery ? "Delivery date" : "Pickup time"))
                        .font(.caption)
                        .foregroundStyle(AppConstants.Colors.textSecondary)
                    Spacer()
                    Text(date.dateAndTimeString)
                        .font(.caption)
                        .foregroundStyle(AppConstants.Colors.textPrimary)
                }
            }
            if let ready = displayOrder.estimatedReadyTime {
                HStack {
                    Text("Est. ready")
                        .font(.caption)
                        .foregroundStyle(AppConstants.Colors.textSecondary)
                    Spacer()
                    Text(ready.dateAndTimeString)
                        .font(.caption)
                        .foregroundStyle(AppConstants.Colors.textPrimary)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppConstants.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppConstants.Layout.cardCornerRadius))
    }

    private var parcelTrackingCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "shippingbox.fill")
                    .font(.subheadline)
                    .foregroundStyle(AppConstants.Colors.accent)
                Text("Shipment")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(AppConstants.Colors.textPrimary)
                Spacer()
                if isAdmin {
                    Button("Edit") { openParcelEditor() }
                        .font(.subheadline)
                        .foregroundStyle(AppConstants.Colors.accent)
                }
            }
            if let detail = displayOrder.trackingStatusDetail, !detail.isEmpty {
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(AppConstants.Colors.textSecondary)
            }
            if let carrier = displayOrder.trackingCarrier, !carrier.isEmpty,
               let num = displayOrder.trackingNumber, !num.isEmpty {
                Text("\(carrier.uppercased()) · \(num)")
                    .font(.caption)
                    .foregroundStyle(AppConstants.Colors.textPrimary)
            } else if isAdmin {
                Text("Add carrier and tracking number to enable Track package.")
                    .font(.caption)
                    .foregroundStyle(AppConstants.Colors.textSecondary)
            }
            if let urlString = displayOrder.trackingUrl, let url = URL(string: urlString) {
                Button {
                    openURL(url)
                } label: {
                    Label("Track package", systemImage: "arrow.up.right.square")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.borderedProminent)
                .tint(AppConstants.Colors.accent)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppConstants.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppConstants.Layout.cardCornerRadius))
    }

    private var itemsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Items")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(AppConstants.Colors.textPrimary)
            ForEach(displayOrder.items) { item in
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .top) {
                        Text("\(item.quantity)× \(item.name)")
                            .font(.subheadline)
                            .foregroundStyle(AppConstants.Colors.textPrimary)
                        Spacer()
                        Text(item.subtotal.currencyFormatted)
                            .font(.subheadline)
                            .foregroundStyle(AppConstants.Colors.textPrimary)
                    }
                    if let s = item.sizeLabel, !s.isEmpty {
                        Text(s)
                            .font(.caption)
                            .foregroundStyle(AppConstants.Colors.textSecondary)
                    }
                    if !item.specialInstructions.isEmpty {
                        Text(item.specialInstructions)
                            .font(.caption)
                            .foregroundStyle(AppConstants.Colors.textSecondary)
                            .italic()
                    }
                }
                .padding(.vertical, 4)
                if item.id != displayOrder.items.last?.id {
                    Divider()
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppConstants.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppConstants.Layout.cardCornerRadius))
    }

    private var totalsCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            OrderTotalsBreakdownView(order: displayOrder, emphasizeTotal: true)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppConstants.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppConstants.Layout.cardCornerRadius))
    }

    private var adminActionsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Admin")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(AppConstants.Colors.textPrimary)
            HStack(spacing: 12) {
                Button {
                    showStatusPicker = true
                } label: {
                    Text("Update status")
                        .font(.subheadline)
                        .foregroundStyle(AppConstants.Colors.accent)
                }
                if displayOrder.statusEnum != .cancelled, !displayOrder.isPaid, let orderId = displayOrder.id {
                    if let markPaid = onMarkAsPaid {
                        Button("Mark as paid") {
                            markPaid(orderId)
                        }
                        .font(.subheadline)
                        .foregroundStyle(.green)
                    }
                    if let sendLink = onSendPaymentLink {
                        Button("Send payment link") {
                            sendLink(orderId)
                        }
                        .font(.subheadline)
                        .foregroundStyle(AppConstants.Colors.accent)
                    }
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppConstants.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppConstants.Layout.cardCornerRadius))
    }

    private var statusColor: Color {
        switch displayOrder.statusEnum {
        case .completed: return .green
        case .cancelled: return .red
        case .ready: return .blue
        default: return AppConstants.Colors.accent
        }
    }
}

//
//  OrdersView.swift
//  Guilty Pleasure Treats
//
//  List of user's previous orders (and all orders for admin).
//

import SwiftUI

struct OrdersView: View {
    @StateObject private var viewModel = OrdersViewModel()
    @ObservedObject private var notificationService = NotificationService.shared
    @State private var orderToOpenFromPush: Order?

    var body: some View {
        Group {
            if viewModel.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.orders.isEmpty {
                emptyOrdersView
            } else {
                ordersList
            }
        }
        .background(AppConstants.Colors.secondary)
        .macOSConstrainedContent()
        .navigationTitle(viewModel.isAdmin ? "All Orders" : "My Orders")
        .inlineNavigationTitle()
        .task { await viewModel.loadOrders() }
        .refreshable { await viewModel.loadOrders() }
        .onChange(of: notificationService.pendingOrderIdToOpen) { _, orderId in
            guard let orderId, let order = viewModel.orders.first(where: { $0.id == orderId }) else { return }
            orderToOpenFromPush = order
            notificationService.clearPendingOrderIdToOpen()
        }
        .onChange(of: viewModel.orders.count) { _, _ in
            guard let orderId = notificationService.pendingOrderIdToOpen,
                  let order = viewModel.orders.first(where: { $0.id == orderId }) else { return }
            orderToOpenFromPush = order
            notificationService.clearPendingOrderIdToOpen()
        }
        .sheet(item: $orderToOpenFromPush) { order in
            NavigationStack {
                OrderDetailView(
                    order: order,
                    isAdmin: viewModel.isAdmin,
                    onParcelTrackingChanged: {
                        Task { await viewModel.loadOrders() }
                    }
                )
            }
            .presentationDetents([.large])
        }
        .overlay(alignment: .top) {
            if let msg = viewModel.errorMessage {
                ErrorMessageBanner(message: msg) {
                    viewModel.errorMessage = nil
                }
                .padding()
            }
        }
    }
    
    private var emptyOrdersView: some View {
        VStack(spacing: 16) {
            Image(systemName: "tray")
                .font(.system(size: 50))
                .foregroundStyle(AppConstants.Colors.textSecondary)
            Text("No orders yet")
                .font(.title3)
                .foregroundStyle(AppConstants.Colors.textPrimary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var ordersList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(viewModel.orders) { order in
                    NavigationLink(destination: OrderDetailView(
                        order: order,
                        isAdmin: viewModel.isAdmin,
                        onUpdateStatus: { updatedOrder, newStatus in
                            Task { await viewModel.updateStatus(order: updatedOrder, status: newStatus) }
                        },
                        onParcelTrackingChanged: {
                            Task { await viewModel.loadOrders() }
                        }
                    )) {
                        OrderRowView(order: order, isAdmin: viewModel.isAdmin) { updatedOrder, newStatus in
                            Task { await viewModel.updateStatus(order: updatedOrder, status: newStatus) }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, AppConstants.Layout.screenHorizontalPadding)
            .padding(.bottom, 24)
        }
    }
}

struct OrderRowView: View {
    let order: Order
    let isAdmin: Bool
    /// (order, newStatus) when admin updates status.
    let onUpdateStatus: (Order, OrderStatus) -> Void
    /// When set, admin can mark order as paid (cash/Cash App/card in person).
    var onMarkAsPaid: ((String) -> Void)? = nil
    @State private var showStatusPicker = false

    private var isSampleOrder: Bool {
        order.id?.hasPrefix("sample-") ?? false
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(order.createdAt?.shortDateString ?? "—")
                    .font(.caption)
                    .foregroundStyle(AppConstants.Colors.textSecondary)
                Spacer()
                Text(order.statusDisplayLabel)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(statusColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(statusColor.opacity(0.2))
                    .clipShape(Capsule())
            }
            if !isAdmin {
                HStack(spacing: 6) {
                    Text("Order status:")
                        .font(.caption)
                        .foregroundStyle(AppConstants.Colors.textSecondary)
                    Text(order.statusDisplayLabel)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(statusColor)
                }
            }

            Text(order.customerName)
                .font(.headline)
                .foregroundStyle(AppConstants.Colors.textPrimary)
            Text("\(order.items.count) items · \(order.total.currencyFormatted)")
                .font(.subheadline)
                .foregroundStyle(AppConstants.Colors.textSecondary)
            if isAdmin {
                if order.statusEnum == .cancelled {
                    Text("Payment: N/A (cancelled)")
                        .font(.caption2)
                        .foregroundStyle(AppConstants.Colors.textSecondary)
                } else {
                    Text(order.isPaid ? "Payment: Paid" : "Payment: Pending")
                        .font(.caption2)
                        .foregroundStyle(AppConstants.Colors.textSecondary)
                }
            }
            if isAdmin, !isSampleOrder {
                HStack(spacing: 12) {
                    Button {
                        showStatusPicker = true
                    } label: {
                        Text("Update status")
                            .font(.caption)
                            .foregroundStyle(AppConstants.Colors.accent)
                    }
                    .confirmationDialog("Update status", isPresented: $showStatusPicker) {
                        ForEach(OrderStatus.allCases, id: \.self) { status in
                            Button(status.displayLabel(for: order.fulfillmentEnum)) { onUpdateStatus(order, status) }
                        }
                        Button("Cancel", role: .cancel) {}
                    } message: {
                        Text("Set order status")
                    }
                    if order.statusEnum != .cancelled, !order.isPaid, let orderId = order.id, let markPaid = onMarkAsPaid {
                        Button("Mark as paid") {
                            markPaid(orderId)
                        }
                        .font(.caption)
                        .foregroundStyle(.green)
                    }
                }
            }
        }
        .padding()
        .background(AppConstants.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppConstants.Layout.cardCornerRadius))
        .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 1)
    }
    
    private var statusColor: Color {
        switch order.statusEnum {
        case .completed: return .green
        case .delivered: return .green
        case .cancelled: return .red
        case .ready: return .blue
        default: return AppConstants.Colors.accent
        }
    }
}

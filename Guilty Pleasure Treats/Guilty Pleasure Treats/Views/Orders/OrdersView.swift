//
//  OrdersView.swift
//  Guilty Pleasure Treats
//
//  List of user's previous orders (and all orders for admin).
//

import SwiftUI

struct OrdersView: View {
    @StateObject private var viewModel = OrdersViewModel()
    
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
        .navigationTitle(viewModel.isAdmin ? "All Orders" : "My Orders")
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.loadOrders() }
        .refreshable { await viewModel.loadOrders() }
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
                    OrderRowView(order: order, isAdmin: viewModel.isAdmin) { updatedOrder, newStatus in
                        Task {
                            await viewModel.updateStatus(order: updatedOrder, status: newStatus)
                        }
                    }
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
    @State private var showStatusPicker = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(order.createdAt?.shortDateString ?? "—")
                    .font(.caption)
                    .foregroundStyle(AppConstants.Colors.textSecondary)
                Spacer()
                Text(order.status)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(statusColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(statusColor.opacity(0.2))
                    .clipShape(Capsule())
            }
            
            Text(order.customerName)
                .font(.headline)
                .foregroundStyle(AppConstants.Colors.textPrimary)
            Text("\(order.items.count) items · \(order.total.currencyFormatted)")
                .font(.subheadline)
                .foregroundStyle(AppConstants.Colors.textSecondary)
            
            if isAdmin {
                Button {
                    showStatusPicker = true
                } label: {
                    Text("Update status")
                        .font(.caption)
                        .foregroundStyle(AppConstants.Colors.accent)
                }
                .confirmationDialog("Update status", isPresented: $showStatusPicker) {
                    ForEach(OrderStatus.allCases, id: \.self) { status in
                        Button(status.rawValue) { onUpdateStatus(order, status) }
                    }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("Set order status")
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
        case .cancelled: return .red
        case .ready: return .blue
        default: return AppConstants.Colors.accent
        }
    }
}

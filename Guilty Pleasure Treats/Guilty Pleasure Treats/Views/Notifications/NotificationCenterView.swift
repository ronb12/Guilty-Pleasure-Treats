//
//  NotificationCenterView.swift
//  Guilty Pleasure Treats
//
//  In-app notification center (bell): list of new order, message, order status, low stock.
//

import SwiftUI

struct NotificationCenterView: View {
    @ObservedObject private var notificationService = NotificationService.shared
    @ObservedObject private var tabRouter = TabRouter.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if notificationService.inAppNotifications.isEmpty {
                    ContentUnavailableView(
                        "No notifications",
                        systemImage: "bell.slash",
                        description: Text("New orders, messages, and order updates will appear here.")
                    )
                } else {
                    List {
                        ForEach(notificationService.inAppNotifications) { notification in
                            NotificationRowView(
                                notification: notification,
                                onTap: { handleTap(notification) },
                                onRemove: { notificationService.removeInAppNotification(id: notification.id) }
                            )
                        }
                        .onDelete { indexSet in
                            let idsToRemove = indexSet.map { notificationService.inAppNotifications[$0].id }
                            for id in idsToRemove {
                                notificationService.removeInAppNotification(id: id)
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .background(AppConstants.Colors.secondary)
            .navigationTitle("Notifications")
            .inlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundStyle(AppConstants.Colors.accent)
                }
                ToolbarItem(placement: .primaryAction) {
                    if !notificationService.inAppNotifications.isEmpty {
                        Button("Clear all") {
                            notificationService.clearAllInAppNotifications()
                        }
                        .foregroundStyle(AppConstants.Colors.accent)
                    }
                }
            }
            .macOSConstrainedContent()
        }
    }

    private func handleTap(_ notification: AppNotification) {
        notificationService.markInAppNotificationRead(id: notification.id)
        dismiss()
        switch notification.type {
        case .newOrder, .newMessage, .lowInventory:
            notificationService.setPendingPushAction(notificationTypeToAction(notification))
        case .newEvent:
            notificationService.setPendingPushAction(.openEvents)
            tabRouter.selectedTab = 0
        case .orderStatus:
            if let orderId = notification.orderId {
                notificationService.setPendingPushAction(.openOrder(orderId: orderId))
                notificationService.setPendingOrderIdToOpen(orderId)
            }
            tabRouter.selectedTab = 4
        }
    }

    private func notificationTypeToAction(_ n: AppNotification) -> PendingPushAction {
        switch n.type {
        case .newMessage:
            return .openAdminMessages(messageId: n.messageId)
        case .newOrder:
            return .openAdminOrder(orderId: n.orderId)
        case .lowInventory:
            return .openAdminInventory
        case .orderStatus:
            return .openOrder(orderId: n.orderId)
        case .newEvent:
            return .openEvents
        }
    }
}

private struct NotificationRowView: View {
    let notification: AppNotification
    let onTap: () -> Void
    let onRemove: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: notification.systemImage)
                    .font(.title2)
                    .foregroundStyle(AppConstants.Colors.accent)
                    .frame(width: 36, height: 36)
                    .background(AppConstants.Colors.accent.opacity(0.12))
                    .clipShape(Circle())
                VStack(alignment: .leading, spacing: 4) {
                    Text(notification.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppConstants.Colors.textPrimary)
                    Text(notification.body)
                        .font(.caption)
                        .foregroundStyle(AppConstants.Colors.textSecondary)
                        .lineLimit(2)
                    Text(notification.createdAt.shortDateString)
                        .font(.caption2)
                        .foregroundStyle(AppConstants.Colors.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                if !notification.read {
                    Circle()
                        .fill(AppConstants.Colors.accent)
                        .frame(width: 8, height: 8)
                }
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
    }
}

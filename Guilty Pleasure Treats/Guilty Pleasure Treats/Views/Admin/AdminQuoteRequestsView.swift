//
//  AdminQuoteRequestsView.swift
//  Guilty Pleasure Treats
//
//  Admin inbox for cake gallery “Request a quote” submissions (same API as contact, filtered).
//

import SwiftUI

struct AdminQuoteRequestsView: View {
    @ObservedObject var viewModel: AdminViewModel
    var onViewOrderFromMessage: (String) -> Void = { _ in }
    @State private var selectedMessage: ContactMessage?

    private func applyScrollToMessageId() {
        guard let messageId = viewModel.scrollToMessageId, !messageId.isEmpty else { return }
        if let msg = viewModel.quoteRequests.first(where: { $0.id == messageId }) {
            selectedMessage = msg
            if msg.readAt == nil {
                Task { await viewModel.markContactMessageRead(msg) }
            }
            viewModel.clearScrollToMessageId()
        }
    }

    var body: some View {
        NavigationStack {
            List {
                if viewModel.quoteRequests.isEmpty {
                    Section {
                        VStack(alignment: .leading, spacing: 14) {
                            Label("No quote requests", systemImage: "text.bubble")
                                .font(.headline)
                                .foregroundStyle(AppConstants.Colors.textPrimary)
                            Text("When customers tap Request a quote on a gallery item, their request appears here. You can reply in app like Messages.")
                                .font(.subheadline)
                                .foregroundStyle(AppConstants.Colors.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .listRowInsets(EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16))
                        .listRowBackground(Color.clear)
                    }
                } else {
                    ForEach(viewModel.quoteRequests) { msg in
                        Button {
                            selectedMessage = msg
                            if msg.readAt == nil {
                                Task { await viewModel.markContactMessageRead(msg) }
                            }
                        } label: {
                            HStack(alignment: .top) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(msg.email)
                                        .font(.subheadline.weight(.medium))
                                        .foregroundStyle(AppConstants.Colors.textPrimary)
                                    if let design = msg.galleryItemTitle, !design.isEmpty {
                                        Text(design)
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(AppConstants.Colors.accent)
                                            .lineLimit(2)
                                    } else if let sub = msg.subject, !sub.isEmpty {
                                        Text(sub)
                                            .font(.caption)
                                            .foregroundStyle(AppConstants.Colors.textSecondary)
                                            .lineLimit(1)
                                    }
                                    if let short = msg.orderReferenceShort, let full = msg.linkedOrderId {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Label(short, systemImage: "number.square.fill")
                                                .font(.caption.weight(.semibold))
                                                .foregroundStyle(AppConstants.Colors.accent)
                                            Text(full)
                                                .font(.caption2)
                                                .monospaced()
                                                .foregroundStyle(AppConstants.Colors.textSecondary)
                                                .lineLimit(2)
                                                .minimumScaleFactor(0.85)
                                                .textSelection(.enabled)
                                        }
                                    }
                                    Text(msg.message)
                                        .font(.caption)
                                        .foregroundStyle(AppConstants.Colors.textSecondary)
                                        .lineLimit(2)
                                }
                                Spacer()
                                if msg.readAt == nil {
                                    Circle()
                                        .fill(AppConstants.Colors.accent)
                                        .frame(width: 8, height: 8)
                                }
                                if let created = msg.createdAt {
                                    Text(created.shortDateString)
                                        .font(.caption2)
                                        .foregroundStyle(AppConstants.Colors.textSecondary)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        #if os(iOS)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                Task { await viewModel.deleteContactMessage(msg) }
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                        #endif
                        .contextMenu {
                            Button(role: .destructive) {
                                Task { await viewModel.deleteContactMessage(msg) }
                            } label: {
                                Label("Delete quote", systemImage: "trash")
                            }
                        }
                    }
                }
            }
            .navigationTitle("Quotes")
            .inlineNavigationTitle()
            .refreshable { await viewModel.loadQuoteRequests() }
            .onAppear { applyScrollToMessageId() }
            .onChange(of: viewModel.scrollToMessageId) { _, _ in applyScrollToMessageId() }
            .onChange(of: viewModel.quoteRequests.count) { _, _ in applyScrollToMessageId() }
            .macOSReduceSheetTitleGap()
            #if os(macOS)
            .padding(.top, -8)
            #endif
            .sheet(item: $selectedMessage) { msg in
                ContactMessageDetailSheet(
                    viewModel: viewModel,
                    message: msg,
                    onDismiss: { selectedMessage = nil },
                    onViewOrderFromMessage: onViewOrderFromMessage,
                    allowDelete: true
                )
                .macOSAdminSheetSize()
            }
        }
    }
}

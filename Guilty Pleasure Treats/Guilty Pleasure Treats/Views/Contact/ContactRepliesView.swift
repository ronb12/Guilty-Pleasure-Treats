//
//  ContactRepliesView.swift
//  Guilty Pleasure Treats
//
//  Customer view: replies from the store to their contact messages.
//

import SwiftUI

struct ContactRepliesView: View {
    @State private var replies: [ContactMessageReply] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var showCompose = false
    private let api = VercelService.shared

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let err = errorMessage {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.title)
                        .foregroundStyle(.orange)
                    Text(err)
                        .font(.subheadline)
                        .foregroundStyle(AppConstants.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if replies.isEmpty {
                VStack(spacing: 20) {
                    ContentUnavailableView(
                    "No messages yet",
                    systemImage: "envelope.open",
                    description: Text("When you contact us and we reply, you’ll see it here.")
                )
                Button("Send a message") {
                    showCompose = true
                }
                    .buttonStyle(.borderedProminent)
                    .tint(AppConstants.Colors.accent)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(replies) { reply in
                        VStack(alignment: .leading, spacing: 8) {
                            if let sub = reply.subject, !sub.isEmpty {
                                Text(sub)
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(AppConstants.Colors.textPrimary)
                            }
                            Text(reply.body)
                                .font(.body)
                                .foregroundStyle(AppConstants.Colors.textPrimary)
                                .textSelection(.enabled)
                            if let created = reply.createdAt {
                                Text(created.shortDateString)
                                    .font(.caption)
                                    .foregroundStyle(AppConstants.Colors.textSecondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .navigationTitle("Messages")
        .inlineNavigationTitle()
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showCompose = true
                } label: {
                    Label("New message", systemImage: "square.and.pencil")
                }
            }
        }
        .sheet(isPresented: $showCompose, onDismiss: {
            Task { await loadReplies() }
        }) {
            ContactView()
        }
        .refreshable { await loadReplies() }
        .task { await loadReplies() }
    }

    private func loadReplies() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            replies = try await api.fetchContactReplies()
        } catch {
            errorMessage = (error as? VercelAPIError)?.message ?? "Couldn’t load messages."
        }
    }
}

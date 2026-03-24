//
//  HTMLPreviewWebView.swift
//  Guilty Pleasure Treats
//
//  Renders HTML for admin previews (e.g. newsletter) with WKWebView.
//

import SwiftUI
import WebKit
#if os(iOS)
import UIKit
#endif

enum HTMLPreviewDocument {
    /// Wraps a fragment in a minimal document so email-style HTML previews correctly.
    static func wrapped(_ htmlFragmentOrFull: String) -> String {
        let t = htmlFragmentOrFull.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else {
            return "<!DOCTYPE html><html><head><meta charset=\"utf-8\"></head><body></body></html>"
        }
        if t.range(of: "<html", options: .caseInsensitive) != nil { return t }
        return """
        <!DOCTYPE html>
        <html><head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <style>
          body { font-family: -apple-system, BlinkMacSystemFont, sans-serif; padding: 16px; color: #333; margin: 0; }
          img { max-width: 100%; height: auto; }
        </style>
        </head><body>\(t)</body></html>
        """
    }
}

#if os(iOS)
struct HTMLPreviewWebView: UIViewRepresentable {
    let html: String

    func makeUIView(context: Context) -> WKWebView {
        let v = WKWebView()
        v.scrollView.isScrollEnabled = true
        v.isOpaque = true
        v.backgroundColor = .systemBackground
        return v
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        uiView.loadHTMLString(HTMLPreviewDocument.wrapped(html), baseURL: nil)
    }
}
#elseif os(macOS)
struct HTMLPreviewWebView: NSViewRepresentable {
    let html: String

    func makeNSView(context: Context) -> WKWebView {
        let v = WKWebView()
        return v
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {
        nsView.loadHTMLString(HTMLPreviewDocument.wrapped(html), baseURL: nil)
    }
}
#endif

/// Full-screen style sheet: subject line + HTML (or plain text if no HTML).
struct NewsletterEmailPreviewSheet: View {
    let subject: String
    let htmlBody: String
    let textBody: String
    var onDismiss: () -> Void

    @Environment(\.dismiss) private var dismiss

    private var htmlTrim: String { htmlBody.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var textTrim: String { textBody.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Subject")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(AppConstants.Colors.textSecondary)
                    Text(subject.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "(No subject yet)" : subject.trimmingCharacters(in: .whitespacesAndNewlines))
                        .font(.headline)
                        .foregroundStyle(AppConstants.Colors.textPrimary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(AppConstants.Layout.cardPadding)
                .background(AppConstants.Colors.cardBackground)

                Divider()

                if !htmlTrim.isEmpty {
                    HTMLPreviewWebView(html: htmlTrim)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if !textTrim.isEmpty {
                    ScrollView {
                        Text(textTrim)
                            .font(.body)
                            .foregroundStyle(AppConstants.Colors.textPrimary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)
                            .padding()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    Spacer()
                    Text("Add HTML or plain text in the editor to preview.")
                        .font(.subheadline)
                        .foregroundStyle(AppConstants.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                    Spacer()
                }
            }
            .background(AppConstants.Colors.secondary)
            .navigationTitle("Preview")
            .inlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        onDismiss()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(AppConstants.Colors.accent)
                }
            }
            .macOSReduceSheetTitleGap()
        }
    }
}

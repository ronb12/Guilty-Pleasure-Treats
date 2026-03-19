//
//  ErrorMessageBanner.swift
//  Guilty Pleasure Treats
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif
#if os(macOS)
import AppKit
#endif

struct ErrorMessageBanner: View {
    let message: String
    /// Optional support/debug payload (e.g. JSON + requestId) for "Copy details".
    var debugCopyText: String? = nil
    let dismiss: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.white)
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 8)
                Button("Dismiss", action: dismiss)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.9))
            }
            if let debug = debugCopyText, !debug.isEmpty {
                Button {
                    copyToPasteboard(debug)
                } label: {
                    Text("Copy debug info")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.white.opacity(0.2))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding()
        .background(Color.red.opacity(0.9))
        .clipShape(RoundedRectangle(cornerRadius: AppConstants.Layout.buttonCornerRadius))
    }

    private func copyToPasteboard(_ text: String) {
        #if canImport(UIKit)
        UIPasteboard.general.string = text
        #elseif os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        #endif
    }
}

//
//  Platform.swift
//  Guilty Pleasure Treats
//
//  Cross-platform types and helpers for iOS and macOS.
//

import SwiftUI

#if os(iOS)
import UIKit
public typealias PlatformImage = UIImage
#elseif os(macOS)
import AppKit
public typealias PlatformImage = NSImage
#endif

extension Image {
    /// Create a SwiftUI Image from a platform image (UIImage on iOS, NSImage on macOS).
    init(platformImage: PlatformImage) {
        #if os(iOS)
        self.init(uiImage: platformImage)
        #else
        self.init(nsImage: platformImage)
        #endif
    }
}

#if os(iOS)
extension View {
    /// Applies `.navigationBarTitleDisplayMode(.inline)` on iOS; no-op on macOS.
    func inlineNavigationTitle() -> some View {
        self.navigationBarTitleDisplayMode(.inline)
    }
    /// Applies `.navigationBarTitleDisplayMode(.large)` on iOS; no-op on macOS.
    func largeNavigationTitle() -> some View {
        self.navigationBarTitleDisplayMode(.large)
    }
}
#else
extension View {
    func inlineNavigationTitle() -> some View { self }
    func largeNavigationTitle() -> some View { self }
}
#endif

/// Toolbar placement for trailing items: .topBarTrailing on iOS, .primaryAction on macOS.
var toolbarTrailingPlacement: ToolbarItemPlacement {
    #if os(iOS)
    return .topBarTrailing
    #else
    return .primaryAction
    #endif
}

/// Cross-platform light gray background (systemGray6 on iOS, controlBackground on macOS).
var platformSystemGrayBackground: Color {
    #if os(iOS)
    return Color(uiColor: .systemGray6)
    #else
    return Color(nsColor: .controlBackgroundColor)
    #endif
}

#if os(macOS)
/// Max width for main content on macOS so lists/menus don’t over-stretch on wide windows.
let adminProductPhotoHeight: CGFloat = 96
#else
let adminProductPhotoHeight: CGFloat = 120
#endif

#if os(macOS)
/// Max width for main content on macOS so lists/menus don't over-stretch on wide windows.
let macOSContentMaxWidth: CGFloat = 880

extension View {
    /// On macOS, constrains width and centers content; no-op on iOS.
    func macOSConstrainedContent() -> some View {
        self.frame(maxWidth: macOSContentMaxWidth)
            .frame(maxWidth: .infinity)
    }
    /// Top padding so sheet content isn’t cut off under the title bar on macOS.
    func macOSSheetTopPadding() -> some View {
        self.padding(.top, 20)
    }
    /// Bounded size so sheet fits on screen, content scrolls, and toolbar buttons stay accessible.
    func macOSAdminSheetSize() -> some View {
        self.frame(minWidth: 700, maxWidth: 780, minHeight: 400, maxHeight: 540)
    }
    /// Larger bounded size for product add/edit and add order; max height keeps window on screen so Cancel/Save stay visible.
    func macOSAdminSheetSizeLarge() -> some View {
        self.frame(minWidth: 640, maxWidth: 860, minHeight: 500, maxHeight: 700)
    }
    /// Tighter spacing so edit sheet content fits without scrolling.
    func macOSCompactFormContent() -> some View {
        self.controlSize(.small)
    }
    /// Horizontal padding so form content isn't cut off at sheet edges on macOS.
    func macOSEditSheetPadding() -> some View {
        self.padding(.horizontal, 12)
    }
    /// Reduces the large gap between sheet top and navigation title on macOS.
    func macOSReduceSheetTitleGap() -> some View {
        self.padding(.top, -20)
    }
}
#else
extension View {
    func macOSConstrainedContent() -> some View { self }
    func macOSSheetTopPadding() -> some View { self }
    func macOSAdminSheetSize() -> some View { self }
    func macOSAdminSheetSizeLarge() -> some View { self }
    func macOSCompactFormContent() -> some View { self }
    func macOSEditSheetPadding() -> some View { self }
    func macOSReduceSheetTitleGap() -> some View { self }
}
#endif

#if os(macOS)
extension PlatformImage {
    /// JPEG data for upload; mirrors UIImage.jpegData(compressionQuality:) on iOS.
    func jpegData(compressionQuality: Double) -> Data? {
        guard let tiff = tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff) else { return nil }
        return rep.representation(using: .jpeg, properties: [.compressionFactor: NSNumber(value: compressionQuality)])
    }
}
#endif

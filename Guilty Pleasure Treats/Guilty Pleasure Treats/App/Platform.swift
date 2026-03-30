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
    /// Applies `.navigationBarTitleDisplayMode(.inline)` on iOS.
    func inlineNavigationTitle() -> some View {
        self.navigationBarTitleDisplayMode(.inline)
    }
    /// Applies `.navigationBarTitleDisplayMode(.large)` on iOS.
    func largeNavigationTitle() -> some View {
        self.navigationBarTitleDisplayMode(.large)
    }
}
#elseif os(macOS)
extension View {
    /// macOS `NavigationStack` defaults to a tall title strip; use inline so content sits under the tab bar like other admin tabs (deployment macOS 14+).
    func inlineNavigationTitle() -> some View {
        self.toolbarTitleDisplayMode(.inline)
    }
    func largeNavigationTitle() -> some View {
        self.toolbarTitleDisplayMode(.automatic)
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
    /// Pulls the whole sheet (including `NavigationStack` title) closer to the window top — SwiftUI adds a large default gap on macOS.
    func macOSAdminSheetSize() -> some View {
        self.padding(.top, -32)
            .frame(minWidth: 700, maxWidth: 780, minHeight: 400, maxHeight: 540)
    }
    /// Larger bounded size for product add/edit and add order; max height keeps window on screen so Cancel/Save stay visible.
    func macOSAdminSheetSizeLarge() -> some View {
        self.padding(.top, -32)
            .frame(minWidth: 640, maxWidth: 860, minHeight: 500, maxHeight: 700)
    }
    /// Multi-section admin forms (e.g. promotions): shorter min width so sheets fit inside the admin window, extra height so grouped `Form` + toolbar aren’t clipped.
    func macOSAdminSheetSizeForm() -> some View {
        self.padding(.top, -32)
            .frame(minWidth: 520, idealWidth: 600, maxWidth: 720, minHeight: 460, idealHeight: 560, maxHeight: 720)
    }
    /// Compact controls on iOS only. On macOS, `.small` Form rows often collide labels with fields.
    func macOSCompactFormContent() -> some View {
        self
    }
    /// Horizontal padding so form content isn’t clipped or cramped at sheet edges on macOS.
    func macOSEditSheetPadding() -> some View {
        self.padding(.horizontal, 20)
    }
    /// Form style that gives clearer section spacing on macOS admin sheets.
    func macOSGroupedFormStyle() -> some View {
        self.formStyle(.grouped)
    }
    /// Historically applied negative padding on `Form`, which does **not** move the navigation title on macOS.
    /// Title tightening is handled by `macOSAdminSheetSize` / `macOSAdminSheetSizeLarge` on the sheet root instead.
    func macOSReduceSheetTitleGap() -> some View {
        self
    }
}
#else
extension View {
    func macOSConstrainedContent() -> some View { self }
    func macOSSheetTopPadding() -> some View { self }
    func macOSAdminSheetSize() -> some View { self }
    func macOSAdminSheetSizeLarge() -> some View { self }
    func macOSAdminSheetSizeForm() -> some View { self }
    func macOSCompactFormContent() -> some View { self }
    func macOSEditSheetPadding() -> some View { self }
    func macOSGroupedFormStyle() -> some View { self }
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

extension PlatformImage {
    /// Image bytes for admin uploads (`/api/upload` JSON base64). Tries JPEG, then PNG.
    func imageDataForAdminUpload(compressionQuality: Double = 0.72) -> Data? {
        #if os(iOS)
        if let j = jpegData(compressionQuality: compressionQuality), !j.isEmpty { return j }
        if let p = pngData(), !p.isEmpty { return p }
        return nil
        #elseif os(macOS)
        if let j = jpegData(compressionQuality: compressionQuality), !j.isEmpty { return j }
        guard let tiff = tiffRepresentation, let rep = NSBitmapImageRep(data: tiff) else { return nil }
        let png = rep.representation(using: .png, properties: [:])
        return (png != nil && !png!.isEmpty) ? png : nil
        #else
        return nil
        #endif
    }
}

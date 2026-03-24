//
//  NewsletterAssetPreprocessor.swift
//  Guilty Pleasure Treats
//
//  Compress images for Blob upload; pass PDF through for hosted download links.
//

import Foundation
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

enum NewsletterAssetPreprocessor {

    /// Returns data, MIME type, and a safe filename for the upload path.
    static func prepareFile(data: Data, pathExtension: String) -> (data: Data, mime: String, filename: String) {
        let ext = pathExtension.lowercased()
        if ext == "pdf" {
            return (data, "application/pdf", "newsletter.pdf")
        }
        #if os(iOS)
        if let ui = UIImage(data: data), let j = ui.jpegData(compressionQuality: 0.82) {
            return (j, "image/jpeg", "design.jpg")
        }
        #elseif os(macOS)
        if let img = NSImage(data: data), let j = img.jpegData(compressionQuality: 0.82) {
            return (j, "image/jpeg", "design.jpg")
        }
        #endif
        if ext == "png" {
            return (data, "image/png", "design.png")
        }
        return (data, "image/jpeg", "design.jpg")
    }
}

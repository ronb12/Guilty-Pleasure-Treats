//
//  QRCodeView.swift
//  Guilty Pleasure Treats
//
//  Renders a QR code from a string (e.g. payment link for Cash App).
//

import SwiftUI
import CoreImage.CIFilterBuiltins

struct QRCodeView: View {
    let content: String
    var size: CGFloat = 200
    
    var body: some View {
        if let image = qrImage(from: content) {
            Image(platformImage: image)
                .interpolation(.none)
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
        } else {
            RoundedRectangle(cornerRadius: 8)
                .fill(AppConstants.Colors.textSecondary.opacity(0.2))
                .frame(width: size, height: size)
                .overlay {
                    Text("QR")
                        .font(.caption)
                        .foregroundStyle(AppConstants.Colors.textSecondary)
                }
        }
    }
    
    private func qrImage(from string: String) -> PlatformImage? {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        filter.correctionLevel = "M"
        guard let output = filter.outputImage else { return nil }
        let scaled = output.transformed(by: CGAffineTransform(scaleX: 4, y: 4))
        guard let cgImage = context.createCGImage(scaled, from: scaled.extent) else { return nil }
        #if os(iOS)
        return UIImage(cgImage: cgImage)
        #else
        return NSImage(cgImage: cgImage, size: NSSize(width: scaled.extent.width, height: scaled.extent.height))
        #endif
    }
}

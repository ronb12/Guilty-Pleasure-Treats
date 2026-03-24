//
//  NewsletterHTMLTemplate.swift
//  Guilty Pleasure Treats
//
//  Professional, email-client-friendly HTML shells (inline styles). Optional Canva image embed.
//

import Foundation

enum NewsletterHTMLTemplate {

    static func escape(_ s: String) -> String {
        s.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }

    /// Image block suitable for Canva exports (PNG/JPEG hosted on your CDN/blob).
    static func imageEmbedBlock(imageURL: String, altText: String) -> String {
        let url = escape(imageURL)
        let alt = escape(altText)
        return """
        <div style="margin:0;padding:0 0 24px;text-align:center;">
          <img src="\(url)" alt="\(alt)" width="600" style="max-width:100%;width:100%;max-width:600px;height:auto;display:block;border:0;outline:none;text-decoration:none;margin:0 auto;" />
        </div>
        """
    }

    /// Link block for a PDF exported from Canva (shows in email as download; many clients won’t render PDF inline).
    static func pdfLinkBlock(pdfURL: String, linkLabel: String) -> String {
        let u = escape(pdfURL)
        let label = escape(linkLabel)
        return """
        <p style="margin:0 0 16px;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif;font-size:16px;line-height:1.5;text-align:center;">
          <a href="\(u)" style="color:#8B4513;font-weight:600;">\(label)</a>
        </p>
        <p style="margin:0;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif;font-size:13px;line-height:1.4;color:#666;text-align:center;">
          Tip: For a design that appears directly in the email, export from Canva as PNG or JPEG and use Upload design image.
        </p>
        """
    }

    /// Full newsletter layout: header band, body copy area, footer — bakery-appropriate styling (no external CSS).
    static func professionalEmail(
        storeName: String,
        preheader: String,
        bodyParagraphs: [String],
        contactEmail: String?,
        accentHex: String = "#6B4423"
    ) -> String {
        let name = escape(storeName)
        let pre = escape(preheader)
        let accent = escape(accentHex)
        let mail = contactEmail.map { escape($0) } ?? ""
        let paras = bodyParagraphs.map { p in
            let t = escape(p)
            return "<p style=\"margin:0 0 16px;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif;font-size:16px;line-height:1.6;color:#333;\">\(t)</p>"
        }.joined()

        let contactFooter: String
        if !mail.isEmpty {
            contactFooter = """
            <a href="mailto:\(mail)" style="color:\(accent);text-decoration:none;font-weight:600;">\(mail)</a>
            """
        } else {
            contactFooter = ""
        }

        return """
        <!DOCTYPE html>
        <html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>\(name)</title></head>
        <body style="margin:0;padding:0;background-color:#f3f0eb;">
        <div style="display:none;max-height:0;overflow:hidden;">\(pre)</div>
        <table role="presentation" cellpadding="0" cellspacing="0" width="100%" style="background-color:#f3f0eb;">
          <tr>
            <td align="center" style="padding:28px 12px;">
              <table role="presentation" cellpadding="0" cellspacing="0" width="600" style="max-width:600px;width:100%;background-color:#ffffff;border-radius:16px;overflow:hidden;box-shadow:0 4px 24px rgba(0,0,0,0.08);">
                <tr>
                  <td style="padding:32px 28px;background:linear-gradient(145deg,\(accent) 0%,#b8956a 100%);text-align:center;">
                    <p style="margin:0;font-family:Georgia,'Times New Roman',serif;font-size:28px;line-height:1.2;color:#ffffff;font-weight:600;letter-spacing:0.02em;">\(name)</p>
                    <p style="margin:12px 0 0;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif;font-size:14px;line-height:1.4;color:rgba(255,255,255,0.92);">Handcrafted treats &amp; custom orders</p>
                  </td>
                </tr>
                <tr>
                  <td style="padding:32px 28px 24px;">
                    \(paras)
                  </td>
                </tr>
                <tr>
                  <td style="padding:20px 28px 28px;background-color:#faf8f5;border-top:1px solid #ebe6df;text-align:center;">
                    <p style="margin:0;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif;font-size:12px;line-height:1.5;color:#888;">
                      \(contactFooter.isEmpty ? "Thank you for supporting local." : "Questions? \(contactFooter)")
                    </p>
                    <p style="margin:10px 0 0;font-size:11px;color:#aaa;">You’re receiving this because you’ve ordered from us or created an account.</p>
                  </td>
                </tr>
              </table>
            </td>
          </tr>
        </table>
        </body></html>
        """
    }
}

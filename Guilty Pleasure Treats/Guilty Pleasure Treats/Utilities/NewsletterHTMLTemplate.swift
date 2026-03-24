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
        <div style="margin:0;padding:0 0 28px;text-align:center;">
          <img src="\(url)" alt="\(alt)" width="600" style="max-width:100%;width:100%;max-width:600px;height:auto;display:block;border:0;outline:none;text-decoration:none;margin:0 auto;box-shadow:0 12px 40px rgba(26,14,18,0.08);" />
        </div>
        """
    }

    /// Link block for a PDF exported from Canva (shows in email as download; many clients won’t render PDF inline).
    static func pdfLinkBlock(pdfURL: String, linkLabel: String) -> String {
        let u = escape(pdfURL)
        let label = escape(linkLabel)
        return """
        <p style="margin:0 0 16px;font-family:Georgia,'Times New Roman',serif;font-size:16px;line-height:1.5;text-align:center;">
          <a href="\(u)" style="color:#7d5c3a;font-weight:600;">\(label)</a>
        </p>
        <p style="margin:0;font-family:Georgia,'Times New Roman',serif;font-size:13px;line-height:1.5;color:#7a6a5c;text-align:center;">
          Tip: For a design that appears directly in the email, export from Canva as PNG or JPEG and use Upload design image.
        </p>
        """
    }

    /// Full newsletter layout: refined palette, optional hosted app icon URL, inline styles for email clients.
    /// `prependInnerHTML` is trusted HTML (e.g. uploaded Canva blocks) inserted above body paragraphs.
    /// `accentHex` tints the hero gradient mid-tone (rose-mauve); defaults suit a luxury bakery look.
    static func professionalEmail(
        storeName: String,
        preheader: String,
        bodyParagraphs: [String],
        contactEmail: String?,
        iconImageURL: String? = nil,
        prependInnerHTML: String? = nil,
        accentHex: String = "#b76e79"
    ) -> String {
        let name = escape(storeName)
        let pre = escape(preheader)
        let accent = escape(accentHex)
        let mail = contactEmail.map { escape($0) } ?? ""
        let paras = bodyParagraphs.map { p in
            let t = escape(p).replacingOccurrences(of: "\n", with: "<br />")
            return "<p style=\"margin:0 0 22px;font-family:'Cormorant Garamond',Georgia,'Times New Roman',serif;font-size:19px;line-height:1.65;color:#2c1810;font-weight:400;\">\(t)</p>"
        }.joined()

        let contactFooter: String
        if !mail.isEmpty {
            contactFooter = """
            <a href="mailto:\(mail)" style="color:#7d5c3a;text-decoration:none;font-weight:600;">\(mail)</a>
            """
        } else {
            contactFooter = ""
        }

        let iconBlock: String
        if let raw = iconImageURL?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty {
            let iu = escape(raw)
            iconBlock = """
            <img src="\(iu)" alt="\(name)" width="80" height="80" style="display:block;margin:0 auto 22px;width:80px;height:80px;border-radius:20px;border:2px solid rgba(212,175,110,0.55);box-shadow:0 8px 28px rgba(0,0,0,0.35);" />
            """
        } else {
            iconBlock = ""
        }

        return """
        <!DOCTYPE html>
        <html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>\(name)</title><link href="https://fonts.googleapis.com/css2?family=Cormorant+Garamond:ital,wght@0,400;0,500;1,400&family=Dancing+Script:wght@600;700&family=Playfair+Display:ital@0;1&display=swap" rel="stylesheet"></head>
        <body style="margin:0;padding:0;background-color:#f5f0ea;">
        <div style="display:none;max-height:0;overflow:hidden;">\(pre)</div>
        <table role="presentation" cellpadding="0" cellspacing="0" width="100%" style="background-color:#f5f0ea;">
          <tr>
            <td align="center" style="padding:36px 16px;">
              <table role="presentation" cellpadding="0" cellspacing="0" width="600" style="max-width:600px;width:100%;background-color:#fdfcfa;border-radius:4px;overflow:hidden;border:1px solid #e8e0d8;box-shadow:0 20px 56px rgba(26,14,18,0.14);">
                <tr>
                  <td style="height:3px;line-height:3px;font-size:0;background:linear-gradient(90deg,#c9a962 0%,#e8d5a8 50%,#c9a962 100%);">&nbsp;</td>
                </tr>
                <tr>
                  <td style="padding:36px 36px 40px;background:linear-gradient(165deg,#1f1216 0%,\(accent) 46%,#2d181e 100%);text-align:center;">
                    \(iconBlock)
                    <p style="margin:0;font-family:'Dancing Script',Georgia,'Times New Roman',serif;font-size:38px;line-height:1.15;color:#fdf8f3;font-weight:600;letter-spacing:0.06em;text-shadow:0 2px 16px rgba(0,0,0,0.45);">\(name)</p>
                    <p style="margin:16px 0 0;font-family:'Playfair Display',Georgia,serif;font-size:15px;line-height:1.5;font-style:italic;color:#e8dcc8;letter-spacing:0.06em;">Every bite&#8217;s a little indulgence</p>
                  </td>
                </tr>
                <tr>
                  <td style="padding:40px 40px 36px;background-color:#fdfcfa;">
                    \(prependInnerHTML ?? "")
                    \(paras)
                  </td>
                </tr>
                <tr>
                  <td style="padding:24px 36px 32px;background-color:#f3ebe4;border-top:1px solid #e0d4c8;text-align:center;">
                    <p style="margin:0;font-family:Georgia,'Times New Roman',serif;font-size:12px;line-height:1.65;color:#6b5344;letter-spacing:0.02em;">
                      \(contactFooter.isEmpty ? "With gratitude for your support." : "Questions? \(contactFooter)")
                    </p>
                    <p style="margin:14px 0 0;font-family:Georgia,serif;font-size:10px;line-height:1.5;color:#8a7a6c;letter-spacing:0.04em;text-transform:uppercase;">You’re receiving this because you’ve ordered from us or created an account.</p>
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

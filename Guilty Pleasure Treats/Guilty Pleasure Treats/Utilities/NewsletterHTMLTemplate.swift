//
//  NewsletterHTMLTemplate.swift
//  Guilty Pleasure Treats
//
//  Professional, email-client-friendly HTML shells (inline styles). Optional Canva image embed.
//  Pinks match Asset Catalog light mode: AppAccent, AppPrimary, AppSecondary, AppTextPrimary.
//

import Foundation

enum NewsletterHTMLTemplate {

    // MARK: - Brand colors (Assets.xcassets — light appearance)
    /// AppAccent — main brand pink (RGB 0.91, 0.26, 0.58)
    private static let appAccentHex = "#E84294"
    /// AppPrimary — soft pink wash (RGB 0.99, 0.89, 0.93)
    private static let appPrimaryHex = "#FCE3ED"
    /// AppSecondary — near-white pink tint (RGB 0.996, 0.97, 0.98)
    private static let appSecondaryHex = "#FEF7FA"
    /// AppTextPrimary — body text (RGB 0.24, 0.13, 0.16)
    private static let appTextPrimaryHex = "#3D2129"

    /// Header background must be a safe hex for `bgcolor` + CSS (no gradients — Gmail strips them).
    private static func sanitizedHeaderBgHex(_ raw: String) -> String {
        let t = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let re = try? NSRegularExpression(pattern: "^#(?:[0-9A-Fa-f]{3}|[0-9A-Fa-f]{6})$"),
              re.firstMatch(in: t, range: NSRange(t.startIndex..., in: t)) != nil
        else { return appAccentHex }
        return t
    }

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
          <img src="\(url)" alt="\(alt)" width="600" style="max-width:100%;width:100%;max-width:600px;height:auto;display:block;border:0;outline:none;text-decoration:none;margin:0 auto;box-shadow:0 12px 40px rgba(232,66,148,0.14);" />
        </div>
        """
    }

    /// Link block for a PDF exported from Canva (shows in email as download; many clients won’t render PDF inline).
    static func pdfLinkBlock(pdfURL: String, linkLabel: String) -> String {
        let u = escape(pdfURL)
        let label = escape(linkLabel)
        return """
        <p style="margin:0 0 16px;font-family:Georgia,'Times New Roman',serif;font-size:16px;line-height:1.5;text-align:center;">
          <a href="\(u)" style="color:\(appAccentHex);font-weight:600;">\(label)</a>
        </p>
        <p style="margin:0;font-family:Georgia,'Times New Roman',serif;font-size:13px;line-height:1.5;color:#9d174d;text-align:center;">
          Tip: For a design that appears directly in the email, export from Canva as PNG or JPEG and use Upload design image.
        </p>
        """
    }

    /// Full newsletter layout: app pink palette (Asset Catalog), optional hosted app icon URL.
    /// `prependInnerHTML` is trusted HTML (e.g. uploaded Canva blocks) inserted above body paragraphs.
    /// `accentHex` overrides the hero mid gradient stop; defaults to AppAccent pink.
    static func professionalEmail(
        storeName: String,
        preheader: String,
        bodyParagraphs: [String],
        contactEmail: String?,
        iconImageURL: String? = nil,
        prependInnerHTML: String? = nil,
        accentHex: String? = nil
    ) -> String {
        let name = escape(storeName)
        let pre = escape(preheader)
        // Solid header color only — email clients (especially Gmail) often strip linear-gradient and external fonts.
        let trimmedAccent = accentHex?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let headerBgHex = sanitizedHeaderBgHex(trimmedAccent.isEmpty ? appAccentHex : trimmedAccent)
        let accentMid = escape(headerBgHex)
        let mail = contactEmail.map { escape($0) } ?? ""
        let paras = bodyParagraphs.map { p in
            let t = escape(p).replacingOccurrences(of: "\n", with: "<br />")
            return "<p style=\"margin:0 0 22px;font-family:'Cormorant Garamond',Georgia,'Times New Roman',serif;font-size:19px;line-height:1.65;color:\(appTextPrimaryHex);font-weight:400;\">\(t)</p>"
        }.joined()

        let contactFooter: String
        if !mail.isEmpty {
            contactFooter = """
            <a href="mailto:\(mail)" style="color:\(appAccentHex);text-decoration:none;font-weight:600;">\(mail)</a>
            """
        } else {
            contactFooter = ""
        }

        // Web-safe fonts only (no Google Fonts `<link>` — many clients block it; preview then matches inbox).
        let titleStyle = "margin:0;font-family:Georgia,'Times New Roman',serif;font-size:28px;line-height:1.15;color:#ffffff;font-weight:700;letter-spacing:0.06em;text-transform:none;"
        let taglineStyle = "margin:4px 0 0;font-family:Georgia,'Times New Roman',serif;font-size:13px;line-height:1.35;font-style:italic;color:#ffffff;letter-spacing:0.03em;opacity:0.95;"
        let headerInner: String
        if let raw = iconImageURL?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty {
            let iu = escape(raw)
            let img = """
            <img src="\(iu)" alt="\(name)" width="52" height="52" style="display:block;width:52px;height:52px;border-radius:14px;border:2px solid rgba(255,255,255,0.9);box-shadow:0 4px 14px rgba(199,61,132,0.38);" />
            """
            headerInner = """
            <table role="presentation" cellpadding="0" cellspacing="0" width="100%" style="border-collapse:collapse;">
              <tr>
                <td style="width:52px;vertical-align:middle;padding:0 12px 0 0;">\(img)</td>
                <td style="vertical-align:middle;text-align:left;padding:0;">
                  <p style="\(titleStyle)">\(name)</p>
                  <p style="\(taglineStyle)">Every bite&#8217;s a little indulgence</p>
                </td>
              </tr>
            </table>
            """
        } else {
            headerInner = """
            <p style="\(titleStyle)text-align:center;">\(name)</p>
            <p style="\(taglineStyle)text-align:center;">Every bite&#8217;s a little indulgence</p>
            """
        }

        return """
        <!DOCTYPE html>
        <html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><meta name="color-scheme" content="light"><meta name="supported-color-schemes" content="light"><title>\(name)</title></head>
        <body style="margin:0;padding:0;background-color:\(appPrimaryHex);">
        <div style="display:none;max-height:0;overflow:hidden;">\(pre)</div>
        <table role="presentation" cellpadding="0" cellspacing="0" width="100%" style="background-color:\(appPrimaryHex);">
          <tr>
            <td align="center" style="padding:20px 12px;">
              <table role="presentation" cellpadding="0" cellspacing="0" width="600" style="max-width:600px;width:100%;background-color:\(appSecondaryHex);border-radius:4px;overflow:hidden;border:1px solid #f5d0e4;box-shadow:0 20px 48px rgba(232,66,148,0.18);">
                <tr>
                  <td bgcolor="\(headerBgHex)" style="height:3px;line-height:3px;font-size:0;background-color:\(accentMid);">&nbsp;</td>
                </tr>
                <tr>
                  <td bgcolor="\(headerBgHex)" style="padding:14px 22px 16px;background-color:\(accentMid);">
                    \(headerInner)
                  </td>
                </tr>
                <tr>
                  <td style="padding:28px 32px 32px;background-color:\(appSecondaryHex);">
                    \(prependInnerHTML ?? "")
                    \(paras)
                  </td>
                </tr>
                <tr>
                  <td style="padding:24px 36px 32px;background-color:\(appPrimaryHex);border-top:1px solid #f5c6de;text-align:center;">
                    <p style="margin:0;font-family:Georgia,'Times New Roman',serif;font-size:12px;line-height:1.65;color:#9d174d;letter-spacing:0.02em;">
                      \(contactFooter.isEmpty ? "With gratitude for your support." : "Questions? \(contactFooter)")
                    </p>
                    <p style="margin:14px 0 0;font-family:Georgia,serif;font-size:10px;line-height:1.5;color:#be185d;letter-spacing:0.04em;text-transform:uppercase;">You’re receiving this because you’ve ordered from us or created an account.</p>
                    <p style="margin:12px 0 0;font-family:Georgia,serif;font-size:11px;line-height:1.5;color:#be185d;">
                      <a href="{{UNSUBSCRIBE_URL}}" style="color:\(appAccentHex);text-decoration:underline;">Unsubscribe from marketing emails</a>
                    </p>
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

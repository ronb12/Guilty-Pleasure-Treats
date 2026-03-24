//
//  Newsletter.swift
//  Guilty Pleasure Treats
//
//  Admin newsletter send (API: POST /api/admin/newsletter).
//

import Foundation

struct NewsletterSendResult: Decodable {
    let sent: Int
    let failed: Int
    let total: Int
    let attempted: Int
    let truncated: Bool
    let sampleErrors: [NewsletterSendSampleError]?

    struct NewsletterSendSampleError: Decodable {
        let to: String
        let message: String
    }
}

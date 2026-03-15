//
//  ImageGenerationService.swift
//  Guilty Pleasure Treats
//
//  Calls an AI image generation API with a text prompt and returns image data.
//  Configure baseURL (and optional API key) for your backend or provider.
//

import Foundation

enum ImageGenerationError: LocalizedError {
    case invalidURL
    case noImageInResponse
    case invalidResponse(Int, String?)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid API configuration."
        case .noImageInResponse: return "No image was returned from the service."
        case .invalidResponse(let code, let msg): return "Request failed (\(code)): \(msg ?? "Unknown error")."
        }
    }
}

final class ImageGenerationService {
    static let shared = ImageGenerationService()
    
    /// Your backend URL that accepts a prompt and returns image URL or base64.
    /// Example: "https://your-api.com/generate-cake-image"
    private let baseURL: String
    
    /// Optional API key header name and value (e.g. "Authorization", "Bearer sk-...").
    private let apiKeyHeader: (String, String)?
    
    private init(
        baseURL: String = AppConstants.imageGenerationBaseURL,
        apiKeyHeader: (String, String)? = nil
    ) {
        self.baseURL = baseURL
        self.apiKeyHeader = apiKeyHeader
    }
    
    /// Generate an image from a text prompt. Returns image data (e.g. JPEG).
    /// Backend contract: POST with JSON {"prompt": "..."}; response either
    /// {"imageUrl": "https://..."} or {"imageBase64": "..."} or raw image bytes with Content-Type image/*.
    func generateImage(prompt: String) async throws -> Data {
        guard let url = URL(string: baseURL), !baseURL.contains("your-") else {
            throw ImageGenerationError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let (name, value) = apiKeyHeader {
            request.setValue(value, forHTTPHeaderField: name)
        }
        let body = ["prompt": prompt]
        request.httpBody = try JSONEncoder().encode(body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw ImageGenerationError.invalidResponse(0, "Invalid response")
        }
        guard (200...299).contains(http.statusCode) else {
            let message = String(data: data, encoding: .utf8)
            throw ImageGenerationError.invalidResponse(http.statusCode, message)
        }
        
        if let contentType = http.value(forHTTPHeaderField: "Content-Type"),
           contentType.hasPrefix("image/") {
            return data
        }
        
        struct APIResponse: Decodable {
            var imageUrl: String?
            var imageBase64: String?
        }
        let decoded = try JSONDecoder().decode(APIResponse.self, from: data)
        if let imageUrlString = decoded.imageUrl, let imageUrl = URL(string: imageUrlString) {
            let (imageData, _) = try await URLSession.shared.data(from: imageUrl)
            return imageData
        }
        if let base64 = decoded.imageBase64, let imageData = Data(base64Encoded: base64) {
            return imageData
        }
        throw ImageGenerationError.noImageInResponse
    }
}

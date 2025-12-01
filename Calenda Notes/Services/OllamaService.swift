//
//  OllamaService.swift
//  Calenda Notes
//
//  Fetches available models from Ollama server
//

import Foundation
import Combine

struct OllamaModel: Identifiable, Decodable, Hashable {
    var id: String { name }
    let name: String
    let size: Int64?
    let parameterSize: String?
    let family: String?
    
    enum CodingKeys: String, CodingKey {
        case name
        case size
        case details
    }
    
    struct Details: Codable {
        let parameterSize: String?
        let family: String?
        
        enum CodingKeys: String, CodingKey {
            case parameterSize = "parameter_size"
            case family
        }
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        size = try container.decodeIfPresent(Int64.self, forKey: .size)
        
        if let details = try container.decodeIfPresent(Details.self, forKey: .details) {
            parameterSize = details.parameterSize
            family = details.family
        } else {
            parameterSize = nil
            family = nil
        }
    }
    
    init(name: String, size: Int64? = nil, parameterSize: String? = nil, family: String? = nil) {
        self.name = name
        self.size = size
        self.parameterSize = parameterSize
        self.family = family
    }
    
    /// Human-readable size (e.g., "4.7 GB")
    var formattedSize: String {
        guard let size = size else { return "" }
        let gb = Double(size) / 1_000_000_000
        if gb >= 1 {
            return String(format: "%.1f GB", gb)
        } else {
            let mb = Double(size) / 1_000_000
            return String(format: "%.0f MB", mb)
        }
    }
    
    /// Display name with parameter count
    var displayName: String {
        if let params = parameterSize {
            return "\(name) (\(params))"
        }
        return name
    }
}

struct OllamaModelsResponse: Codable {
    let models: [OllamaModel]
}

@MainActor
final class OllamaService: ObservableObject {
    static let shared = OllamaService()
    
    @Published var availableModels: [OllamaModel] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private init() {}
    
    /// Fetch available models from Ollama server
    func fetchModels() async {
        let settings = AppSettings.shared
        
        // Extract base URL (remove /v1 suffix if present)
        var baseURLString = settings.serverURL
        if baseURLString.hasSuffix("/v1") {
            baseURLString = String(baseURLString.dropLast(3))
        }
        if baseURLString.hasSuffix("/v1/") {
            baseURLString = String(baseURLString.dropLast(4))
        }
        
        guard let url = URL(string: baseURLString)?.appendingPathComponent("api/tags") else {
            errorMessage = "Invalid server URL"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            var request = URLRequest(url: url)
            request.timeoutInterval = 10
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
                let status = (response as? HTTPURLResponse)?.statusCode ?? -1
                errorMessage = "Server returned error \(status)"
                isLoading = false
                return
            }
            
            let decoded = try JSONDecoder().decode(OllamaModelsResponse.self, from: data)
            
            // Sort models: smaller first (good for tool calling)
            availableModels = decoded.models.sorted { model1, model2 in
                // Prioritize models with known sizes
                guard let size1 = model1.size else { return false }
                guard let size2 = model2.size else { return true }
                return size1 < size2
            }
            
            print("✅ Fetched \(availableModels.count) models from Ollama")
            
        } catch {
            errorMessage = "Failed to fetch models: \(error.localizedDescription)"
            print("❌ Error fetching models: \(error)")
        }
        
        isLoading = false
    }
    
    /// Recommended fast models that support tool calling
    var recommendedModels: [OllamaModel] {
        let recommendedNames = ["qwen2.5:1.5b", "qwen2.5:3b", "qwen3:0.6b", "gemma3:1b", "llama3.2:1b", "llama3.2:3b"]
        return availableModels.filter { model in
            recommendedNames.contains { model.name.lowercased().contains($0.lowercased()) }
        }
    }
}


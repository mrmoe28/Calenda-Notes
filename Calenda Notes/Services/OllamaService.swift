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

struct OllamaModelsResponse: Decodable {
    let models: [OllamaModel]
}

@MainActor
final class OllamaService: ObservableObject {
    static let shared = OllamaService()
    
    @Published var availableModels: [OllamaModel] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var isConnected = false
    
    private let maxRetries = 3
    
    // Stable session for Ollama API
    private static let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        config.timeoutIntervalForResource = 60
        config.waitsForConnectivity = true
        return URLSession(configuration: config)
    }()
    
    private init() {}
    
    /// Fetch available models from Ollama server with retry
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
            isConnected = false
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        // Retry logic
        for attempt in 0..<maxRetries {
            do {
                var request = URLRequest(url: url)
                request.timeoutInterval = 15
                
                let (data, response) = try await Self.session.data(for: request)
                
                guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
                    let status = (response as? HTTPURLResponse)?.statusCode ?? -1
                    errorMessage = "Server error \(status)"
                    isConnected = false
                    isLoading = false
                    return
                }
                
                let decoded = try JSONDecoder().decode(OllamaModelsResponse.self, from: data)
                
                // Sort models: smaller first (good for tool calling)
                availableModels = decoded.models.sorted { model1, model2 in
                    guard let size1 = model1.size else { return false }
                    guard let size2 = model2.size else { return true }
                    return size1 < size2
                }
                
                isConnected = true
                errorMessage = nil
                print("✅ Fetched \(availableModels.count) models from Ollama")
                isLoading = false
                return
                
            } catch {
                let friendlyError = friendlyErrorMessage(for: error)
                
                if attempt < maxRetries - 1 {
                    print("⚠️ Retry \(attempt + 1)/\(maxRetries): \(friendlyError)")
                    try? await Task.sleep(nanoseconds: UInt64(pow(2.0, Double(attempt)) * 1_000_000_000))
                } else {
                    errorMessage = friendlyError
                    isConnected = false
                    print("❌ Failed to fetch models after \(maxRetries) attempts: \(error)")
                }
            }
        }
        
        isLoading = false
    }
    
    /// Quick connection check
    func checkConnection() async -> Bool {
        let settings = AppSettings.shared
        var baseURLString = settings.serverURL
        if baseURLString.hasSuffix("/v1") {
            baseURLString = String(baseURLString.dropLast(3))
        }
        
        guard let url = URL(string: baseURLString)?.appendingPathComponent("api/tags") else {
            isConnected = false
            return false
        }
        
        do {
            var request = URLRequest(url: url)
            request.timeoutInterval = 5
            
            let (_, response) = try await Self.session.data(for: request)
            
            if let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode {
                isConnected = true
                return true
            }
        } catch {
            // Silent fail for health check
        }
        
        isConnected = false
        return false
    }
    
    private func friendlyErrorMessage(for error: Error) -> String {
        if let urlError = error as? URLError {
            switch urlError.code {
            case .timedOut:
                return "Connection timed out - is Ollama running?"
            case .cannotConnectToHost:
                return "Can't connect - check IP address"
            case .notConnectedToInternet:
                return "No internet connection"
            case .networkConnectionLost:
                return "Connection lost - retrying..."
            case .cannotFindHost:
                return "Server not found"
            default:
                return "Network error"
            }
        }
        return "Connection failed"
    }
    
    /// Recommended fast models that support tool calling
    var recommendedModels: [OllamaModel] {
        let recommendedNames = ["qwen2.5:1.5b", "qwen2.5:3b", "qwen3:0.6b", "gemma3:1b", "llama3.2:1b", "llama3.2:3b"]
        return availableModels.filter { model in
            recommendedNames.contains { model.name.lowercased().contains($0.lowercased()) }
        }
    }
}


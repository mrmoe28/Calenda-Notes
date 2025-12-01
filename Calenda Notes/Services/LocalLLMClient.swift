//
//  LocalLLMClient.swift
//  Calenda Notes
//

import Foundation

struct LLMChatRequest: Encodable {
    let model: String
    let messages: [LLMMessage]
    let stream: Bool
    let temperature: Double?
    let max_tokens: Int?
}

// Standard text-only message
struct LLMMessage: Encodable {
    let role: String
    let content: LLMMessageContent
    
    init(role: String, content: String) {
        self.role = role
        self.content = .text(content)
    }
    
    init(role: String, textAndImage: (text: String, imageBase64: String)) {
        self.role = role
        self.content = .multimodal([
            .init(type: "text", text: textAndImage.text, imageUrl: nil),
            .init(type: "image_url", text: nil, imageUrl: .init(url: "data:image/jpeg;base64,\(textAndImage.imageBase64)"))
        ])
    }
}

// Support both text and multimodal content
enum LLMMessageContent: Encodable {
    case text(String)
    case multimodal([LLMContentPart])
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .text(let string):
            try container.encode(string)
        case .multimodal(let parts):
            try container.encode(parts)
        }
    }
}

struct LLMContentPart: Encodable {
    let type: String
    let text: String?
    let imageUrl: ImageURL?
    
    enum CodingKeys: String, CodingKey {
        case type
        case text
        case imageUrl = "image_url"
    }
    
    struct ImageURL: Encodable {
        let url: String
    }
}

// OpenAI-compatible response format (non-streaming)
struct LLMChatResponse: Decodable {
    struct Choice: Decodable {
        struct Message: Decodable {
            let role: String
            let content: String
        }
        let message: Message
    }
    let choices: [Choice]
}

// Streaming response format (SSE chunks)
struct LLMStreamChunk: Decodable {
    struct Choice: Decodable {
        struct Delta: Decodable {
            let content: String?
            let role: String?
        }
        let delta: Delta
        let finish_reason: String?
    }
    let choices: [Choice]
}

protocol LLMClient {
    func sendMessage(history: [ChatMessage], userInput: String, imageData: Data?) async throws -> String
    func streamMessage(history: [ChatMessage], userInput: String, imageData: Data?, onChunk: @escaping (String) -> Void) async throws -> String
}

extension LLMClient {
    // Convenience methods without image (backward compatible)
    func sendMessage(history: [ChatMessage], userInput: String) async throws -> String {
        try await sendMessage(history: history, userInput: userInput, imageData: nil)
    }
    
    func streamMessage(history: [ChatMessage], userInput: String, onChunk: @escaping (String) -> Void) async throws -> String {
        try await streamMessage(history: history, userInput: userInput, imageData: nil, onChunk: onChunk)
    }
}

final class LocalLLMClient: LLMClient {
    private let baseURL: URL
    private let endpointPath: String
    
    // Retry configuration
    private let maxRetries = 3
    private let baseRetryDelay: TimeInterval = 1.0
    
    init(baseURL: URL, endpointPath: String, urlSession: URLSession = .shared) {
        self.baseURL = baseURL
        self.endpointPath = endpointPath
    }
    
    // MARK: - Build Request
    
    private func buildRequest(history: [ChatMessage], userInput: String, imageData: Data?, stream: Bool) async throws -> URLRequest {
        var url = baseURL.appendingPathComponent(endpointPath)
        
        // Fix double slashes in URL path
        if let urlString = url.absoluteString.removingPercentEncoding {
            let cleaned = urlString.replacingOccurrences(of: "//v1", with: "/v1")
            if let cleanedURL = URL(string: cleaned) {
                url = cleanedURL
            }
        }
        
        // Map our ChatMessage history → generic role/content messages
        var allMessages: [LLMMessage] = []
        
        for (index, message) in history.enumerated() {
            if index == 0 && !message.isUser {
                // First assistant message is system prompt
                allMessages.append(LLMMessage(role: "system", content: message.text))
            } else if let msgImageData = message.imageData {
                // Message with image
                let base64 = msgImageData.base64EncodedString()
                allMessages.append(LLMMessage(
                    role: message.isUser ? "user" : "assistant",
                    textAndImage: (text: message.text, imageBase64: base64)
                ))
            } else {
                allMessages.append(LLMMessage(
                    role: message.isUser ? "user" : "assistant",
                    content: message.text
                ))
            }
        }
        
        // Add current user input (with optional image)
        if let imageData = imageData {
            let base64 = imageData.base64EncodedString()
            allMessages.append(LLMMessage(
                role: "user",
                textAndImage: (text: userInput, imageBase64: base64)
            ))
        } else {
            allMessages.append(LLMMessage(role: "user", content: userInput))
        }
        
        // Get settings (single MainActor call for speed)
        let (temperature, maxTokens, modelName) = await MainActor.run {
            let s = AppSettings.shared
            return (s.temperature, s.maxTokens, s.modelName)
        }
        
        let requestBody = LLMChatRequest(
            model: modelName,
            messages: allMessages,
            stream: stream,
            temperature: temperature,
            max_tokens: maxTokens
        )
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("keep-alive", forHTTPHeaderField: "Connection")  // Reuse connection
        request.httpBody = try JSONEncoder().encode(requestBody)
        request.timeoutInterval = 120  // Generous timeout for slow models
        request.cachePolicy = .reloadIgnoringLocalCacheData
        
        return request
    }
    
    // Shared session with stable connection configuration
    private static let stableSession: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30  // Wait for request to complete
        config.timeoutIntervalForResource = 180  // Total time for resource (3 mins for slow models)
        config.httpMaximumConnectionsPerHost = 4  // Allow more parallel connections
        config.waitsForConnectivity = true  // Wait for network instead of failing immediately
        config.allowsCellularAccess = true
        config.allowsExpensiveNetworkAccess = true
        config.allowsConstrainedNetworkAccess = true
        // Keep connections alive longer
        config.httpShouldSetCookies = false
        config.httpShouldUsePipelining = true
        return URLSession(configuration: config)
    }()
    
    // MARK: - Retry Helper
    
    private func withRetry<T>(
        operation: @escaping () async throws -> T,
        retryCount: Int = 0
    ) async throws -> T {
        do {
            return try await operation()
        } catch {
            // Check if we should retry
            let isRetryable = isRetryableError(error)
            
            if isRetryable && retryCount < maxRetries {
                let delay = baseRetryDelay * pow(2.0, Double(retryCount))
                print("⚠️ Retry \(retryCount + 1)/\(maxRetries) after \(delay)s: \(error.localizedDescription)")
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                return try await withRetry(operation: operation, retryCount: retryCount + 1)
            }
            
            throw error
        }
    }
    
    private func isRetryableError(_ error: Error) -> Bool {
        if let urlError = error as? URLError {
            switch urlError.code {
            case .timedOut, .networkConnectionLost, .notConnectedToInternet,
                 .cannotConnectToHost, .cannotFindHost, .dnsLookupFailed:
                return true
            default:
                return false
            }
        }
        
        if let nsError = error as NSError? {
            // Retry on connection errors
            if nsError.domain == NSURLErrorDomain {
                return true
            }
        }
        
        return false
    }
    
    private func friendlyErrorMessage(for error: Error) -> String {
        if let urlError = error as? URLError {
            switch urlError.code {
            case .timedOut:
                return "Connection timed out. Is Ollama running?"
            case .cannotConnectToHost:
                return "Can't reach server. Check the IP address."
            case .notConnectedToInternet:
                return "No internet connection."
            case .networkConnectionLost:
                return "Lost connection. Retrying..."
            case .cannotFindHost:
                return "Server not found. Check your URL."
            default:
                return "Network error: \(urlError.localizedDescription)"
            }
        }
        return error.localizedDescription
    }
    
    // MARK: - Non-Streaming (fallback)
    
    func sendMessage(history: [ChatMessage], userInput: String, imageData: Data?) async throws -> String {
        let request = try await buildRequest(history: history, userInput: userInput, imageData: imageData, stream: false)
        
        return try await withRetry {
            print("🔗 Sending non-streaming request")
            
            let (data, response) = try await Self.stableSession.data(for: request)
            
            guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
                let status = (response as? HTTPURLResponse)?.statusCode ?? -1
                let raw = String(data: data, encoding: .utf8) ?? "<no body>"
                throw NSError(domain: "LocalLLMClient", code: status, 
                             userInfo: [NSLocalizedDescriptionKey: "Server error \(status): \(raw.prefix(200))"])
            }
            
            let decoded = try JSONDecoder().decode(LLMChatResponse.self, from: data)
            guard let first = decoded.choices.first else {
                throw NSError(domain: "LocalLLMClient", code: -2, 
                             userInfo: [NSLocalizedDescriptionKey: "No choices in response"])
            }
            
            return first.message.content
        }
    }
    
    // MARK: - Streaming
    
    func streamMessage(history: [ChatMessage], userInput: String, imageData: Data?, onChunk: @escaping (String) -> Void) async throws -> String {
        let request = try await buildRequest(history: history, userInput: userInput, imageData: imageData, stream: true)
        
        // Streaming with retry on connection failure
        return try await withRetry {
            print("🔗 Sending streaming request")
            
            let (bytes, response) = try await Self.stableSession.bytes(for: request)
            
            guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
                let status = (response as? HTTPURLResponse)?.statusCode ?? -1
                throw NSError(domain: "LocalLLMClient", code: status,
                             userInfo: [NSLocalizedDescriptionKey: "Server error \(status)"])
            }
            
            var fullResponse = ""
            
            // Process SSE stream
            for try await line in bytes.lines {
                // SSE format: "data: {...}"
                guard line.hasPrefix("data: ") else { continue }
                
                let jsonString = String(line.dropFirst(6)) // Remove "data: " prefix
                
                // Check for stream end
                if jsonString == "[DONE]" {
                    print("✅ Stream complete")
                    break
                }
                
                // Parse chunk
                guard let jsonData = jsonString.data(using: .utf8) else { continue }
                
                do {
                    let chunk = try JSONDecoder().decode(LLMStreamChunk.self, from: jsonData)
                    
                    if let content = chunk.choices.first?.delta.content {
                        fullResponse += content
                        
                        // Call the chunk handler on main thread
                        await MainActor.run {
                            onChunk(content)
                        }
                    }
                    
                    // Check for finish
                    if chunk.choices.first?.finish_reason != nil {
                        break
                    }
                } catch {
                    // Some servers send different formats, try to be lenient
                    print("⚠️ Chunk parse error (continuing): \(error.localizedDescription)")
                }
            }
            
            print("✅ Full response: \(fullResponse.prefix(50))...")
            return fullResponse
        }
    }
    
    // MARK: - Connection Health Check
    
    /// Quick check if the server is reachable
    func checkConnection() async -> (isConnected: Bool, error: String?) {
        // Extract base URL for health check
        var baseURLString = baseURL.absoluteString
        if baseURLString.contains("/v1") {
            baseURLString = baseURLString.components(separatedBy: "/v1").first ?? baseURLString
        }
        
        guard let healthURL = URL(string: baseURLString)?.appendingPathComponent("api/tags") else {
            return (false, "Invalid URL")
        }
        
        do {
            var request = URLRequest(url: healthURL)
            request.timeoutInterval = 5  // Quick health check
            
            let (_, response) = try await Self.stableSession.data(for: request)
            
            if let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode {
                return (true, nil)
            } else {
                let status = (response as? HTTPURLResponse)?.statusCode ?? -1
                return (false, "Server returned \(status)")
            }
        } catch {
            return (false, friendlyErrorMessage(for: error))
        }
    }
}

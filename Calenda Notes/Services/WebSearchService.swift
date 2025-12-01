//
//  WebSearchService.swift
//  Calenda Notes
//

import Foundation

struct SearchResult: Identifiable {
    let id = UUID()
    let title: String
    let snippet: String
    let url: String
}

final class WebSearchService {
    
    /// Performs a DuckDuckGo instant answer search
    func search(query: String) async throws -> [SearchResult] {
        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        let urlString = "https://api.duckduckgo.com/?q=\(encodedQuery)&format=json&no_html=1&skip_disambig=1"
        
        guard let url = URL(string: urlString) else {
            throw NSError(domain: "WebSearch", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
        }
        
        let (data, _) = try await URLSession.shared.data(from: url)
        let response = try JSONDecoder().decode(DuckDuckGoResponse.self, from: data)
        
        var results: [SearchResult] = []
        
        // Add abstract if available
        if !response.Abstract.isEmpty {
            results.append(SearchResult(
                title: response.Heading.isEmpty ? "Summary" : response.Heading,
                snippet: response.Abstract,
                url: response.AbstractURL
            ))
        }
        
        // Add related topics
        for topic in response.RelatedTopics.prefix(5) {
            if let text = topic.Text, let firstURL = topic.FirstURL {
                let title = text.components(separatedBy: " - ").first ?? text
                results.append(SearchResult(
                    title: String(title.prefix(100)),
                    snippet: text,
                    url: firstURL
                ))
            }
        }
        
        return results
    }
    
    func formatResultsForLLM(_ results: [SearchResult]) -> String {
        if results.isEmpty {
            return "No search results found."
        }
        
        var formatted = "Here's what I found:\n\n"
        for (index, result) in results.enumerated() {
            // Use markdown link format for clickable URLs
            if !result.url.isEmpty {
                formatted += "\(index + 1). [\(result.title)](\(result.url))\n"
            } else {
                formatted += "\(index + 1). \(result.title)\n"
            }
            formatted += "   \(result.snippet.prefix(200))\n\n"
        }
        return formatted
    }
    
    /// Format results with image URLs if available
    func formatResultsWithImages(_ results: [SearchResult]) -> (text: String, imageURLs: [String]) {
        var formatted = "Here's what I found:\n\n"
        var imageURLs: [String] = []
        
        for (index, result) in results.enumerated() {
            if !result.url.isEmpty {
                formatted += "\(index + 1). [\(result.title)](\(result.url))\n"
            } else {
                formatted += "\(index + 1). \(result.title)\n"
            }
            formatted += "   \(result.snippet.prefix(200))\n\n"
        }
        
        return (formatted, imageURLs)
    }
}

// MARK: - DuckDuckGo API Response

private struct DuckDuckGoResponse: Decodable {
    let Abstract: String
    let AbstractURL: String
    let Heading: String
    let RelatedTopics: [RelatedTopic]
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        Abstract = try container.decodeIfPresent(String.self, forKey: .Abstract) ?? ""
        AbstractURL = try container.decodeIfPresent(String.self, forKey: .AbstractURL) ?? ""
        Heading = try container.decodeIfPresent(String.self, forKey: .Heading) ?? ""
        RelatedTopics = try container.decodeIfPresent([RelatedTopic].self, forKey: .RelatedTopics) ?? []
    }
    
    enum CodingKeys: String, CodingKey {
        case Abstract, AbstractURL, Heading, RelatedTopics
    }
}

private struct RelatedTopic: Decodable {
    let Text: String?
    let FirstURL: String?
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        Text = try container.decodeIfPresent(String.self, forKey: .Text)
        FirstURL = try container.decodeIfPresent(String.self, forKey: .FirstURL)
    }
    
    enum CodingKeys: String, CodingKey {
        case Text, FirstURL
    }
}


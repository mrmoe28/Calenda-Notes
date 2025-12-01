//
//  KnowledgeBaseService.swift
//  Calenda Notes
//
//  Manages uploaded documents for AI context
//

import Foundation
import UniformTypeIdentifiers
import Combine
import CoreGraphics

struct KnowledgeDocument: Codable, Identifiable {
    let id: UUID
    let name: String
    let content: String
    let uploadDate: Date
    let fileType: String
    let wordCount: Int
    var tags: [String]
    var isEnabled: Bool // Whether to include in AI context
    
    init(id: UUID = UUID(), name: String, content: String, fileType: String, tags: [String] = [], isEnabled: Bool = true) {
        self.id = id
        self.name = name
        self.content = content
        self.uploadDate = Date()
        self.fileType = fileType
        self.wordCount = content.split(separator: " ").count
        self.tags = tags
        self.isEnabled = isEnabled
    }
}

@MainActor
final class KnowledgeBaseService: ObservableObject {
    @Published var documents: [KnowledgeDocument] = []
    @Published var isProcessing = false
    @Published var errorMessage: String?
    
    private let fileManager = FileManager.default
    private let maxDocumentSize = 100_000 // Max characters per document
    private let maxTotalDocuments = 20
    
    private var storageURL: URL {
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentsPath.appendingPathComponent("knowledge_base.json")
    }
    
    init() {
        loadDocuments()
    }
    
    // MARK: - Storage
    
    func saveDocuments() {
        do {
            let data = try JSONEncoder().encode(documents)
            try data.write(to: storageURL)
            print("📚 Saved \(documents.count) documents to knowledge base")
        } catch {
            print("❌ Failed to save knowledge base: \(error)")
        }
    }
    
    func loadDocuments() {
        guard fileManager.fileExists(atPath: storageURL.path) else { return }
        
        do {
            let data = try Data(contentsOf: storageURL)
            documents = try JSONDecoder().decode([KnowledgeDocument].self, from: data)
            print("📖 Loaded \(documents.count) documents from knowledge base")
        } catch {
            print("❌ Failed to load knowledge base: \(error)")
        }
    }
    
    // MARK: - Document Management
    
    func addDocument(from url: URL) async throws {
        guard documents.count < maxTotalDocuments else {
            throw KnowledgeBaseError.tooManyDocuments
        }
        
        isProcessing = true
        errorMessage = nil
        
        defer { isProcessing = false }
        
        // Read file content
        let content: String
        let fileType: String
        
        do {
            // Start accessing security-scoped resource
            guard url.startAccessingSecurityScopedResource() else {
                throw KnowledgeBaseError.accessDenied
            }
            defer { url.stopAccessingSecurityScopedResource() }
            
            let typeIdentifier = try url.resourceValues(forKeys: [.typeIdentifierKey]).typeIdentifier ?? ""
            fileType = url.pathExtension.lowercased()
            
            // Handle different file types
            if UTType(typeIdentifier)?.conforms(to: .text) == true || 
               ["txt", "md", "json", "csv", "xml", "html", "swift", "py", "js"].contains(fileType) {
                content = try String(contentsOf: url, encoding: .utf8)
            } else if UTType(typeIdentifier)?.conforms(to: .pdf) == true || fileType == "pdf" {
                content = try extractTextFromPDF(url: url)
            } else {
                // Try reading as text anyway
                content = try String(contentsOf: url, encoding: .utf8)
            }
        } catch let error as KnowledgeBaseError {
            throw error
        } catch {
            throw KnowledgeBaseError.readError(error.localizedDescription)
        }
        
        // Validate content
        guard !content.isEmpty else {
            throw KnowledgeBaseError.emptyDocument
        }
        
        // Truncate if too long
        let truncatedContent: String
        if content.count > maxDocumentSize {
            truncatedContent = String(content.prefix(maxDocumentSize)) + "\n\n[Document truncated - original was \(content.count) characters]"
        } else {
            truncatedContent = content
        }
        
        // Extract tags from content
        let tags = extractTags(from: truncatedContent, fileName: url.lastPathComponent)
        
        let document = KnowledgeDocument(
            name: url.lastPathComponent,
            content: truncatedContent,
            fileType: fileType,
            tags: tags
        )
        
        documents.append(document)
        saveDocuments()
    }
    
    func addTextDocument(name: String, content: String) {
        guard documents.count < maxTotalDocuments else {
            errorMessage = "Maximum number of documents reached"
            return
        }
        
        let truncatedContent = content.count > maxDocumentSize 
            ? String(content.prefix(maxDocumentSize)) 
            : content
        
        let tags = extractTags(from: truncatedContent, fileName: name)
        
        let document = KnowledgeDocument(
            name: name,
            content: truncatedContent,
            fileType: "txt",
            tags: tags
        )
        
        documents.append(document)
        saveDocuments()
    }
    
    func removeDocument(_ document: KnowledgeDocument) {
        documents.removeAll { $0.id == document.id }
        saveDocuments()
    }
    
    func toggleDocument(_ document: KnowledgeDocument) {
        if let index = documents.firstIndex(where: { $0.id == document.id }) {
            documents[index].isEnabled.toggle()
            saveDocuments()
        }
    }
    
    func clearAll() {
        documents.removeAll()
        saveDocuments()
    }
    
    // MARK: - Context Generation
    
    /// Get relevant knowledge context for a query
    func getRelevantContext(for query: String, maxCharacters: Int = 4000) -> String {
        let enabledDocs = documents.filter { $0.isEnabled }
        guard !enabledDocs.isEmpty else { return "" }
        
        let queryWords = Set(query.lowercased().split(separator: " ").map(String.init))
        
        // Score each document by relevance
        var scoredDocs: [(doc: KnowledgeDocument, score: Double)] = []
        
        for doc in enabledDocs {
            let tagWords = Set(doc.tags.map { $0.lowercased() })
            let titleWords = Set(doc.name.lowercased().split(separator: " ").map(String.init))
            
            // Calculate relevance score
            let tagOverlap = Double(queryWords.intersection(tagWords).count)
            let titleOverlap = Double(queryWords.intersection(titleWords).count)
            let contentMatch = queryWords.reduce(0.0) { total, word in
                total + (doc.content.lowercased().contains(word) ? 1.0 : 0.0)
            }
            
            let score = tagOverlap * 3 + titleOverlap * 2 + contentMatch
            if score > 0 {
                scoredDocs.append((doc, score))
            }
        }
        
        // Sort by score
        scoredDocs.sort { $0.score > $1.score }
        
        // Build context string within character limit
        var context = "## Relevant Knowledge Base Documents:\n\n"
        var totalChars = context.count
        
        for (doc, _) in scoredDocs {
            let docSection = "### \(doc.name)\n\(doc.content)\n\n"
            
            if totalChars + docSection.count > maxCharacters {
                // Add truncated version if there's room
                let remainingChars = maxCharacters - totalChars - 100
                if remainingChars > 500 {
                    context += "### \(doc.name)\n\(String(doc.content.prefix(remainingChars)))...\n\n"
                }
                break
            }
            
            context += docSection
            totalChars += docSection.count
        }
        
        return context
    }
    
    /// Get summary of all documents for system prompt
    func getKnowledgeSummary() -> String {
        let enabledDocs = documents.filter { $0.isEnabled }
        guard !enabledDocs.isEmpty else { return "" }
        
        var summary = "You have access to the following knowledge base documents:\n"
        for doc in enabledDocs {
            summary += "- \(doc.name) (\(doc.wordCount) words, tags: \(doc.tags.joined(separator: ", ")))\n"
        }
        summary += "\nRefer to these documents when answering questions about their topics."
        
        return summary
    }
    
    // MARK: - Helpers
    
    private func extractTags(from content: String, fileName: String) -> [String] {
        var tags: [String] = []
        let lowercased = content.lowercased()
        
        // Common document topics
        let topicKeywords = [
            "api", "documentation", "guide", "tutorial", "reference",
            "meeting", "notes", "minutes", "agenda",
            "report", "analysis", "summary", "overview",
            "policy", "procedure", "process", "workflow",
            "recipe", "instructions", "how-to", "manual",
            "contract", "agreement", "terms", "legal",
            "budget", "finance", "invoice", "expense",
            "research", "study", "paper", "article",
            "code", "programming", "development", "software"
        ]
        
        for keyword in topicKeywords {
            if lowercased.contains(keyword) || fileName.lowercased().contains(keyword) {
                tags.append(keyword)
            }
        }
        
        // Add file type as tag
        let fileType = (fileName as NSString).pathExtension.lowercased()
        if !fileType.isEmpty {
            tags.append(fileType)
        }
        
        return Array(Set(tags)).prefix(10).map { $0 }
    }
    
    private func extractTextFromPDF(url: URL) throws -> String {
        // Use CGPDFDocument to extract text
        guard let pdfDocument = CGPDFDocument(url as CFURL) else {
            throw KnowledgeBaseError.pdfError
        }
        
        var fullText = ""
        let pageCount = pdfDocument.numberOfPages
        
        for pageNum in 1...min(pageCount, 50) { // Limit to first 50 pages
            guard let page = pdfDocument.page(at: pageNum) else { continue }
            
            // Note: Full PDF text extraction requires more complex implementation
            // For now, we'll indicate this limitation
            fullText += "[Page \(pageNum) of PDF]\n"
        }
        
        if fullText.isEmpty {
            fullText = "[PDF document - \(pageCount) pages. For best results, convert to text format.]"
        }
        
        return fullText
    }
}

// MARK: - Errors

enum KnowledgeBaseError: Error, LocalizedError {
    case tooManyDocuments
    case accessDenied
    case readError(String)
    case emptyDocument
    case pdfError
    
    var errorDescription: String? {
        switch self {
        case .tooManyDocuments:
            return "Maximum number of documents (20) reached. Remove some documents first."
        case .accessDenied:
            return "Unable to access the file. Please try again."
        case .readError(let message):
            return "Error reading file: \(message)"
        case .emptyDocument:
            return "The document appears to be empty."
        case .pdfError:
            return "Unable to read PDF. Try converting to text format."
        }
    }
}


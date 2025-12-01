//
//  KnowledgeBaseView.swift
//  Calenda Notes
//

import SwiftUI
import UniformTypeIdentifiers

struct KnowledgeBaseView: View {
    @StateObject private var knowledgeService = KnowledgeBaseService()
    @Environment(\.dismiss) private var dismiss
    
    @State private var showDocumentPicker = false
    @State private var showAddTextSheet = false
    @State private var showClearAlert = false
    @State private var newDocumentName = ""
    @State private var newDocumentContent = ""
    
    var body: some View {
        NavigationView {
            List {
                // Stats Section
                Section {
                    HStack {
                        Label("\(knowledgeService.documents.count)", systemImage: "doc.fill")
                        Text("documents")
                            .foregroundColor(.secondary)
                        Spacer()
                        let totalWords = knowledgeService.documents.reduce(0) { $0 + $1.wordCount }
                        Text("\(totalWords) words")
                            .foregroundColor(.secondary)
                    }
                    
                    let enabledCount = knowledgeService.documents.filter { $0.isEnabled }.count
                    HStack {
                        Label("\(enabledCount)", systemImage: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("enabled for AI context")
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Label("Overview", systemImage: "chart.bar.fill")
                }
                
                // Add Documents Section
                Section {
                    Button(action: { showDocumentPicker = true }) {
                        Label("Upload Document", systemImage: "doc.badge.plus")
                    }
                    
                    Button(action: { showAddTextSheet = true }) {
                        Label("Add Text Note", systemImage: "note.text.badge.plus")
                    }
                } header: {
                    Label("Add Knowledge", systemImage: "plus.circle")
                } footer: {
                    Text("Supported: .txt, .md, .json, .csv, .pdf (text extraction limited)")
                }
                
                // Documents List
                if !knowledgeService.documents.isEmpty {
                    Section {
                        ForEach(knowledgeService.documents) { doc in
                            DocumentRow(document: doc) {
                                knowledgeService.toggleDocument(doc)
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    knowledgeService.removeDocument(doc)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    } header: {
                        Label("Documents", systemImage: "folder.fill")
                    }
                    
                    // Clear All
                    Section {
                        Button(role: .destructive, action: { showClearAlert = true }) {
                            Label("Clear All Documents", systemImage: "trash")
                        }
                    }
                }
                
                // Help Section
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("How it works")
                            .font(.headline)
                        
                        Text("Documents you add here become part of Nova's knowledge. When you ask questions, Nova will search these documents for relevant information.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Text("Tips:")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("• Use clear, descriptive file names")
                            Text("• Keep documents focused on specific topics")
                            Text("• Disable documents you don't need right now")
                            Text("• Plain text works best for accurate retrieval")
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 8)
                } header: {
                    Label("Help", systemImage: "questionmark.circle")
                }
            }
            .navigationTitle("Knowledge Base")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .fileImporter(
                isPresented: $showDocumentPicker,
                allowedContentTypes: [.text, .plainText, .pdf, .json, .commaSeparatedText, .xml],
                allowsMultipleSelection: false
            ) { result in
                handleFileImport(result)
            }
            .sheet(isPresented: $showAddTextSheet) {
                AddTextDocumentSheet(
                    name: $newDocumentName,
                    content: $newDocumentContent,
                    onSave: {
                        knowledgeService.addTextDocument(name: newDocumentName, content: newDocumentContent)
                        newDocumentName = ""
                        newDocumentContent = ""
                    }
                )
            }
            .alert("Clear All Documents?", isPresented: $showClearAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Clear All", role: .destructive) {
                    knowledgeService.clearAll()
                }
            } message: {
                Text("This will remove all documents from the knowledge base. This cannot be undone.")
            }
            .overlay {
                if knowledgeService.isProcessing {
                    ProgressView("Processing...")
                        .padding()
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
    }
    
    private func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            Task {
                do {
                    try await knowledgeService.addDocument(from: url)
                } catch {
                    knowledgeService.errorMessage = error.localizedDescription
                }
            }
        case .failure(let error):
            knowledgeService.errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Document Row

struct DocumentRow: View {
    let document: KnowledgeDocument
    let onToggle: () -> Void
    
    @State private var showDetail = false
    
    var body: some View {
        Button(action: { showDetail = true }) {
            HStack(spacing: 12) {
                // File type icon
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(iconColor.opacity(0.15))
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: iconName)
                        .font(.title3)
                        .foregroundColor(iconColor)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(document.name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    HStack(spacing: 8) {
                        Text("\(document.wordCount) words")
                        Text("•")
                        Text(document.uploadDate, style: .date)
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                    
                    if !document.tags.isEmpty {
                        Text(document.tags.prefix(3).joined(separator: ", "))
                            .font(.caption2)
                            .foregroundColor(.blue)
                    }
                }
                
                Spacer()
                
                // Enable/disable toggle
                Button(action: onToggle) {
                    Image(systemName: document.isEnabled ? "checkmark.circle.fill" : "circle")
                        .font(.title2)
                        .foregroundColor(document.isEnabled ? .green : .gray)
                }
                .buttonStyle(.plain)
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showDetail) {
            DocumentDetailView(document: document)
        }
    }
    
    private var iconName: String {
        switch document.fileType {
        case "pdf": return "doc.richtext"
        case "json": return "curlybraces"
        case "csv": return "tablecells"
        case "md": return "text.badge.checkmark"
        default: return "doc.text"
        }
    }
    
    private var iconColor: Color {
        switch document.fileType {
        case "pdf": return .red
        case "json": return .orange
        case "csv": return .green
        case "md": return .purple
        default: return .blue
        }
    }
}

// MARK: - Document Detail View

struct DocumentDetailView: View {
    let document: KnowledgeDocument
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Metadata
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Type:")
                                .foregroundColor(.secondary)
                            Text(document.fileType.uppercased())
                                .fontWeight(.medium)
                        }
                        
                        HStack {
                            Text("Words:")
                                .foregroundColor(.secondary)
                            Text("\(document.wordCount)")
                        }
                        
                        HStack {
                            Text("Added:")
                                .foregroundColor(.secondary)
                            Text(document.uploadDate, style: .date)
                        }
                        
                        if !document.tags.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Tags:")
                                    .foregroundColor(.secondary)
                                FlowLayout(spacing: 4) {
                                    ForEach(document.tags, id: \.self) { tag in
                                        Text(tag)
                                            .font(.caption)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(Color.blue.opacity(0.1))
                                            .foregroundColor(.blue)
                                            .clipShape(Capsule())
                                    }
                                }
                            }
                        }
                    }
                    .font(.subheadline)
                    .padding()
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    
                    // Content preview
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Content Preview")
                            .font(.headline)
                        
                        Text(document.content)
                            .font(.system(.body, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding()
            }
            .navigationTitle(document.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Add Text Document Sheet

struct AddTextDocumentSheet: View {
    @Binding var name: String
    @Binding var content: String
    let onSave: () -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                Section("Document Name") {
                    TextField("e.g., Meeting Notes", text: $name)
                }
                
                Section("Content") {
                    TextEditor(text: $content)
                        .frame(minHeight: 200)
                }
            }
            .navigationTitle("Add Text Note")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        onSave()
                        dismiss()
                    }
                    .disabled(name.isEmpty || content.isEmpty)
                }
            }
        }
    }
}

// MARK: - Flow Layout for Tags

struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(in: proposal.width ?? 0, subviews: subviews, spacing: spacing)
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(in: bounds.width, subviews: subviews, spacing: spacing)
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.positions[index].x,
                                     y: bounds.minY + result.positions[index].y),
                         proposal: .unspecified)
        }
    }
    
    struct FlowResult {
        var size: CGSize = .zero
        var positions: [CGPoint] = []
        
        init(in width: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var x: CGFloat = 0
            var y: CGFloat = 0
            var maxHeight: CGFloat = 0
            
            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)
                
                if x + size.width > width && x > 0 {
                    x = 0
                    y += maxHeight + spacing
                    maxHeight = 0
                }
                
                positions.append(CGPoint(x: x, y: y))
                maxHeight = max(maxHeight, size.height)
                x += size.width + spacing
            }
            
            self.size = CGSize(width: width, height: y + maxHeight)
        }
    }
}

#Preview {
    KnowledgeBaseView()
}


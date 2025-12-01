//
//  ChatView.swift
//  Calenda Notes
//

import SwiftUI
import PhotosUI
import UniformTypeIdentifiers
import AVFoundation

struct ChatView: View {
    @ObservedObject var viewModel: ChatViewModel
    @ObservedObject var settings = AppSettings.shared
    @State private var showVoiceMode = false
    @State private var showSettings = false
    @State private var showAttachmentMenu = false
    @State private var showImagePicker = false
    @State private var showDocumentPicker = false
    @State private var showCamera = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var lastSpokenMessageId: UUID?
    
    // Speech synthesizer for reading responses aloud
    private let synthesizer = AVSpeechSynthesizer()
    
    var body: some View {
        VStack(spacing: 0) {
            // Compact Header
            HStack(spacing: 12) {
                // Settings button
                Button(action: { showSettings = true }) {
                    Image(systemName: "gearshape.fill")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
                
                Text("Nova")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                if viewModel.isSending && !viewModel.isStreaming {
                    ProgressView()
                        .scaleEffect(0.7)
                }
                
                Spacer()
                
                // Voice mode button
                Button(action: { showVoiceMode = true }) {
                    Image(systemName: "waveform.circle.fill")
                        .font(.title3)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.blue, .purple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color(.systemBackground))
            
            Divider()
            
            // Messages - Full Screen
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(viewModel.messages) { message in
                            MessageBubble(
                                message: message,
                                isStreaming: viewModel.streamingMessageId == message.id
                            )
                            .id(message.id)
                            .padding(.horizontal, 12)
                        }
                        
                        // Only show typing indicator when waiting for first response (not streaming)
                        if viewModel.isSending && !viewModel.isStreaming {
                            HStack {
                                TypingIndicator()
                                Spacer()
                            }
                            .padding(.horizontal, 12)
                            .id("typing")
                        }
                        
                        // Bottom spacer for better scrolling
                        Color.clear.frame(height: 1).id("bottom")
                    }
                    .padding(.vertical, 8)
                }
                .scrollDismissesKeyboard(.interactively)
                .onAppear {
                    scrollToBottom(proxy: proxy)
                }
                .onChange(of: viewModel.messages.count) { _, _ in
                    scrollToBottom(proxy: proxy)
                }
                .onChange(of: viewModel.isSending) { _, _ in
                    scrollToBottom(proxy: proxy)
                }
                .onChange(of: viewModel.messages.last?.text) { _, _ in
                    // Scroll as streaming content grows - more responsive
                    if viewModel.isStreaming {
                        withAnimation(.linear(duration: 0.1)) {
                            proxy.scrollTo("bottom", anchor: .bottom)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            // Error banner
            if let error = viewModel.errorMessage {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text(error)
                        .font(.caption)
                }
                .foregroundStyle(.red)
                .padding(.horizontal)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.red.opacity(0.1))
            }
            
            Divider()
            
            // Compact Input bar
            HStack(spacing: 8) {
                // Plus button for attachments
                Button(action: { showAttachmentMenu = true }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.blue, .purple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                
                // Text field
                HStack(spacing: 8) {
                    // Show image preview if pending
                    if let imageData = viewModel.pendingImageData,
                       let uiImage = UIImage(data: imageData) {
                        HStack(spacing: 4) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 32, height: 32)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                            Button(action: { 
                                viewModel.pendingImageData = nil 
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(4)
                        .background(Color.blue.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    
                    TextField("Message", text: $viewModel.inputText, axis: .vertical)
                        .lineLimit(1...4)
                        .onSubmit {
                            sendWithAttachment()
                        }
                    
                    if !viewModel.inputText.isEmpty {
                        Button(action: { viewModel.inputText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.body)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 20))
                
                // Send / Voice button
                if viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && viewModel.pendingImageData == nil {
                    Button(action: { showVoiceMode = true }) {
                        Image(systemName: "mic.fill")
                            .font(.system(size: 18))
                            .foregroundColor(.white)
                            .frame(width: 38, height: 38)
                            .background(
                                LinearGradient(
                                    colors: [.blue, .purple],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .clipShape(Circle())
                    }
                } else {
                    Button(action: { sendWithAttachment() }) {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 38, height: 38)
                            .background(Color.blue)
                            .clipShape(Circle())
                    }
                    .disabled(viewModel.isSending)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(.systemBackground))
        }
        // Attachment menu
        .confirmationDialog("Add Attachment", isPresented: $showAttachmentMenu) {
            Button("Photo Library") { showImagePicker = true }
            Button("Take Photo") { showCamera = true }
            Button("Document") { showDocumentPicker = true }
            Button("Cancel", role: .cancel) { }
        }
        // Photo picker
        .photosPicker(isPresented: $showImagePicker, selection: $selectedPhotoItem, matching: .images)
        .onChange(of: selectedPhotoItem) { _, newItem in
            Task {
                if let data = try? await newItem?.loadTransferable(type: Data.self) {
                    // Compress image if too large (max 4MB for most vision APIs)
                    if let compressed = compressImageData(data, maxSizeKB: 1024) {
                        viewModel.pendingImageData = compressed
                    } else {
                        viewModel.pendingImageData = data
                    }
                }
            }
        }
        // Document picker
        .sheet(isPresented: $showDocumentPicker) {
            DocumentPickerView { url in
                loadDocument(from: url)
            }
        }
        // Camera
        .sheet(isPresented: $showCamera) {
            CameraView { imageData in
                // Compress camera image
                if let compressed = compressImageData(imageData, maxSizeKB: 1024) {
                    viewModel.pendingImageData = compressed
                } else {
                    viewModel.pendingImageData = imageData
                }
            }
        }
        .fullScreenCover(isPresented: $showVoiceMode) {
            VoiceConversationView(viewModel: viewModel)
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(viewModel: viewModel)
        }
        // Speak Nova's responses when streaming finishes
        .onChange(of: viewModel.isStreaming) { wasStreaming, isStreaming in
            // When streaming ends (was true, now false), speak the response
            if wasStreaming && !isStreaming && settings.speakResponsesInChat {
                // Find the last assistant message
                if let lastMessage = viewModel.messages.last, 
                   !lastMessage.isUser,
                   lastMessage.id != lastSpokenMessageId {
                    speakText(lastMessage.text)
                    lastSpokenMessageId = lastMessage.id
                }
            }
        }
    }
    
    // MARK: - Text to Speech
    
    private func speakText(_ text: String) {
        // Stop any ongoing speech
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        
        // Clean text for speech (remove markdown, emojis, etc.)
        let cleanedText = cleanTextForSpeech(text)
        guard !cleanedText.isEmpty else { return }
        
        // Configure audio session
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playback, mode: .default, options: [.duckOthers])
            try audioSession.setActive(true)
        } catch {
            print("❌ Audio session error: \(error)")
        }
        
        let utterance = AVSpeechUtterance(string: cleanedText)
        utterance.rate = settings.voiceSpeed > 0 ? Float(settings.voiceSpeed) : 0.5
        utterance.pitchMultiplier = settings.voicePitch > 0 ? Float(settings.voicePitch) : 1.0
        utterance.volume = 1.0
        
        // Use saved voice
        if !settings.voiceIdentifier.isEmpty,
           let voice = AVSpeechSynthesisVoice(identifier: settings.voiceIdentifier) {
            utterance.voice = voice
        } else {
            // Default to a good English voice
            let voices = AVSpeechSynthesisVoice.speechVoices()
            let englishVoices = voices.filter { $0.language.starts(with: "en") }
            let premiumVoice = englishVoices.first { $0.quality == .enhanced }
            utterance.voice = premiumVoice ?? AVSpeechSynthesisVoice(language: "en-US")
        }
        
        synthesizer.speak(utterance)
    }
    
    private func cleanTextForSpeech(_ text: String) -> String {
        var cleaned = text
        // Remove markdown
        cleaned = cleaned.replacingOccurrences(of: "**", with: "")
        cleaned = cleaned.replacingOccurrences(of: "*", with: "")
        cleaned = cleaned.replacingOccurrences(of: "#", with: "")
        cleaned = cleaned.replacingOccurrences(of: "`", with: "")
        cleaned = cleaned.replacingOccurrences(of: "[", with: "")
        cleaned = cleaned.replacingOccurrences(of: "]", with: "")
        // Remove URLs
        cleaned = cleaned.replacingOccurrences(of: #"https?://\S+"#, with: "", options: .regularExpression)
        // Remove emojis for cleaner speech (keep some basic ones)
        cleaned = cleaned.replacingOccurrences(of: #"[\u{1F600}-\u{1F64F}]"#, with: "", options: .regularExpression)
        cleaned = cleaned.replacingOccurrences(of: #"[\u{1F300}-\u{1F5FF}]"#, with: "", options: .regularExpression)
        cleaned = cleaned.replacingOccurrences(of: #"[\u{1F680}-\u{1F6FF}]"#, with: "", options: .regularExpression)
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private func scrollToBottom(proxy: ScrollViewProxy) {
        withAnimation(.easeOut(duration: 0.15)) {
            proxy.scrollTo("bottom", anchor: .bottom)
        }
    }
    
    private func sendWithAttachment() {
        // The viewModel now handles both text and image
        viewModel.send()
    }
    
    private func compressImageData(_ data: Data, maxSizeKB: Int) -> Data? {
        guard let image = UIImage(data: data) else { return nil }
        
        let maxBytes = maxSizeKB * 1024
        var compression: CGFloat = 0.8
        var imageData = image.jpegData(compressionQuality: compression)
        
        // Reduce quality until under size limit
        while let data = imageData, data.count > maxBytes && compression > 0.1 {
            compression -= 0.1
            imageData = image.jpegData(compressionQuality: compression)
        }
        
        // If still too large, resize the image
        if let data = imageData, data.count > maxBytes {
            let scale = sqrt(Double(maxBytes) / Double(data.count))
            let newSize = CGSize(
                width: image.size.width * scale,
                height: image.size.height * scale
            )
            
            UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
            image.draw(in: CGRect(origin: .zero, size: newSize))
            let resizedImage = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()
            
            return resizedImage?.jpegData(compressionQuality: 0.7)
        }
        
        return imageData
    }
    
    private func loadDocument(from url: URL) {
        guard url.startAccessingSecurityScopedResource() else { return }
        defer { url.stopAccessingSecurityScopedResource() }
        
        do {
            let content = try String(contentsOf: url, encoding: .utf8)
            let truncated = String(content.prefix(2000))
            viewModel.inputText = "Please analyze this document (\(url.lastPathComponent)):\n\n\(truncated)"
        } catch {
            viewModel.inputText = "I tried to share a document (\(url.lastPathComponent)) but couldn't read it."
        }
    }
}

// MARK: - Document Picker

struct DocumentPickerView: UIViewControllerRepresentable {
    let onPick: (URL) -> Void
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.text, .plainText, .pdf, .json, .commaSeparatedText])
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(onPick: onPick)
    }
    
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onPick: (URL) -> Void
        
        init(onPick: @escaping (URL) -> Void) {
            self.onPick = onPick
        }
        
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            if let url = urls.first {
                onPick(url)
            }
        }
    }
}

// MARK: - Camera View

struct CameraView: UIViewControllerRepresentable {
    let onCapture: (Data) -> Void
    @Environment(\.dismiss) private var dismiss
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(onCapture: onCapture, dismiss: dismiss)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onCapture: (Data) -> Void
        let dismiss: DismissAction
        
        init(onCapture: @escaping (Data) -> Void, dismiss: DismissAction) {
            self.onCapture = onCapture
            self.dismiss = dismiss
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage,
               let data = image.jpegData(compressionQuality: 0.8) {
                onCapture(data)
            }
            dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            dismiss()
        }
    }
}

// MARK: - Typing Indicator

struct TypingIndicator: View {
    @State private var dotCount = 0
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(Color.gray)
                    .frame(width: 8, height: 8)
                    .scaleEffect(dotCount == index ? 1.2 : 0.8)
                    .animation(
                        .easeInOut(duration: 0.4)
                        .repeatForever()
                        .delay(Double(index) * 0.15),
                        value: dotCount
                    )
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .onAppear {
            Timer.scheduledTimer(withTimeInterval: 0.4, repeats: true) { _ in
                dotCount = (dotCount + 1) % 3
            }
        }
    }
}

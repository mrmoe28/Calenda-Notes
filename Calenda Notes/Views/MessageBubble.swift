//
//  MessageBubble.swift
//  Calenda Notes
//

import SwiftUI

struct MessageBubble: View {
    let message: ChatMessage
    var isStreaming: Bool = false
    
    @State private var cursorVisible = true
    @Environment(\.openURL) private var openURL
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            if message.isUser {
                Spacer(minLength: 40)
            } else {
                // AI Avatar
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.purple, .blue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 28, height: 28)
                    .overlay(
                        Image(systemName: "sparkles")
                            .font(.system(size: 12))
                            .foregroundColor(.white)
                    )
            }
            
            VStack(alignment: message.isUser ? .trailing : .leading, spacing: 4) {
                VStack(alignment: .leading, spacing: 8) {
                    // Display image if present
                    if let imageData = message.imageData, let uiImage = UIImage(data: imageData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: 250, maxHeight: 200)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    
                    // Display image from URL if present
                    if let imageURL = message.imageURL, let url = URL(string: imageURL) {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .scaledToFit()
                                    .frame(maxWidth: 250, maxHeight: 200)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                            case .failure:
                                Image(systemName: "photo")
                                    .foregroundColor(.secondary)
                            case .empty:
                                ProgressView()
                            @unknown default:
                                EmptyView()
                            }
                        }
                    }
                    
                    // Message text with links
                    HStack(spacing: 0) {
                        if message.text.isEmpty && isStreaming {
                            Text(" ")
                                .font(.body)
                        } else {
                            LinkTextView(text: message.text, isUser: message.isUser)
                        }
                        
                        // Blinking cursor for streaming
                        if isStreaming {
                            Text("▌")
                                .font(.body)
                                .foregroundColor(.blue)
                                .opacity(cursorVisible ? 1 : 0)
                                .animation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true), value: cursorVisible)
                                .onAppear { cursorVisible = false }
                        }
                    }
                }
                .foregroundColor(message.isUser ? .white : .primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    message.isUser
                    ? AnyShapeStyle(LinearGradient(
                        colors: [.blue, .blue.opacity(0.8)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    : AnyShapeStyle(Color(.systemGray6))
                )
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                
                if !isStreaming {
                    Text(formatTime(message.timestamp))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            
            if message.isUser {
                // User Avatar
                Circle()
                    .fill(Color.blue)
                    .frame(width: 28, height: 28)
                    .overlay(
                        Image(systemName: "person.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.white)
                    )
            } else {
                Spacer(minLength: 40)
            }
        }
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Link Text View

struct LinkTextView: View {
    let text: String
    let isUser: Bool
    
    var body: some View {
        Text(attributedText)
            .font(.body)
            .tint(isUser ? .white.opacity(0.9) : .blue)
    }
    
    private var attributedText: AttributedString {
        var result = AttributedString()
        let fullText = text
        
        // Parse markdown links [text](url)
        let pattern = #"\[([^\]]+)\]\(([^\)]+)\)"#
        
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return AttributedString(fullText)
        }
        
        let nsString = fullText as NSString
        let matches = regex.matches(in: fullText, options: [], range: NSRange(location: 0, length: nsString.length))
        
        var lastEnd = 0
        
        for match in matches {
            // Add text before the link
            if match.range.location > lastEnd {
                let beforeRange = NSRange(location: lastEnd, length: match.range.location - lastEnd)
                let beforeText = nsString.substring(with: beforeRange)
                result.append(AttributedString(beforeText))
            }
            
            // Extract link text and URL
            if match.numberOfRanges >= 3 {
                let linkTextRange = match.range(at: 1)
                let urlRange = match.range(at: 2)
                
                let linkText = nsString.substring(with: linkTextRange)
                let urlString = nsString.substring(with: urlRange)
                
                var linkAttr = AttributedString(linkText)
                if let url = URL(string: urlString) {
                    linkAttr.link = url
                    linkAttr.underlineStyle = .single
                }
                result.append(linkAttr)
            }
            
            lastEnd = match.range.location + match.range.length
        }
        
        // Add remaining text
        if lastEnd < nsString.length {
            let remainingRange = NSRange(location: lastEnd, length: nsString.length - lastEnd)
            let remainingText = nsString.substring(with: remainingRange)
            
            // Also detect plain URLs
            result.append(parseURLs(in: remainingText))
        } else if matches.isEmpty {
            // No markdown links found, check for plain URLs
            result = parseURLs(in: fullText)
        }
        
        return result
    }
    
    private func parseURLs(in text: String) -> AttributedString {
        var result = AttributedString()
        
        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        let nsString = text as NSString
        let matches = detector?.matches(in: text, options: [], range: NSRange(location: 0, length: nsString.length)) ?? []
        
        var lastEnd = 0
        
        for match in matches {
            // Add text before the URL
            if match.range.location > lastEnd {
                let beforeRange = NSRange(location: lastEnd, length: match.range.location - lastEnd)
                let beforeText = nsString.substring(with: beforeRange)
                result.append(AttributedString(beforeText))
            }
            
            // Add the URL with link attribute
            let urlText = nsString.substring(with: match.range)
            var urlAttr = AttributedString(urlText)
            if let url = match.url {
                urlAttr.link = url
                urlAttr.underlineStyle = .single
            }
            result.append(urlAttr)
            
            lastEnd = match.range.location + match.range.length
        }
        
        // Add remaining text
        if lastEnd < nsString.length {
            let remainingRange = NSRange(location: lastEnd, length: nsString.length - lastEnd)
            let remainingText = nsString.substring(with: remainingRange)
            result.append(AttributedString(remainingText))
        } else if matches.isEmpty {
            result = AttributedString(text)
        }
        
        return result
    }
}

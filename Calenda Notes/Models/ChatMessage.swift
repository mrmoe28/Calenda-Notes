//
//  ChatMessage.swift
//  Calenda Notes
//

import Foundation

struct ChatMessage: Identifiable, Equatable {
    let id: UUID
    let text: String
    let isUser: Bool
    let timestamp: Date
    var imageData: Data?
    var imageURL: String?
    
    init(id: UUID = UUID(), text: String, isUser: Bool, timestamp: Date = Date(), imageData: Data? = nil, imageURL: String? = nil) {
        self.id = id
        self.text = text
        self.isUser = isUser
        self.timestamp = timestamp
        self.imageData = imageData
        self.imageURL = imageURL
    }
    
    static func == (lhs: ChatMessage, rhs: ChatMessage) -> Bool {
        lhs.id == rhs.id && lhs.text == rhs.text && lhs.isUser == rhs.isUser
    }
}


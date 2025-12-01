//
//  ContactsService.swift
//  Calenda Notes
//

import Foundation
import Contacts

final class ContactsService {
    private let store = CNContactStore()
    
    var isAuthorized: Bool {
        let status = CNContactStore.authorizationStatus(for: .contacts)
        return status == .authorized
    }
    
    func requestAccess() async -> Bool {
        let status = CNContactStore.authorizationStatus(for: .contacts)
        
        if status == .notDetermined {
            do {
                let granted = try await store.requestAccess(for: .contacts)
                return granted
            } catch {
                print("❌ Contacts access error: \(error)")
                return false
            }
        }
        
        return status == .authorized
    }
    
    // MARK: - Search Contacts
    
    func searchContacts(query: String) async -> String {
        if !isAuthorized {
            let granted = await requestAccess()
            if !granted {
                return "❌ Contacts access denied. Please enable in Settings."
            }
        }
        
        let keysToFetch: [CNKeyDescriptor] = [
            CNContactGivenNameKey as CNKeyDescriptor,
            CNContactFamilyNameKey as CNKeyDescriptor,
            CNContactPhoneNumbersKey as CNKeyDescriptor,
            CNContactEmailAddressesKey as CNKeyDescriptor,
            CNContactOrganizationNameKey as CNKeyDescriptor
        ]
        
        do {
            let predicate = CNContact.predicateForContacts(matchingName: query)
            let contacts = try store.unifiedContacts(matching: predicate, keysToFetch: keysToFetch)
            
            if contacts.isEmpty {
                return "📇 No contacts found matching '\(query)'"
            }
            
            return formatContacts(contacts)
        } catch {
            return "❌ Error searching contacts: \(error.localizedDescription)"
        }
    }
    
    func getContactByName(_ name: String) async -> String {
        return await searchContacts(query: name)
    }
    
    func getContactPhone(name: String) async -> String? {
        if !isAuthorized {
            _ = await requestAccess()
        }
        
        guard isAuthorized else { return nil }
        
        let keysToFetch: [CNKeyDescriptor] = [
            CNContactGivenNameKey as CNKeyDescriptor,
            CNContactFamilyNameKey as CNKeyDescriptor,
            CNContactPhoneNumbersKey as CNKeyDescriptor
        ]
        
        do {
            let predicate = CNContact.predicateForContacts(matchingName: name)
            let contacts = try store.unifiedContacts(matching: predicate, keysToFetch: keysToFetch)
            
            if let contact = contacts.first,
               let phone = contact.phoneNumbers.first?.value.stringValue {
                return phone
            }
        } catch {
            print("❌ Error fetching contact: \(error)")
        }
        
        return nil
    }
    
    func getContactEmail(name: String) async -> String? {
        if !isAuthorized {
            _ = await requestAccess()
        }
        
        guard isAuthorized else { return nil }
        
        let keysToFetch: [CNKeyDescriptor] = [
            CNContactGivenNameKey as CNKeyDescriptor,
            CNContactFamilyNameKey as CNKeyDescriptor,
            CNContactEmailAddressesKey as CNKeyDescriptor
        ]
        
        do {
            let predicate = CNContact.predicateForContacts(matchingName: name)
            let contacts = try store.unifiedContacts(matching: predicate, keysToFetch: keysToFetch)
            
            if let contact = contacts.first,
               let email = contact.emailAddresses.first?.value as String? {
                return email
            }
        } catch {
            print("❌ Error fetching contact: \(error)")
        }
        
        return nil
    }
    
    // MARK: - Get All Contacts
    
    func getAllContacts(limit: Int = 20) async -> String {
        if !isAuthorized {
            let granted = await requestAccess()
            if !granted {
                return "❌ Contacts access denied. Please enable in Settings."
            }
        }
        
        let keysToFetch: [CNKeyDescriptor] = [
            CNContactGivenNameKey as CNKeyDescriptor,
            CNContactFamilyNameKey as CNKeyDescriptor,
            CNContactPhoneNumbersKey as CNKeyDescriptor,
            CNContactEmailAddressesKey as CNKeyDescriptor
        ]
        
        let request = CNContactFetchRequest(keysToFetch: keysToFetch)
        request.sortOrder = .givenName
        
        var contacts: [CNContact] = []
        
        do {
            try store.enumerateContacts(with: request) { contact, stop in
                contacts.append(contact)
                if contacts.count >= limit {
                    stop.pointee = true
                }
            }
        } catch {
            return "❌ Error fetching contacts: \(error.localizedDescription)"
        }
        
        if contacts.isEmpty {
            return "📇 No contacts found"
        }
        
        return "📇 Contacts (\(contacts.count)):\n" + formatContacts(contacts)
    }
    
    // MARK: - Create Contact
    
    func createContact(
        firstName: String,
        lastName: String? = nil,
        phone: String? = nil,
        email: String? = nil,
        company: String? = nil
    ) async -> String {
        if !isAuthorized {
            let granted = await requestAccess()
            if !granted {
                return "❌ Contacts access denied. Please enable in Settings."
            }
        }
        
        let contact = CNMutableContact()
        contact.givenName = firstName
        
        if let lastName = lastName {
            contact.familyName = lastName
        }
        
        if let phone = phone {
            let phoneNumber = CNPhoneNumber(stringValue: phone)
            contact.phoneNumbers = [CNLabeledValue(label: CNLabelPhoneNumberMobile, value: phoneNumber)]
        }
        
        if let email = email {
            contact.emailAddresses = [CNLabeledValue(label: CNLabelWork, value: email as NSString)]
        }
        
        if let company = company {
            contact.organizationName = company
        }
        
        let saveRequest = CNSaveRequest()
        saveRequest.add(contact, toContainerWithIdentifier: nil)
        
        do {
            try store.execute(saveRequest)
            let fullName = [firstName, lastName].compactMap { $0 }.joined(separator: " ")
            return "✅ Created contact '\(fullName)'"
        } catch {
            return "❌ Failed to create contact: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Formatting
    
    private func formatContacts(_ contacts: [CNContact]) -> String {
        var result = ""
        
        for contact in contacts {
            let name = [contact.givenName, contact.familyName]
                .filter { !$0.isEmpty }
                .joined(separator: " ")
            
            result += "• \(name.isEmpty ? "No Name" : name)\n"
            
            if let phone = contact.phoneNumbers.first?.value.stringValue {
                result += "  📱 \(phone)\n"
            }
            
            if let email = contact.emailAddresses.first?.value as String? {
                result += "  ✉️ \(email)\n"
            }
            
            if !contact.organizationName.isEmpty {
                result += "  🏢 \(contact.organizationName)\n"
            }
        }
        
        return result
    }
    
    // MARK: - Quick Lookup for Actions
    
    func lookupPhoneNumber(for name: String) async -> (name: String, phone: String)? {
        if !isAuthorized {
            _ = await requestAccess()
        }
        
        guard isAuthorized else { return nil }
        
        let keysToFetch: [CNKeyDescriptor] = [
            CNContactGivenNameKey as CNKeyDescriptor,
            CNContactFamilyNameKey as CNKeyDescriptor,
            CNContactPhoneNumbersKey as CNKeyDescriptor
        ]
        
        do {
            let predicate = CNContact.predicateForContacts(matchingName: name)
            let contacts = try store.unifiedContacts(matching: predicate, keysToFetch: keysToFetch)
            
            if let contact = contacts.first,
               let phone = contact.phoneNumbers.first?.value.stringValue {
                let fullName = [contact.givenName, contact.familyName]
                    .filter { !$0.isEmpty }
                    .joined(separator: " ")
                return (fullName, phone)
            }
        } catch {
            print("❌ Error looking up contact: \(error)")
        }
        
        return nil
    }
}

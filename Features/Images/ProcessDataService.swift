//
//  ProcessDataService.swift
//  ClientServerBasic
//
//  Created by Walter Karabin on 2026-02-02.
//

import SwiftUI

class ProcessDataService {
    static let shared = ProcessDataService()
    let apiClient: APIClient
    
    // We pass the apiClient in the init
    init(apiClient: APIClient = APIClient.shared) {
        self.apiClient = apiClient
    }
    
    // Process the extracted text data into invoice
    func processTextIntoInvoice(for fileId: String, text: [[String]]) async throws -> Invoice {
        // call the APIClient with the extracted text for a specific file
        let endpoint = AppEnvironment.apiHost.appendingPathComponent("/api/files/process/text-extract/\(fileId)")
        let payload = extractedTextRequestDTO(extractedText: text)
        let body = try JSONEncoder().encode(payload)
        let response: textExtractDTO = try await apiClient.request(
            endpoint: endpoint,
            method: "POST",
            body: body,
            responseType: textExtractDTO.self
        )
        
        print(response)
        let createdInvoice: Invoice = response.invoice
        return createdInvoice
    }
    
    func createInvoiceFromRawText(text: [[String]]) async throws -> Invoice {
        // call the APIClient with the extracted text
        let endpoint = AppEnvironment.apiHost.appendingPathComponent("/api/files/process/text-extract")
        let payload = extractedTextRequestDTO(extractedText: text)
        let body = try JSONEncoder().encode(payload)
        let response: textExtractDTO = try await apiClient.request(
            endpoint: endpoint,
            method: "POST",
            body: body,
            responseType: textExtractDTO.self
        )
        print("createInvoiceFromRawText response: \(response)")
        
        let createdInvoice: Invoice = response.invoice
        return createdInvoice
    }
}

struct extractedTextRequestDTO: Codable {
    var extractedText: [[String]]
}

struct textExtractDTO: Codable {
    var invoice: Invoice
    var message: String
}

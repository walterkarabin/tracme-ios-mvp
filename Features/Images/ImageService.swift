//
//  ImageService.swift
//  tracme-alpha
//
//  Created by Walter Karabin on 2026-02-02.
//

import Foundation
import SwiftUI

class ImageService {
    static let shared = ImageService()
    let apiClient: APIClient
    
    // We pass the apiClient in the init
    init(apiClient: APIClient = APIClient.shared) {
        self.apiClient = apiClient
    }
    
    func uploadImage(imageData: Data) async throws -> UploadedImageDTO {
        let filename = UUID().uuidString + ".jpeg"
        let endpoint = AppEnvironment.apiHost.appendingPathComponent("/api/files")
        
        let (responseData, httpResponse) = try await apiClient.uploadMultipart(
                data: imageData,
                filename: filename,
                fieldName: "file",
                mimeType: "image/jpeg",
                endpoint: endpoint)
        guard httpResponse.statusCode == 200 else {
            let body = String(data: responseData, encoding: .utf8) ?? "<no body>"
            throw NSError(domain: "ImageService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey : body])
        }
        
        // Decode server response to obtain key
        let decoder = JSONDecoder()
        let uploadedImage = try decoder.decode(UploadedImageDTO.self, from: responseData)
//        let key = meta?.key as String?
        
        return uploadedImage
    }
    
    
}

struct UploadedImageDTO: Codable {
    var mongoId: String
    var name: String
    var type: String
    var key: String
    var url: String?
    
    
    enum CodingKeys: String, CodingKey {
        case mongoId = "_id"
        case name
        case type
        case key
        case url
    }
}
/**
 export type File = {
   _id?: string;
   name: string;
   type: string;
   key: string;
   url?: string;
   processedInfo: InvoiceResponse | null;
   project?: Project | null;
   creation_date: Date;
   creator: User;
   archived: boolean;
 };
 */

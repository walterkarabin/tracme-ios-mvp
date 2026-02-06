//
//  ImageStore.swift
//  ClientServerBasic
//
//  Created by Walter Karabin on 2026-01-28.
//

import SwiftUI
import PhotosUI

// DTOs for Requests
struct InvoiceUploadRequest: Codable {
    let textRows: [[String]]
}

struct ImageUploadRequest: Codable {
    // let image: UIImage??
    // Add other fields if needed, e.g.:
    // let imageWidth: Double
    // let imageHeight: Double
}

struct UploadResponse: Codable {
    let id: String
    let message: String
}

// 1. The State (Data)
struct ImageState {
    var selectedImage: UIImage? = nil
    var textItems: [TextOverlay] = [] // Flat list for drawing boxes
    var textRows: [[TextOverlay]] = [] // Nested list for the ScrollView
    
    var isProcessing: Bool = false
    var isUploading: Bool = false // <--- NEW: Track upload status
    var uploadSuccess: Bool = false // <--- NEW: Trigger for success alert
    
    var errorMessage: String? = nil
}

// 2. The Actions (Events)
// Here I can add events for the model to execute
enum ImageAction {
    case imageSelected(UIImage)
    case processImage
    case processingComplete([TextOverlay])
    case processingFailed(String)
    
    // --- NEW UPLOAD ACTIONS ---
    case uploadImage
    case uploadTextData(String?)
    case uploadComplete
    case uploadFailed(String)
    
    // action to take once invoice is created
    case invoiceCreated(Invoice)
    case dismissPresentedInvoice

    case clear
    case clearError // Useful to dismiss alerts
}

// 3. The Store (Logic)
@MainActor
class ImageStore: ObservableObject {
    @Published private(set) var state = ImageState()
    @Published var presentedInvoice: Invoice?

    private let apiClient: APIClient
    private var invoiceStore: InvoiceStore?

    init(apiClient: APIClient = APIClient.shared, invoiceStore: InvoiceStore? = nil) {
        self.apiClient = apiClient
        self.invoiceStore = invoiceStore
    }

    /// Delegate invoice update to InvoiceStore so InvoiceView edit mode can persist changes.
    func updateInvoice(_ invoice: Invoice) async {
        await invoiceStore?.updateInvoice(invoice)
    }

    func dispatch(_ action: ImageAction) {
        switch action {
            
        case .imageSelected(let image):
            state.selectedImage = image
            state.textItems = []
            state.textRows = []
            // Automatically start processing when image is set
            dispatch(.processImage)
            
        case .processImage:
            guard let image = state.selectedImage else { return }
            print("process image")
            state.isProcessing = true
            state.errorMessage = nil
            
            // SIDE EFFECT: Call the Service
            Task {
                do {
                    // 1. OCR
                    let rawItems = try await OCRService.shared.recognizeText(from: image)
                    // 2. Color Logic
                    let coloredItems = OCRService.shared.assignColors(to: rawItems)
                    // 3. Update State
                    dispatch(.processingComplete(coloredItems))
                } catch {
                    dispatch(.processingFailed(error.localizedDescription))
                }
            }
            
        case .processingComplete(let items):
            state.isProcessing = false
            state.textItems = items
            // We calculate rows here to update the View
            state.textRows = OCRService.shared.organizeIntoRows(items: items)
            dispatch(.uploadImage)
            
        case .processingFailed(let message):
            state.isProcessing = false
            state.errorMessage = message
            
        case .uploadImage:
            // Image upload logic
            // 1. Validate we have an image
            guard let image = state.selectedImage else {
                dispatch(.uploadFailed("No image selected"))
                return
            }
//            
            state.isUploading = true
            state.errorMessage = nil
//            
            // 2. Prepare Data (Compress to JPEG)
            // compressionQuality: 1.0 is max quality, 0.8 is usually a good balance
            guard let imageData = image.jpegData(compressionQuality: 0.8) else {
                dispatch(.uploadFailed("Could not process image data"))
                return
            }
            print("upload image")
            
            Task {
                do {
                    // Call the image service
                    let uploadedImage = try await ImageService.shared.uploadImage(imageData: imageData)
                    
                    // based on the uploaded image upload the text data
                    dispatch(.uploadTextData(uploadedImage.key))
                } catch {
                    dispatch(.uploadFailed(error.localizedDescription))
                }
            }
        case .uploadTextData(let imageKey):
            // 1. Validate we have data
            guard !state.textRows.isEmpty else { return }
            print("upload text data")
            
            state.isUploading = true
            state.errorMessage = nil
            
            // 2. Prepare the Payload
            // Extract just the string text from our UI objects
            let rawStrings = state.textRows.map { row in
                row.map { $0.text }
            }
//            let payload = InvoiceUploadRequest(textRows: rawStrings)
            
            // 3. Perform the Network Request
            Task {
                do {
                    print("network request: uploading text data")
                    var invoice = nil as Invoice?
                    if let key = imageKey {
                        // --- SCENARIO A: Key was passed ---
                        // We link this text to the specific file ID/Key
                        print("processing text for key: \(key) \n text: \(rawStrings)")
                        invoice = try await ProcessDataService.shared.processTextIntoInvoice(
                            for: key,
                            text: rawStrings
                        )
                        
//                        dispatch(.invoiceCreated(invoice))
                        
                    } else {
                        // --- SCENARIO B: No Key passed (Fallback Logic) ---
                        // "Follow some other logic"
                        
                        // Example 1: Check if we have a key saved in State?
                        // if let storedKey = state.lastUploadedKey { ... }
                        
                        print("processing text with no image key, text: \(rawStrings)")
                        
                        // Example 2: Call a different API endpoint that doesn't need a file ID?
                        invoice = try await ProcessDataService.shared.createInvoiceFromRawText(text: rawStrings)
                        
                        // Example 3: Error out if a key is strictly required
//                        throw NSError(domain: "ImageStore", code: 400, userInfo: [NSLocalizedDescriptionKey: "Logic Error: No Image Key provided for text upload."])
                    }
                    // "try await" allows us to catch the specific error here
//                    let invoice = try await ProcessDataService.shared.processTextIntoInvoice(for: "123", text: "Sample")
                    // Ensure we actually have an invoice. If not, throw an error immediately.
                    guard let validInvoice = invoice else {
                        print("FAILURE")
                        throw NSError(domain: "ImageStore", code: 500, userInfo: [NSLocalizedDescriptionKey: "Failed to generate invoice: Result was nil."])
                    }
                    
                    dispatch(.invoiceCreated(validInvoice))
                } catch {
                    // Now you have the actual error from the API
                    print("Error: \(error.localizedDescription)")
                    dispatch(.processingFailed("Error creating invoice: \(error.localizedDescription)"))
                }
            }
            
        case .uploadComplete:
            state.isUploading = false
            state.uploadSuccess = true
            
        case .uploadFailed(let message):
            state.isUploading = false
            state.errorMessage = "Upload failed: \(message)"
        
        case .invoiceCreated(let invoice):
            invoiceStore?.addInvoice(invoice)
            state.isUploading = false
            state.uploadSuccess = true
            presentedInvoice = invoice

        case .dismissPresentedInvoice:
            presentedInvoice = nil

        case .clear:
            // Keep the client, reset the state
            state = ImageState()
            
        case .clearError:
            state.errorMessage = nil
            state.uploadSuccess = false
        }
    }
}

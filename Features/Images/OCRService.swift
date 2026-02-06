//
//  OCRService.swift
//  tracme-alpha
//
//  Created by Walter Karabin on 2026-01-28.
//

import SwiftUI
import Vision
import ImageIO

// 1. The Data Model
struct TextOverlay: Identifiable, Equatable {
    let id = UUID()
    let text: String
    let bounds: CGRect
    var color: Color = .yellow
    
    // Equatable allows the View to know if it needs to redraw
    static func == (lhs: TextOverlay, rhs: TextOverlay) -> Bool {
        lhs.id == rhs.id && lhs.color == rhs.color
    }
}

// 2. The Worker (Service)
class OCRService {
    static let shared = OCRService()
    
    // Step A: perform the Vision Request
    func recognizeText(from image: UIImage) async throws -> [TextOverlay] {
        guard let cgImage = image.cgImage else { return [] }
        
        let orientation = CGImagePropertyOrientation(image.imageOrientation)
        let requestHandler = VNImageRequestHandler(cgImage: cgImage, orientation: orientation)
        
        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(returning: [])
                    return
                }
                let items = observations.compactMap { observation -> TextOverlay? in
                    guard let candidate = observation.topCandidates(1).first else { return nil }
                    return TextOverlay(text: candidate.string, bounds: observation.boundingBox)
                }
                continuation.resume(returning: items)
            }
            request.recognitionLevel = .accurate
            try? requestHandler.perform([request])
        }
    }
    
    // Step B: Assign Colors
    func assignColors(to items: [TextOverlay]) -> [TextOverlay] {
        var resultItems = items
        var knownGroups: [(y: CGFloat, h: CGFloat, color: Color)] = []
        let palette: [Color] = [.red, .green, .blue, .orange, .purple, .cyan]
        let tolerance: CGFloat = 0.01
        
        for index in resultItems.indices {
            let item = resultItems[index]
            if let matchIndex = knownGroups.firstIndex(where: { group in
                abs(group.y - item.bounds.minY) < tolerance &&
                abs(group.h - item.bounds.height) < tolerance
            }) {
                resultItems[index].color = knownGroups[matchIndex].color
            } else {
                let newColor = palette[knownGroups.count % palette.count]
                knownGroups.append((y: item.bounds.minY, h: item.bounds.height, color: newColor))
                resultItems[index].color = newColor
            }
        }
        return resultItems
    }
    
    // Step C: Organize (Returns both the flat list and the rows)
    func organizeIntoRows(items: [TextOverlay]) -> [[TextOverlay]] {
        let sortedItems = items.sorted { $0.bounds.maxY > $1.bounds.maxY }
        var rows: [[TextOverlay]] = []
        var currentRow: [TextOverlay] = []
        
        for item in sortedItems {
            guard let lastItemInRow = currentRow.last else {
                currentRow.append(item)
                continue
            }
            let verticalDistance = abs(item.bounds.midY - lastItemInRow.bounds.midY)
            let heightThreshold = lastItemInRow.bounds.height * 0.5
            
            if verticalDistance < heightThreshold {
                currentRow.append(item)
            } else {
                rows.append(currentRow.sorted { $0.bounds.minX < $1.bounds.minX })
                currentRow = [item]
            }
        }
        if !currentRow.isEmpty {
            rows.append(currentRow.sorted { $0.bounds.minX < $1.bounds.minX })
        }
        return rows
    }
}

// Orientation Helper
extension CGImagePropertyOrientation {
    init(_ uiOrientation: UIImage.Orientation) {
        switch uiOrientation {
        case .up: self = .up
        case .upMirrored: self = .upMirrored
        case .down: self = .down
        case .downMirrored: self = .downMirrored
        case .left: self = .left
        case .leftMirrored: self = .leftMirrored
        case .right: self = .right
        case .rightMirrored: self = .rightMirrored
        @unknown default: self = .up
        }
    }
}

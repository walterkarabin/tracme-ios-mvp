//
//  ImageView.swift
//  ClientServerBasic
//
//  Created by Walter Karabin on 2026-01-23.
//

import SwiftUI
import PhotosUI
import Vision

enum InvoicePresentation { case sheet, popup }

struct ImageView: View {
    @StateObject private var store: ImageStore
    var invoicePresentation: InvoicePresentation = .sheet

    init(invoiceStore: InvoiceStore? = nil, invoicePresentation: InvoicePresentation = .sheet) {
        _store = StateObject(wrappedValue: ImageStore(invoiceStore: invoiceStore))
        self.invoicePresentation = invoicePresentation
    }

    // 2. Keep UI-only state (Zoom/Pan/Navigation) local
    @State private var currentScale: CGFloat = 1.0
    @State private var finalScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var isTextVisible: Bool = false
    
    @State private var showingCamera: Bool = false
    @State private var showingLiveScanner: Bool = false
    @State private var selectedPickerItem: PhotosPickerItem? // Helper for the picker

    var body: some View {
        NavigationStack {
            VStack {
                Spacer()
                
                // --- IMAGE AREA ---
                if let selectedImage = store.state.selectedImage {
                    GeometryReader { proxy in
                        ZStack {
                            Image(uiImage: selectedImage)
                                .resizable()
                                .scaledToFit()
                                .overlay {
                                    GeometryReader { geometry in
                                        overlayContent(in: geometry)
                                    }
                                }
                            // Zoom Modifiers
                                .scaleEffect(currentScale)
                                .offset(offset)
                                .gesture(zoomGesture)
                                .onTapGesture(count: 2, coordinateSpace: .local) { loc in
                                    handleDoubleTap(at: loc, in: proxy)
                                }
                                .onTapGesture {
                                    withAnimation { isTextVisible.toggle() }
                                }
                        }
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .clipped()
                    }
                    .frame(height: 400)
                    .cornerRadius(25)
                } else {
                    ContentUnavailableView("No Image", systemImage: "photo")
                }
                
                if store.state.isProcessing {
                    ProgressView("Scanning Text...")
                        .padding()
                }
                
                // --- CONTROLS ---
                VStack(spacing: 12) {
                    PhotosPicker(selection: $selectedPickerItem, matching: .images) {
                        Label("Select from Library", systemImage: "photo.on.rectangle")
                            .primaryButtonStyle(color: .blue)
                    }
                    
                    Button(action: { showingCamera = true }) {
                        Label("Take Photo", systemImage: "camera")
                            .primaryButtonStyle(color: .blue)
                    }
                    
                    Button(action: { showingLiveScanner = true }) {
                        Label("Live Scan", systemImage: "text.viewfinder")
                            .primaryButtonStyle(color: .indigo)
                    }
                }
                .padding(.horizontal)
                
                Spacer(minLength: 16)
            }
            .padding()
            
            // --- EVENT HANDLERS ---
            
            // 1. Handle Gallery Selection
            .onChange(of: selectedPickerItem) { _, newItem in
                Task {
                    if let data = try? await newItem?.loadTransferable(type: Data.self),
                       let uiImage = UIImage(data: data) {
                        // SEND ACTION
                        store.dispatch(.imageSelected(uiImage))
                    }
                }
            }
            
            // 2. Sheets
            .fullScreenCover(isPresented: $showingCamera) {
                ARCameraView(image: Binding(
                    get: { store.state.selectedImage },
                    set: { if let img = $0 { store.dispatch(.imageSelected(img)) } }
                ))
            }
            .sheet(isPresented: $showingLiveScanner) { }
            .sheet(item: invoicePresentation == .sheet ? $store.presentedInvoice : .constant(nil)) { inv in
                InvoiceView(
                    invoice: inv,
                    onDismiss: { store.dispatch(.dismissPresentedInvoice) },
                    onSave: { updated in await store.updateInvoice(updated) }
                )
            }
            .overlay {
                if invoicePresentation == .popup, let inv = store.presentedInvoice {
                    Color.black.opacity(0.4).ignoresSafeArea()
                        .onTapGesture { store.dispatch(.dismissPresentedInvoice) }
                        .overlay {
                            InvoiceView(
                                invoice: inv,
                                onDismiss: { store.dispatch(.dismissPresentedInvoice) },
                                onSave: { updated in await store.updateInvoice(updated) }
                            )
                            .frame(maxWidth: 400)
                            .background(Color(.systemBackground))
                            .cornerRadius(12)
                            .padding(24)
                        }
                }
            }
        }
    }
    
    private func handleDoubleTap(at location: CGPoint, in proxy: GeometryProxy) {
        withAnimation(.easeInOut) {
            if currentScale > 1 {
                // Case A: Zoom Out (Reset)
                currentScale = 1
                finalScale = 1
                offset = .zero
                lastOffset = .zero
            } else {
                // Case B: Zoom In (to 3x)
                currentScale = 3
                finalScale = 3
                
                // Calculate the offset to center the tap point
                let halfWidth = proxy.size.width / 2
                let halfHeight = proxy.size.height / 2
                
                let xDistance = halfWidth - location.x
                let yDistance = halfHeight - location.y
                
                offset = CGSize(
                    width: xDistance * (currentScale - 1),
                    height: yDistance * (currentScale - 1)
                )
                
                lastOffset = offset
            }
        }
    }
    
    @ViewBuilder
    private func overlayContent(in geometry: GeometryProxy) -> some View {
        if isTextVisible {
            ForEach(store.state.textItems) { item in
                textBubble(for: item, in: geometry)
            }
        } else {
            ForEach(store.state.textItems) { item in
                boundingBox(for: item, in: geometry)
                
            }
        }
    }
    
    private func textBubble(for item: TextOverlay, in geometry: GeometryProxy) -> some View {
        Text(item.text)
            .padding(4)
            .background(Color.black.opacity(0.7))
            .foregroundColor(.white)
            .font(.caption)
            .cornerRadius(4)
        // POSITIONING MAGIC:
            .position(
                x: item.bounds.midX * geometry.size.width,
                y: (1 - item.bounds.midY) * geometry.size.height
            )
    }
    
    private func boundingBox(for item: TextOverlay, in geometry: GeometryProxy) -> some View {
        // Rectangles
        Rectangle()
            .stroke(item.color.opacity(0.7), style: StrokeStyle(lineWidth: 2))
            .frame(
                width: item.bounds.width * geometry.size.width,
                height: item.bounds.height * geometry.size.height
            )
            .position(x: item.bounds.midX * geometry.size.width,
                      y: (1 - item.bounds.midY) * geometry.size.height)
    }
    
    var zoomGesture: some Gesture {
        SimultaneousGesture(
            // 1. MAGNIFICATION (Pinch)
            MagnificationGesture()
                .onChanged { value in
                    let newScale = finalScale * value
                    
                    // CHANGE A: Allow zooming out to 0.5 (was 1)
                    // This gives the user the "rubber band" feeling
                    currentScale = max(0.5, min(newScale, 5))
                }
                .onEnded { _ in
                    finalScale = currentScale
                    
                    // CHANGE B: The Snap Back Logic
                    // If the user releases while zoomed out (scale < 1)...
                    if finalScale < 1 {
                        // ...smoothly animate back to normal size and center
                        withAnimation(.spring()) {
                            currentScale = 1
                            finalScale = 1
                            offset = .zero     // Reset position to center
                            lastOffset = .zero // Reset drag memory
                        }
                    }
                },
            
            // 2. DRAG (Pan)
            DragGesture()
                .onChanged { value in
                    // Only allow dragging if we are actually zoomed in
                    if currentScale > 1 {
                        offset = CGSize(
                            width: lastOffset.width + value.translation.width,
                            height: lastOffset.height + value.translation.height
                        )
                    }
                }
                .onEnded { _ in
                    if currentScale > 1 {
                        lastOffset = offset
                    }
                }
        )
    }
    
}

// Helper for Button Styles
extension View {
    func primaryButtonStyle(color: Color) -> some View {
        self.padding()
            .frame(maxWidth: .infinity)
            .background(color)
            .foregroundColor(.white)
            .cornerRadius(25)
    }
}


#Preview {
    class MockAuth: AuthProvider {
        var accessToken: String? = "mock_token"
        var refreshToken: String? = "mock_refresh"
        func refreshAccessToken() async -> Bool { return true }
        func removeAccessToken() {}
    }
    return ImageView()
}

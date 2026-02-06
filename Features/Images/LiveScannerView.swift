//
//  LiveScannerView.swift
//  tracme-alpha
//
//  Created by Walter Karabin on 2026-01-27.
//

import SwiftUI
import AVFoundation
import Vision

struct LiveScannerView: View {
    // We use the same struct as before
    @State private var detectedItems: [TextOverlay] = []
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        ZStack {
            // 1. Black Background (for the letterboxing bars)
            Color.black.ignoresSafeArea()
            
            // 2. The Camera Feed + Overlay
            GeometryReader { geometry in
                ZStack {
                    // Camera
                    LiveCameraRepresentable(detectedItems: $detectedItems)
                    
                    // Bounding Boxes
                    ForEach(detectedItems) { item in
                        Rectangle()
                            .stroke(Color.yellow, lineWidth: 2)
                            .background(Color.yellow.opacity(0.2))
                            .frame(
                                width: item.bounds.width * geometry.size.width,
                                height: item.bounds.height * geometry.size.height
                            )
                            .position(
                                x: item.bounds.midX * geometry.size.width,
                                y: (1 - item.bounds.midY) * geometry.size.height
                            )
                    }
                }
            }
            
            // 3. Close Button
            VStack {
                HStack {
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.largeTitle)
                            .foregroundColor(.white)
                            .padding()
                    }
                }
                Spacer()
            }
        }
    }
}

// MARK: - The Bridge
struct LiveCameraRepresentable: UIViewControllerRepresentable {
    @Binding var detectedItems: [TextOverlay]
    
    func makeUIViewController(context: Context) -> ScannerViewController {
        let controller = ScannerViewController()
        controller.delegate = context.coordinator
        return controller
    }
    
    func updateUIViewController(_ uiViewController: ScannerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }
    
    class Coordinator: NSObject, ScannerViewControllerDelegate {
        var parent: LiveCameraRepresentable
        
        init(parent: LiveCameraRepresentable) {
            self.parent = parent
        }
        
        func didDetectItems(items: [TextOverlay]) {
            parent.detectedItems = items
        }
    }
}

// MARK: - The Camera Controller
protocol ScannerViewControllerDelegate: AnyObject {
    func didDetectItems(items: [TextOverlay])
}

class ScannerViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {
    
    weak var delegate: ScannerViewControllerDelegate?
    private let captureSession = AVCaptureSession()
    private var lastProcessingTime = Date()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // 1. Setup Camera (Standard Back Camera)
        guard let captureDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: captureDevice) else { return }
        
        captureSession.addInput(input)
        
        // 2. Setup Output
        let output = AVCaptureVideoDataOutput()
        output.setSampleBufferDelegate(self, queue: DispatchQueue(label: "videoQueue"))
        captureSession.addOutput(output)
        
        // 3. Setup Preview Layer
        let previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.frame = view.bounds
        // IMPORTANT: Use .resizeAspect (Fit) so coordinates match perfectly
        previewLayer.videoGravity = .resizeAspect
        view.layer.addSublayer(previewLayer)
        
        // 4. Start
        DispatchQueue.global(qos: .background).async {
            self.captureSession.startRunning()
        }
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        view.layer.sublayers?.first?.frame = view.bounds
    }
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        
        // Throttle: Process 5 times per second
        guard Date().timeIntervalSince(lastProcessingTime) >= 0.2 else { return }
        lastProcessingTime = Date()
        
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        let request = VNRecognizeTextRequest { [weak self] request, error in
            guard let observations = request.results as? [VNRecognizedTextObservation] else { return }
            
            // Map results to our struct
            let overlayItems = observations.compactMap { observation -> TextOverlay? in
                guard let candidate = observation.topCandidates(1).first else { return nil }
                return TextOverlay(text: candidate.string, bounds: observation.boundingBox)
            }
            
            DispatchQueue.main.async {
                self?.delegate?.didDetectItems(items: overlayItems)
            }
        }
        
        request.recognitionLevel = .fast
        
        // Live video is usually .right oriented relative to sensor
        try? VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .right).perform([request])
    }
}

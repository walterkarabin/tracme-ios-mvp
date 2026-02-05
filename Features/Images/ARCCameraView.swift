//
//  ARCCameraView.swift
//  ClientServerBasic
//
//  Created by Walter Karabin on 2026-01-27.
//

import SwiftUI
import AVFoundation
import Vision

struct ARCameraView: View {
    @Binding var image: UIImage? // Where we save the final photo
    @Environment(\.dismiss) var dismiss
    
    // State for the boxes
    @State private var detectedItems: [TextOverlay] = []
    
    // Trigger to tell the camera to snap
    @State private var shouldCapturePhoto = false
    
    var body: some View {
        ZStack {
            // 1. The Camera Preview & Vision Logic
            // We pass the 'shouldCapturePhoto' binding so the controller knows when to snap
            ARCameraRepresentable(
                detectedItems: $detectedItems,
                image: $image,
                shouldCapturePhoto: $shouldCapturePhoto,
                dismissAction: { dismiss() }
            )
            .ignoresSafeArea()
            
            // 2. The Live Bounding Boxes (The "Feedback")
            GeometryReader { geometry in
                ForEach(detectedItems) { item in
                    Rectangle()
                        .stroke(Color.blue, lineWidth: 2)
                        .background(Color.blue.opacity(0.1))
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
            
            // 3. UI Controls (Shutter Button & Close)
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
                
                // SHUTTER BUTTON
                Button(action: {
                    // Trigger the capture in the Representable
                    shouldCapturePhoto = true
                }) {
                    ZStack {
                        Circle()
                            .fill(Color.white)
                            .frame(width: 70, height: 70)
                        Circle()
                            .stroke(Color.white, lineWidth: 4)
                            .frame(width: 80, height: 80)
                    }
                }
                .padding(.bottom, 30)
            }
        }
    }
}

// MARK: - The Bridge
struct ARCameraRepresentable: UIViewControllerRepresentable {
    @Binding var detectedItems: [TextOverlay]
    @Binding var image: UIImage?
    @Binding var shouldCapturePhoto: Bool
    var dismissAction: () -> Void
    
    func makeUIViewController(context: Context) -> ARScannerViewController {
        let controller = ARScannerViewController()
        controller.delegate = context.coordinator
        return controller
    }
    
    // This function runs whenever SwiftUI state changes
    func updateUIViewController(_ uiViewController: ARScannerViewController, context: Context) {
        if shouldCapturePhoto {
            uiViewController.capturePhoto()
            // Reset the trigger immediately so we don't take 100 photos
            DispatchQueue.main.async {
                shouldCapturePhoto = false
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }
    
    class Coordinator: NSObject, ARScannerViewControllerDelegate {
        var parent: ARCameraRepresentable
        
        init(parent: ARCameraRepresentable) {
            self.parent = parent
        }
        
        func didDetectItems(items: [TextOverlay]) {
            parent.detectedItems = items
        }
        
        func didCapturePhoto(image: UIImage) {
            parent.image = image
            parent.dismissAction() // Close the sheet
        }
    }
}

// MARK: - The Camera Controller
protocol ARScannerViewControllerDelegate: AnyObject {
    func didDetectItems(items: [TextOverlay])
    func didCapturePhoto(image: UIImage)
}

class ARScannerViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate, AVCapturePhotoCaptureDelegate {
    
    weak var delegate: ARScannerViewControllerDelegate?
    private let captureSession = AVCaptureSession()
    private let photoOutput = AVCapturePhotoOutput() // <--- NEW: For taking pictures
    private var lastProcessingTime = Date()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupCamera()
    }
    
    private func setupCamera() {
        guard let captureDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: captureDevice) else { return }
        
        captureSession.beginConfiguration()
        
        if captureSession.canAddInput(input) { captureSession.addInput(input) }
        
        // 1. Video Data Output (For Vision/Overlays)
        let videoOutput = AVCaptureVideoDataOutput()
        videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "videoQueue"))
        if captureSession.canAddOutput(videoOutput) { captureSession.addOutput(videoOutput) }
        
        // 2. Photo Output (For High Res Capture)
        if captureSession.canAddOutput(photoOutput) { captureSession.addOutput(photoOutput) }
        
        captureSession.commitConfiguration()
        
        // 3. Preview Layer
        let previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.frame = view.bounds
        previewLayer.videoGravity = .resizeAspect // Maintain aspect ratio for accurate boxes
        view.layer.addSublayer(previewLayer)
        
        DispatchQueue.global(qos: .background).async {
            self.captureSession.startRunning()
        }
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        view.layer.sublayers?.first?.frame = view.bounds
    }
    
    // MARK: - Public Action
    func capturePhoto() {
        let settings = AVCapturePhotoSettings()
        photoOutput.capturePhoto(with: settings, delegate: self)
    }
    
    // MARK: - Photo Capture Delegate
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let data = photo.fileDataRepresentation(), let uiImage = UIImage(data: data) {
            DispatchQueue.main.async {
                self.delegate?.didCapturePhoto(image: uiImage)
            }
        }
    }
    
    // MARK: - Video Frame Delegate (Vision)
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        
        // Throttle Vision (prevent overheating)
        guard Date().timeIntervalSince(lastProcessingTime) >= 0.1 else { return }
        lastProcessingTime = Date()
        
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        let request = VNRecognizeTextRequest { [weak self] request, error in
            guard let observations = request.results as? [VNRecognizedTextObservation] else { return }
            
            let overlayItems = observations.compactMap { observation -> TextOverlay? in
                guard let candidate = observation.topCandidates(1).first else { return nil }
                return TextOverlay(text: candidate.string, bounds: observation.boundingBox)
            }
            
            DispatchQueue.main.async {
                self?.delegate?.didDetectItems(items: overlayItems)
            }
        }
        
        request.recognitionLevel = .fast
        try? VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .right).perform([request])
    }
}

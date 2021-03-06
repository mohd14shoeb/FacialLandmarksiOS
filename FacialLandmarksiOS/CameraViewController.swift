//
//  ViewController.swift
//  FacialLandmarksiOS
//
//  Created by Khurram on 30/09/2018.
//  Copyright © 2018 Example. All rights reserved.
//

import Vision
import AVFoundation
import UIKit

class CameraViewController: UIViewController {

override func viewDidLoad() {
    super.viewDidLoad()
    // Do any additional setup after loading the view, typically from a nib.
    if isCameraAuthorized() {
        configureSession()
    }
}
    
private let session = AVCaptureSession()
private let faceDetectionRequest = VNDetectFaceRectanglesRequest()
private let faceDetectionRequestHandler = VNSequenceRequestHandler()
private var cameraView: CameraView {
    return view as! CameraView
}
    
}

extension CameraViewController {
    
private func handleDetection(detectionResults: [VNFaceObservation]) {
    DispatchQueue.main.async {
        if let sublayers = self.view.layer.sublayers {
            for layer in sublayers[1...] {
                layer.removeFromSuperlayer()
            }
        }
        let viewWidth = self.view.frame.size.width
        let viewHeight = self.view.frame.size.height
        for result in detectionResults {
            
            let layer = self.newRectangularLayer()
            
            var rect = result.boundingBox
            rect.origin.x *= viewWidth
            rect.size.height *= viewHeight
            rect.origin.y = ((1 - rect.origin.y) * viewHeight) - rect.size.height
            rect.size.width *= viewWidth
            
            layer.frame = rect
            layer.borderWidth = 2
            layer.borderColor = UIColor.red.cgColor
            self.view.layer.addSublayer(layer)
        }
    }
}
private func isCameraAuthorized() -> Bool {
    let authorizationStatus = AVCaptureDevice.authorizationStatus(for: AVMediaType.video)
    switch authorizationStatus {
    case .notDetermined:
        AVCaptureDevice.requestAccess(for: AVMediaType.video,
                                      completionHandler: { (granted:Bool) -> Void in
                                        if granted {
                                            DispatchQueue.main.async {
                                                self.configureSession()
                                            }
                                        }
        })
        return true
    case .authorized:
        return true
    case .denied, .restricted: return false
    }
}
private func configureSession() {
    
    cameraView.session = session
    
    let position = AVCaptureDevice.Position.front
    let cameraDevices = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera], mediaType: AVMediaType.video, position: position)
    var cameraDevice: AVCaptureDevice?
    for device in cameraDevices.devices {
        if device.position == position {
            cameraDevice = device
            break
        }
    }
    do {
        let captureDeviceInput = try AVCaptureDeviceInput(device: cameraDevice!)
        if session.canAddInput(captureDeviceInput) {
            session.addInput(captureDeviceInput)
        }
    }
    catch {
        print("Error occured \(error)")
        return
    }
    session.sessionPreset = .high
    let videoDataOutput = AVCaptureVideoDataOutput()
    videoDataOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "BackgroundQueue", qos: .userInteractive, attributes: .concurrent, autoreleaseFrequency: .inherit, target: nil))
    if session.canAddOutput(videoDataOutput) {
        session.addOutput(videoDataOutput)
    }
    cameraView.videoPreviewLayer.videoGravity = .resizeAspectFill
    session.startRunning()
}
private func newRectangularLayer() -> CALayer {
    
    let layer = CALayer()
    layer.borderWidth = 2
    layer.borderColor = UIColor.red.cgColor
    return layer
}
}

extension CameraViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
// MARK: - Camera Delegate and Setup
func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
    guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
        return
    }
    var imageRequestOptions = [VNImageOption: Any]()
    if let cameraData = CMGetAttachment(sampleBuffer, key: kCMSampleBufferAttachmentKey_CameraIntrinsicMatrix, attachmentModeOut: nil) {
        imageRequestOptions[.cameraIntrinsics] = cameraData
    }
    do {
        try faceDetectionRequestHandler.perform([faceDetectionRequest], on: pixelBuffer, orientation: CGImagePropertyOrientation(rawValue: 6)!)
    }
    catch {
        print(error)
        return
    }
    guard let results = faceDetectionRequest.results as? [VNFaceObservation] else { return }
    handleDetection(detectionResults: results)
}
}

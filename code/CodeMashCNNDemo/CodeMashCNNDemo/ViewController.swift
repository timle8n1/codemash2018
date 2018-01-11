//
//  ViewController.swift
//  CodeMashCNNDemo
//
//  Created by Tim Lemaster on 1/6/18.
//  Copyright © 2018 LeMaster Design Lab. All rights reserved.
//

import UIKit
import AVFoundation

class ViewController: UIViewController {
    
    @IBOutlet private var captureView: UIView!
    @IBOutlet private var boundingBox: UIView!
    @IBOutlet private var neuralInputImageView: UIImageView!
    
    @IBOutlet var confidenceLabels: [UILabel]!
    
    
    var session: AVCaptureSession?
    var device: AVCaptureDevice?
    var input: AVCaptureDeviceInput?
    var output: AVCaptureMetadataOutput?
    var prevLayer: AVCaptureVideoPreviewLayer?

    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupViews()
        setupCaptureSession()
    }
    
    override func viewDidLayoutSubviews() {
        prevLayer?.frame.size = captureView.frame.size
        super.viewDidLayoutSubviews()
    }
    
    private func setupViews() {
        boundingBox.layer.borderColor = UIColor.white.cgColor
        boundingBox.layer.borderWidth = 1.0
    }

    private func setupCaptureSession() {
        session = AVCaptureSession()
        device = AVCaptureDevice.default(for: AVMediaType.video)
        
        input = try! AVCaptureDeviceInput(device: device!)
        session?.addInput(input!)
        
        prevLayer = AVCaptureVideoPreviewLayer(session: session!)
        prevLayer?.frame.size = captureView.frame.size
        prevLayer?.videoGravity = AVLayerVideoGravity.resizeAspectFill
        
        captureView.layer.addSublayer(prevLayer!)
        
        let videoDataOutput = AVCaptureVideoDataOutput()
        videoDataOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as AnyHashable as! String: NSNumber(value: kCVPixelFormatType_32BGRA)]
        videoDataOutput.alwaysDiscardsLateVideoFrames = true
        let queue = DispatchQueue.global(qos: .utility)
        videoDataOutput.setSampleBufferDelegate(self, queue: queue)
        
        session?.addOutput(videoDataOutput)
        
        if let connection = videoDataOutput.connection(with: .video) {
            connection.videoOrientation = .portrait
        }
        
        session?.startRunning()
    }
}

extension ViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
    
    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer)
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        
        let int32Buffer = unsafeBitCast(CVPixelBufferGetBaseAddress(pixelBuffer),
                                        to: UnsafeMutablePointer<UInt8>.self)
        
        let blue = int32Buffer[0]
        let green = int32Buffer[1]
        let red  = int32Buffer[2]
        let alpha  = int32Buffer[3]
        
        print("RGB:\(red) \(green) \(blue)")
        
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue)
        guard let context = CGContext(data: baseAddress,
                                      width: width,
                                      height: height,
                                      bitsPerComponent: 8,
                                      bytesPerRow: bytesPerRow,
                                      space: colorSpace,
                                      bitmapInfo: bitmapInfo.rawValue) else { return }
        guard let cgImage = context.makeImage() else { return }
        CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly)
        
        guard let cropImage = cgImage.cropping(to: CGRect(x: width/2 - 161,
                                                          y: height/2 - 161,
                                                          width: 323,
                                                          height: 323)) else { return }
        
        let monoFilter = CIFilter(name: "CIColorMonochrome")
        monoFilter!.setValue(CIColor(red: 1.0, green: 1.0, blue: 1.0), forKey: "inputColor")
        monoFilter!.setValue(1.0, forKey: "inputIntensity")
        
        let invertFilter = CIFilter(name: "CIColorInvert")
        
        // convert UIImage to CIImage and set as input
        
        let ciInput = CIImage(cgImage: cropImage)
        monoFilter?.setValue(ciInput, forKey: "inputImage")
        invertFilter?.setValue(monoFilter?.outputImage, forKey: "inputImage")
        
        // get output CIImage, render as CGImage first to retain proper UIImage scale
        
        let ciOutput = invertFilter?.outputImage
        let ciContext = CIContext()
        guard let monoImage = ciContext.createCGImage(ciOutput!, from: (ciOutput?.extent)!) else { return }

        DispatchQueue.main.async { [weak self] in
            self?.neuralInputImageView.image = UIImage(cgImage: monoImage)
        }
        
        predict(image: monoImage)
    }
}

extension ViewController {
    
    func predict(image: CGImage) {
        let predictor = DigitPredictor()
        
        predictor.predictDigit(fromImage: image) { (observations) in
            
            if let confidenceArray = observations[0].featureValue.multiArrayValue {
                
                for i in 0...9 {
                    let displayConfidence = String(format:"%.0f", confidenceArray[i].floatValue * 100.0)
                    self.confidenceLabels[i].text = "\(i): \(displayConfidence)%"
                }
            }
        }
    }
}

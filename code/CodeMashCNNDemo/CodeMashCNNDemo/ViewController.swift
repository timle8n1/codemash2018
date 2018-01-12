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
    
    @IBOutlet var digitLabel: UILabel!
    
    
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
        
        let int8Buffer = unsafeBitCast(CVPixelBufferGetBaseAddress(pixelBuffer),
                                    to: UnsafeMutablePointer<UInt8>.self)
        
        
        let startRow = height/2 - 161
        let startColumn = width/2 - 161
        
        var yTotal = 0
        var xTotal = 0
        var blackPixels = 0
        
        for y in startRow...startRow + 323 {
            for x in startColumn...startColumn + 323 {
                let rowOffset = y * bytesPerRow
                let columnOffset = x * 4
                
                let blue = int8Buffer[rowOffset + columnOffset]
                let green = int8Buffer[rowOffset + columnOffset + 1]
                let red  = int8Buffer[rowOffset + columnOffset + 2]
                
                let total = UInt32(blue) + UInt32(green) + UInt32(red)
                
                if total < 100 {
                    blackPixels += 1
                    yTotal += y
                    xTotal += x
                }
            }
        }
        
        var xCenter: Int?
        var yCenter: Int?
        if blackPixels > 0 {
            xCenter = Int(Float(xTotal/blackPixels - startColumn) * 0.061) - 10
            yCenter = Int(Float(yTotal/blackPixels - startRow) * 0.061) - 10
        }
        
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
        
        let resizeFilter = CIFilter(name: "CILanczosScaleTransform")
        resizeFilter!.setValue(0.061, forKey: "inputScale")
        resizeFilter!.setValue(1.0, forKey: "inputAspectRatio")
        
        let monoFilter = CIFilter(name: "CIColorMonochrome")
        monoFilter!.setValue(CIColor(red: 1.0, green: 1.0, blue: 1.0), forKey: "inputColor")
        monoFilter!.setValue(1.0, forKey: "inputIntensity")
        
        let invertFilter = CIFilter(name: "CIColorInvert")
        
        let ciInput = CIImage(cgImage: cropImage)
        resizeFilter?.setValue(ciInput, forKey: "inputImage")
        monoFilter?.setValue(resizeFilter?.outputImage, forKey: "inputImage")
        invertFilter?.setValue(monoFilter?.outputImage, forKey: "inputImage")
        
        let ciOutput = invertFilter?.outputImage
        let ciContext = CIContext()
        
        guard let monoImage = ciContext.createCGImage(ciOutput!, from: (ciOutput?.extent)!) else { return };
        
        let size = CGSize(width: 28, height: 28)
        UIGraphicsBeginImageContextWithOptions(size, true, 1.0)
        
        let centerContext = UIGraphicsGetCurrentContext()
        centerContext?.translateBy(x: 0, y: 28)
        centerContext?.scaleBy(x: 1.0, y: -1.0)
        
        var offsetX = 4
        var offsetY = 4
        if let xCenter = xCenter,
            let yCenter = yCenter {
            
            if xCenter < -4 {
                offsetX = 8
            } else if xCenter > 4 {
                offsetX = 0
            } else {
                offsetX -= xCenter
            }
            
            if yCenter < -4 {
                offsetY = 8
            } else if yCenter > 4 {
                offsetY = 0
            } else {
                offsetY -= yCenter
            }
        }
        
        centerContext!.draw(monoImage, in: CGRect(x: offsetX, y: offsetY, width: 20, height: 20))
        guard let centerImage = centerContext?.makeImage() else { return }
        
        DispatchQueue.main.async { [weak self] in
            self?.neuralInputImageView.image = UIImage(cgImage: centerImage)
        }
        
        predict(image: centerImage)
    }
}

extension ViewController {
    
    func predict(image: CGImage) {
        let predictor = DigitPredictor()
        
        predictor.predictDigit(fromImage: image) { (observations) in
            
            if let confidenceArray = observations[0].featureValue.multiArrayValue {
                
                var digitIndex = 0
                var score = Float(0.0)
                
                for i in 0...9 {
                    
                    let displayConfidence = confidenceArray[i].floatValue
                    
                    if displayConfidence > score {
                        digitIndex = i
                        score = displayConfidence
                    }
                }
                
                self.digitLabel.text = "\(digitIndex)"
            }
        }
    }
}

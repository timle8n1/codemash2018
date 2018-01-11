//
//  DigitPredictor.swift
//  CodeMashCNNDemo
//
//  Created by Tim Lemaster on 1/6/18.
//  Copyright © 2018 LeMaster Design Lab. All rights reserved.
//

import Foundation
import Vision
import CoreML

class DigitPredictor {
    
    let model = try! VNCoreMLModel(for: mnist_cnn().model)
    
    func predictDigit(fromImage image: CGImage, completion: @escaping ([VNCoreMLFeatureValueObservation]) -> ()) {
        
        let request = VNCoreMLRequest(model: model) { (request, error) in
            
            DispatchQueue.main.async {
                let observations = request.results as! [VNCoreMLFeatureValueObservation]
                completion(observations)
            }
        }
        
        DispatchQueue.global().async {
            let handler = VNImageRequestHandler(cgImage: image)
            
            do {
                try handler.perform([request])
            } catch {}
        }
    }
}

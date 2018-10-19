/**
 * Copyright IBM Corporation 2017, 2018
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 **/

import UIKit
import AVFoundation
import Vision

class CameraViewController: UIViewController {

    // MARK: - IBOutlets
    
    @IBOutlet weak var cameraView: UIView!
    @IBOutlet weak var focusView: UIImageView!
    @IBOutlet weak var captureButton: UIButton!

    // MARK: - Variable Declarations
    
    let cloudVision: CloudVision = {
        guard let path = Bundle.main.path(forResource: "Credentials", ofType: "plist") else {
            // Please create a Credentials.plist file with your Object Storage credentials.
            fatalError()
        }
        guard let apiKey = NSDictionary(contentsOfFile: path)?["apikey"] as? String else {
            // No Object Storage API key found. Make sure you add your API key to the Credentials.plist file.
            fatalError()
        }
        return CloudVision(endpoint: CloudVisionConstants.endpoint, apiKey: apiKey)
    }()
    
    let photoOutput = AVCapturePhotoOutput()
    lazy var captureSession: AVCaptureSession? = {
        guard let backCamera = AVCaptureDevice.default(for: .video),
            let input = try? AVCaptureDeviceInput(device: backCamera) else {
                return nil
        }
        
        let captureSession = AVCaptureSession()
        captureSession.sessionPreset = .high
        captureSession.addInput(input)
        
        if captureSession.canAddOutput(photoOutput) {
            captureSession.addOutput(photoOutput)
            let previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
            previewLayer.frame = CGRect(x: view.bounds.minX, y: view.bounds.minY, width: view.bounds.width, height: view.bounds.height)
            // `.resize` allows the camera to fill the screen on the iPhone X.
            previewLayer.videoGravity = .resize
            previewLayer.connection?.videoOrientation = .portrait
            cameraView.layer.addSublayer(previewLayer)
            return captureSession
        }
        return nil
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        captureSession?.startRunning()
    }
    
    // MARK: - Image Upload
    
    func classifyImage(_ image: UIImage) {
        let editedImage = cropToCenter(image: image, targetSize: CGSize(width: 224, height: 224))
        
        cloudVision.uploadImage(image: editedImage, bucketId: CloudVisionConstants.bucketId) { data, responce, error in

        }
    }
    
    func cropToCenter(image: UIImage, targetSize: CGSize) -> UIImage {
        let offset = abs((image.size.width - image.size.height) / 2)
        let posX = image.size.width > image.size.height ? offset : 0.0
        let posY = image.size.width < image.size.height ? offset : 0.0
        let newSize = CGFloat(min(image.size.width, image.size.height))
        
        print(posX)
        print(posY)
        
        // crop image to square
        let cropRect = CGRect(x: posY, y: posX, width: newSize, height: newSize)
        
        guard let cgImage = image.cgImage,
            let cropped = cgImage.cropping(to: cropRect) else {
                return image
        }
        
        let image2 = UIImage(cgImage: cropped, scale: image.scale, orientation: image.imageOrientation)
        
        let resizeRect = CGRect(x: 0, y: 0, width: targetSize.width, height: targetSize.height)
        
        UIGraphicsBeginImageContextWithOptions(targetSize, false, 1.0)
        image2.draw(in: resizeRect)
        let newImage = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        
        return newImage
    }
    
    // MARK: - IBActions
    
    @IBAction func capturePhoto() {
        photoOutput.capturePhoto(with: AVCapturePhotoSettings(), delegate: self)
    }
}

// MARK: - Error Handling

extension CameraViewController {
    func showAlert(_ alertTitle: String, alertMessage: String) {
        let alert = UIAlertController(title: alertTitle, message: alertMessage, preferredStyle: UIAlertControllerStyle.alert)
        alert.addAction(UIAlertAction(title: "Dismiss", style: UIAlertActionStyle.default, handler: nil))
        self.present(alert, animated: true, completion: nil)
    }
    
    func modelUpdateFail(bucketId: String, error: Error) {
        let error = error as NSError
        var errorMessage = ""
        
        // 0 = probably wrong api key
        // 404 = probably no model
        // -1009 = probably no internet
        
        switch error.code {
        case 0:
            errorMessage = "Please check your Object Storage API key in `Credentials.plist` and try again."
        case 404:
            errorMessage = "We couldn't find a bucket with ID: \"\(bucketId)\""
        case 500:
            errorMessage = "Internal server error. Please try again."
        case -1009:
            errorMessage = "Please check your internet connection."
        default:
            errorMessage = "Please try again."
        }
        
        // TODO: Do some more checks, does the model exist? is it still training? etc.
        // The service's response is pretty generic and just guesses.
        
        showAlert("Unable to download model", alertMessage: errorMessage)
    }
}

// MARK: - AVCapturePhotoCaptureDelegate

extension CameraViewController: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error = error {
            print(error.localizedDescription)
            return
        }
        guard let photoData = photo.fileDataRepresentation(),
            let image = UIImage(data: photoData) else {
            return
        }
        
        classifyImage(image)
    }
}



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
    @IBOutlet weak var thumbnail: UIView!
    @IBOutlet weak var thumbnailImage: UIImageView!
    @IBOutlet weak var queue: UILabel!
    @IBOutlet weak var width: NSLayoutConstraint!
    @IBOutlet weak var height: NSLayoutConstraint!

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
    
    var queueCount = 0
    
    override func viewDidLoad() {
        super.viewDidLoad()
        captureSession?.startRunning()
        thumbnailImage.layer.cornerRadius = 5.0
        queue.isHidden = true
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        // load the thumbnail of images.
        // This needs to happen in view did appear so it loads in the right spot.
        let border = UIView()
        let frame = CGRect(x: thumbnailImage.frame.origin.x - 1.0, y: thumbnailImage.frame.origin.y - 1.0, width: thumbnailImage.frame.size.height + 2.0, height: thumbnailImage.frame.size.height + 2.0)
        border.backgroundColor = UIColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 0.25)
        border.frame = frame
        border.layer.cornerRadius = 7.0
        view.insertSubview(border, belowSubview: thumbnailImage)
    }
    
    // MARK: - Image Upload
    
    func classifyImage(_ image: UIImage) {
        guard let editedImage = cropToCenter(image: image, targetSize: CGSize(width: 224, height: 224)) else {
            return
        }
        queueCount += 1
        queue.text = "\(queueCount)"
        queue.isHidden = false
        cloudVision.uploadImage(image: editedImage, bucketId: CloudVisionConstants.bucketId) { data, responce, error in
            DispatchQueue.main.async {
                self.queueCount -= 1
                self.queue.text = "\(self.queueCount)"
                if self.queueCount == 0 {
                    self.queue.isHidden = true
                    self.thumbnailImage.image = nil
                }
            }
        }
    }
    
    func cropToCenter(image: UIImage, targetSize: CGSize) -> UIImage? {
        guard let cgImage = image.cgImage else {
            return nil
        }
        
        let offset = abs((CGFloat(cgImage.width) - CGFloat(cgImage.height)) / 2)
        let newSize = CGFloat(min(cgImage.width, cgImage.height))
        
        let cropRect: CGRect
        if cgImage.width < cgImage.height {
            cropRect = CGRect(x: 0.0, y: offset, width: newSize, height: newSize)
        } else {
            cropRect = CGRect(x: offset, y: 0.0, width: newSize, height: newSize)
        }
        
        guard let cropped = cgImage.cropping(to: cropRect) else {
            return nil
        }
        
        let image = UIImage(cgImage: cropped, scale: image.scale, orientation: image.imageOrientation)
        let resizeRect = CGRect(x: 0, y: 0, width: targetSize.width, height: targetSize.height)
        
        UIGraphicsBeginImageContextWithOptions(targetSize, false, 1.0)
        image.draw(in: resizeRect)
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

    
    func photoOutput(_ captureOutput: AVCapturePhotoOutput, willCapturePhotoFor resolvedSettings: AVCaptureResolvedPhotoSettings) {
        DispatchQueue.main.async { [unowned self] in
            self.cameraView.layer.opacity = 0
            UIView.animate(withDuration: 0.25) { [unowned self] in
                self.cameraView.layer.opacity = 1
            }
        }
    }
    
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error = error {
            print(error.localizedDescription)
            return
        }
        guard let photoData = photo.fileDataRepresentation(),
            let image = UIImage(data: photoData) else {
            return
        }
        
        DispatchQueue.main.async { [unowned self] in
            self.width.constant = 5
            self.height.constant = 5
            self.thumbnailImage.image = image
            self.view.layoutIfNeeded()
            self.width.constant = 60
            self.height.constant = 60
            UIView.animate(withDuration: 0.3, delay: 0.0, options: [.curveEaseOut], animations: { () -> Void in
                self.thumbnailImage.alpha = 1.0
            }, completion: nil)
            UIView.animate(withDuration: 0.3, delay: 0.0, options: [.curveEaseOut], animations: { () -> Void in
                self.view.layoutIfNeeded()
            }, completion: nil)
        }
        
        classifyImage(image)
    }
}


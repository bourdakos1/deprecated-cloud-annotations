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
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var heatmapView: UIImageView!
    @IBOutlet weak var outlineView: UIImageView!
    @IBOutlet weak var focusView: UIImageView!
    @IBOutlet weak var simulatorTextView: UITextView!
    @IBOutlet weak var captureButton: UIButton!
    @IBOutlet weak var updateModelButton: UIButton!
    @IBOutlet weak var choosePhotoButton: UIButton!
    @IBOutlet weak var closeButton: UIButton!
    @IBOutlet weak var alphaSlider: UISlider!
    @IBOutlet weak var pickerView: AKPickerView!
    
    // MARK: - Variable Declarations
    
    let resourceId: String = {
        guard let path = Bundle.main.path(forResource: "Credentials", ofType: "plist") else {
            // Please create a Credentials.plist file with your Object Storage credentials.
            fatalError()
        }
        guard let resourceId = NSDictionary(contentsOfFile: path)?["resourceId"] as? String else {
            // No Object Storage Resource Instance ID found. Make sure you add your Resource Instance ID to the Credentials.plist file.
            fatalError()
        }
        return resourceId
    }()
    
    let cloudVision: CloudVision = {
        guard let path = Bundle.main.path(forResource: "Credentials", ofType: "plist") else {
            // Please create a Credentials.plist file with your Object Storage credentials.
            fatalError()
        }
        guard let apiKey = NSDictionary(contentsOfFile: path)?["apiKey"] as? String else {
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
    
    var editedImage = UIImage()
    var originalConfs = [VNClassificationObservation]()
    var heatmaps = [String: HeatmapImages]()
    var selectionIndex = 0
    var buckets = [String]()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        captureSession?.startRunning()
        resetUI()
        
        pickerView.delegate = self
        pickerView.dataSource = self
        pickerView.interitemSpacing = CGFloat(25.0)
        pickerView.pickerViewStyle = .flat
        pickerView.maskDisabled = true
        pickerView.font = UIFont.boldSystemFont(ofSize: 14)
        pickerView.highlightedFont = UIFont.boldSystemFont(ofSize: 14)
        pickerView.highlightedTextColor = UIColor.white
        pickerView.textColor = UIColor(red: 1, green: 1, blue: 1, alpha: 0.6)
        if let lastBucket = UserDefaults.standard.string(forKey: "bucket_id") {
            buckets.append(lastBucket)
        }
        pickerView.reloadData()
        
        var modelList = [String]()
        let dispatchGroup = DispatchGroup()
        dispatchGroup.enter()
        cloudVision.getBucketList(resourceId: resourceId) { buckets, error in
            defer { dispatchGroup.leave() }
            guard let buckets = buckets else {
                return
            }
            for bucket in buckets {
                dispatchGroup.enter()
                self.cloudVision.getLatestModelDate(bucketId: bucket, modelBranch: CloudVisionConstants.modelBranch) { date, error in
                    defer { dispatchGroup.leave() }
                    
                    guard let _ = date else {
                        return
                    }
                    modelList.append(bucket)
                }
            }
        }
        
        dispatchGroup.notify(queue: .main) {
            self.buckets = modelList
            self.pickerView.reloadData()
            self.pickerView.selectItem(self.selectionIndex)
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard let drawer = pulleyViewController?.drawerContentViewController as? ResultsTableViewController else {
            return
        }
        drawer.delegate = self
    }
    
    func checkUpdates(forBucket bucketId: String) {
        cloudVision.getLatestModelDate(bucketId: bucketId, modelBranch: CloudVisionConstants.modelBranch) { date, error in
            DispatchQueue.main.async {
                guard let cloudModelLastModified = date else {
                    self.modelUpdateFail(bucketId: bucketId, error: error ?? NSError())
                    return
                }
                let defaults = UserDefaults.standard
                
                // If local model data is matches the cloud date don't download the model.
                if let localModelLastModified = defaults.object(forKey: "lastModified") as? Date {
                    if localModelLastModified >= cloudModelLastModified {
                        return
                    }
                }
                
                // Download the cloud model.
                SwiftSpinner.show("Compiling model...")
                self.cloudVision.downloadModel(bucketId: bucketId, modelBranch: CloudVisionConstants.modelBranch) { _, error in
                    DispatchQueue.main.async {
                        if let error = error {
                            self.modelUpdateFail(bucketId: bucketId, error: error)
                        } else {
                            defaults.set(cloudModelLastModified, forKey: "lastModified")
                        }
                        SwiftSpinner.hide()
                    }
                }
            }
        }
    }
    
    // MARK: - Image Classification
    
    func classifyImage(_ image: UIImage, localThreshold: Double = 0.0) {
        guard let croppedImage = cropToCenter(image: image, targetSize: CGSize(width: 224, height: 224)) else {
            return
        }
        
        editedImage = croppedImage
        
        showResultsUI(for: image)
        
        guard let cgImage = editedImage.cgImage else {
            return
        }
        
        guard let bucketId = UserDefaults.standard.string(forKey: "bucket_id") else {
            return
        }
        
        CloudVision.classify(image: cgImage, bucketId: bucketId) { classifications, error in
            // Make sure that an image was successfully classified.
            guard let classifications = classifications else {
                return
            }
            
            DispatchQueue.main.async {
                self.push(results: classifications)
            }
            
            self.originalConfs = classifications
        }
    }
    
    func startAnalysis(classToAnalyze: String, localThreshold: Double = 0.0) {
        if let heatmapImages = heatmaps[classToAnalyze] {
            heatmapView.image = heatmapImages.heatmap
            outlineView.image = heatmapImages.outline
            return
        }
        
        var confidences = [[Double]](repeating: [Double](repeating: -1, count: 17), count: 17)
        
        DispatchQueue.main.async {
            SwiftSpinner.show("analyzing")
        }
        
        let chosenClasses = originalConfs.filter({ return $0.identifier == classToAnalyze })
        guard let chosenClass = chosenClasses.first else {
            return
        }
        let originalConf = Double(chosenClass.confidence)
        
        let dispatchGroup = DispatchGroup()
        dispatchGroup.enter()
        
        DispatchQueue.global(qos: .background).async {
            for down in 0 ..< 11 {
                for right in 0 ..< 11 {
                    confidences[down + 3][right + 3] = 0
                    dispatchGroup.enter()
                    let maskedImage = self.maskImage(image: self.editedImage, at: CGPoint(x: right, y: down))
                    guard let cgImage = maskedImage.cgImage else {
                        return
                    }
                    guard let bucketId = UserDefaults.standard.string(forKey: "bucket_id") else {
                        return
                    }
                    CloudVision.classify(image: cgImage, bucketId: bucketId) { [down, right] classifications, _ in
                        
                        defer { dispatchGroup.leave() }
                        
                        // Make sure that an image was successfully classified.
                        guard let classifications = classifications else {
                            return
                        }
                        
                        let usbClass = classifications.filter({ return $0.identifier == classToAnalyze })
                        
                        guard let usbClassSingle = usbClass.first else {
                                return
                        }
                        
                        let score = Double(usbClassSingle.confidence)
                        
                        print(".", terminator:"")
                        
                        confidences[down + 3][right + 3] = score
                    }
                }
            }
            dispatchGroup.leave()
            
            dispatchGroup.notify(queue: .main) {
                print()
                print(confidences)
                
                guard let image = self.imageView.image else {
                    return
                }
                
                let heatmap = self.calculateHeatmap(confidences, originalConf)
                let heatmapImage = self.renderHeatmap(heatmap, color: .black, size: image.size)
                let outlineImage = self.renderOutline(heatmap, size: image.size)
                
                let heatmapImages = HeatmapImages(heatmap: heatmapImage, outline: outlineImage)
                self.heatmaps[classToAnalyze] = heatmapImages
                
                self.heatmapView.image = heatmapImage
                self.outlineView.image = outlineImage
                self.heatmapView.alpha = CGFloat(self.alphaSlider.value)
                
                self.heatmapView.isHidden = false
                self.outlineView.isHidden = false
                self.alphaSlider.isHidden = false
                
                SwiftSpinner.hide()
            }
        }
    }
    
    func maskImage(image: UIImage, at point: CGPoint) -> UIImage {
        let size = image.size
        UIGraphicsBeginImageContextWithOptions(size, false, UIScreen.main.scale)
        
        image.draw(at: .zero)
        
        let rectangle = CGRect(x: point.x * 16, y: point.y * 16, width: 64, height: 64)
        
        UIColor(red: 1, green: 0, blue: 1, alpha: 1).setFill()
        UIRectFill(rectangle)
        
        let newImage = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        return newImage
    }
    
    func cropToCenter(image: UIImage, targetSize: CGSize) -> UIImage? {
        guard let cgImage = image.cgImage else {
            return nil
        }
        
        let offset = abs(CGFloat(cgImage.width - cgImage.height) / 2)
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
    
    func dismissResults() {
        push(results: [], position: .closed)
    }
    
    func push(results: [VNClassificationObservation], position: PulleyPosition = .partiallyRevealed) {
        guard let drawer = pulleyViewController?.drawerContentViewController as? ResultsTableViewController else {
            return
        }
        drawer.classifications = results
        pulleyViewController?.setDrawerPosition(position: position, animated: true)
        drawer.tableView.reloadData()
    }
    
    func showResultsUI(for image: UIImage) {
        imageView.image = image
        imageView.isHidden = false
        simulatorTextView.isHidden = true
        closeButton.isHidden = false
        captureButton.isHidden = true
        choosePhotoButton.isHidden = true
        updateModelButton.isHidden = true
        focusView.isHidden = true
    }
    
    func resetUI() {
        heatmaps = [String: HeatmapImages]()
        if captureSession != nil {
            simulatorTextView.isHidden = true
            imageView.isHidden = true
            captureButton.isHidden = false
            focusView.isHidden = false
        } else {
            imageView.image = UIImage(named: "Background")
            simulatorTextView.isHidden = false
            imageView.isHidden = false
            captureButton.isHidden = true
            focusView.isHidden = true
        }
        heatmapView.isHidden = true
        outlineView.isHidden = true
        alphaSlider.isHidden = true
        closeButton.isHidden = true
        choosePhotoButton.isHidden = false
        updateModelButton.isHidden = false
        dismissResults()
    }
    
    // MARK: - IBActions
    
    @IBAction func sliderValueChanged(_ sender: UISlider) {
        let currentValue = CGFloat(sender.value)
        self.heatmapView.alpha = currentValue
    }
    
    @IBAction func capturePhoto() {
        photoOutput.capturePhoto(with: AVCapturePhotoSettings(), delegate: self)
    }
    
    @IBAction func presentPhotoPicker() {
        let picker = UIImagePickerController()
        picker.delegate = self
        picker.sourceType = .photoLibrary
        present(picker, animated: true)
    }
    
    @IBAction func reset() {
        resetUI()
    }
    
    // MARK: - Structs
    
    struct HeatmapImages {
        let heatmap: UIImage
        let outline: UIImage
    }
}

// MARK: - Error Handling

extension CameraViewController {
    func showAlert(_ alertTitle: String, alertMessage: String) {
        let alert = UIAlertController(title: alertTitle, message: alertMessage, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Dismiss", style: .default, handler: nil))
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

// MARK: - UIImagePickerControllerDelegate

extension CameraViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        picker.dismiss(animated: true)
        
        guard let image = info[.originalImage] as? UIImage else {
            return
        }
        
        classifyImage(image)
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

// MARK: - TableViewControllerSelectionDelegate

extension CameraViewController: TableViewControllerSelectionDelegate {
    func didSelectItem(_ name: String) {
        startAnalysis(classToAnalyze: name)
    }
}

// MARK: - AKPickerViewDataSource

extension CameraViewController: AKPickerViewDataSource {
    func numberOfItemsInPickerView(_ pickerView: AKPickerView) -> Int {
        return max(buckets.count, 1)
    }
    
    func pickerView(_ pickerView: AKPickerView, titleForItem item: Int) -> String {
        if buckets.count <= 0 {
            return "Loading..."
        }
        
        // Find the selection index of our default.
        if buckets[item] == UserDefaults.standard.string(forKey: "bucket_id") {
            selectionIndex = item
        }
        
        return buckets[item]
    }
}

// MARK: - AKPickerViewDelegate

extension CameraViewController: AKPickerViewDelegate {
    func pickerView(_ pickerView: AKPickerView, didSelectItem item: Int) {
        if buckets.count > 0 {
            print("setting bucket \(buckets[item])")
            UserDefaults.standard.set(buckets[item], forKey: "bucket_id")
            checkUpdates(forBucket: buckets[item])
        }
    }
}

//
//  CloudVision.swift
//  Core ML Vision
//
//  Created by Nicholas Bourdakos on 10/16/18.
//

import UIKit
import CoreML
import Vision

class CloudVision {
    let endpoint: String
    let apiKey: String
    
    init(endpoint: String, apiKey: String) {
        self.endpoint = endpoint
        self.apiKey = apiKey
    }
    
    func uploadImage(image: UIImage, bucketId: String, completion: @escaping (Data?, URLResponse?, Error?) -> Void) {
        let fileName = "\(UUID().uuidString.lowercased()).jpg"
        
        guard let data = image.jpegData(compressionQuality: 1) else {
            let description = "Bad image"
            let userInfo = [NSLocalizedDescriptionKey: description]
            let error = NSError(domain: Bundle.main.bundleIdentifier ?? "", code: 0, userInfo: userInfo)
            completion(nil, nil, error)
            return
        }
        
        guard let url = URL(string: "https://\(self.endpoint)/\(bucketId)/\(fileName)") else {
            let description = "Bad url"
            let userInfo = [NSLocalizedDescriptionKey: description]
            let error = NSError(domain: Bundle.main.bundleIdentifier ?? "", code: 0, userInfo: userInfo)
            completion(nil, nil, error)
            return
        }
        
        getToken() { token, error in
            guard let token = token else {
                let description = "Failed to authenticate"
                let userInfo = [NSLocalizedDescriptionKey: description]
                let error = NSError(domain: Bundle.main.bundleIdentifier ?? "", code: 0, userInfo: userInfo)
                completion(nil, nil, error)
                return
            }
            
            let sessionConfig = URLSessionConfiguration.default
            let session = URLSession(configuration: sessionConfig)
            var request = URLRequest(url: url)
        
            request.httpMethod = "PUT"
            request.setValue("bearer \(token)", forHTTPHeaderField: "Authorization")
        
            request.setValue(String(data.count), forHTTPHeaderField: "Content-Length")
        
            request.httpBody = data
        
            let task = session.dataTask(with: request, completionHandler: completion)
            task.resume()
        }
    }
    
    class func classify(image: CGImage, bucketId: String, completion: @escaping ([VNClassificationObservation]?, Error?) -> Void) {
        // run classification request in background to avoid blocking
        DispatchQueue.global(qos: .userInitiated).async {
            // get classifier model
            let model: MLModel
            do {
                model = try loadModelFromDisk(bucketId: bucketId)
            } catch {
                let description = "Failed to load model for model \(bucketId): \(error.localizedDescription)"
                let userInfo = [NSLocalizedDescriptionKey: description]
                let error = NSError(domain: Bundle.main.bundleIdentifier ?? "", code: 0, userInfo: userInfo)
                completion(nil, error)
                return
            }
            
            // convert MLModel to VNCoreMLModel
            let classifier: VNCoreMLModel
            do {
                classifier = try VNCoreMLModel(for: model)
            } catch {
                let description = "Failed to convert model for model \(bucketId): \(error.localizedDescription)"
                let userInfo = [NSLocalizedDescriptionKey: description]
                let error = NSError(domain: Bundle.main.bundleIdentifier ?? "", code: 0, userInfo: userInfo)
                completion(nil, error)
                return
            }
            
            // construct classification request
            let request = VNCoreMLRequest(model: classifier) { request, error in
                guard error == nil else {
                    let description = "Model \(bucketId) failed with error: \(error!)"
                    let userInfo = [NSLocalizedDescriptionKey: description]
                    let error = NSError(domain: Bundle.main.bundleIdentifier ?? "", code: 0, userInfo: userInfo)
                    completion(nil, error)
                    return
                }
                guard let observations = request.results as? [VNClassificationObservation] else {
                    let description = "Failed to parse results for model \(bucketId)"
                    let userInfo = [NSLocalizedDescriptionKey: description]
                    let error = NSError(domain: Bundle.main.bundleIdentifier ?? "", code: 0, userInfo: userInfo)
                    completion(nil, error)
                    return
                }
                completion(observations, nil)
            }
            
            // scale image (yields results in line with vision demo)
            request.imageCropAndScaleOption = .scaleFill
            
            // execute classification request
            do {
                let requestHandler = VNImageRequestHandler(cgImage: image)
                try requestHandler.perform([request])
            } catch {
                let description = "Failed to process classification request: \(error.localizedDescription)"
                let userInfo = [NSLocalizedDescriptionKey: description]
                let error = NSError(domain: Bundle.main.bundleIdentifier ?? "", code: 0, userInfo: userInfo)
                completion(nil, error)
                return
            }
        }
    }

    /**
     Load a Core ML model from disk. The model must be named "[classifier-id].mlmodelc" and reside in the
     application support directory or main bundle.
     */
    private class func loadModelFromDisk(bucketId: String) throws -> MLModel {
        let modelURL = try locateModelOnDisk(bucketId: bucketId)
        return try MLModel(contentsOf: modelURL)
    }
    
    /**
     Locate a Core ML model on disk. The model must be named "[classifier-id].mlmodelc" and reside in the
     application support directory or main bundle.
     */
    private class func locateModelOnDisk(bucketId: String) throws -> URL {
        
        // search for model in application support directory
        let fileManager = FileManager.default
        if let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            let modelURL = appSupport.appendingPathComponent(bucketId + ".mlmodelc", isDirectory: false)
            if fileManager.fileExists(atPath: modelURL.path) {
                return modelURL
            }
        }
        
        // search for model in main bundle
        if let modelURL = Bundle.main.url(forResource: bucketId, withExtension: ".mlmodelc") {
            return modelURL
        }
        
        // model not found -> throw an error
        let description = "Failed to locate a Core ML model on disk for classifier \(bucketId)."
        let userInfo = [NSLocalizedDescriptionKey: description]
        let error = NSError(domain: Bundle.main.bundleIdentifier ?? "", code: 0, userInfo: userInfo)
        throw error
    }
    
    private func download(url: URL, to destination: URL, token: String, completion: @escaping (HTTPURLResponse?, Error?) -> Void) {
        let sessionConfig = URLSessionConfiguration.default
        let session = URLSession(configuration: sessionConfig)
        var request = URLRequest(url: url)
        request.setValue("bearer \(token)", forHTTPHeaderField: "Authorization")

        // create a task to execute the request
        let task = session.downloadTask(with: request) { (location, response, error) in
            // ensure there is no underlying error
            guard error == nil else {
                let description = "Initial download error"
                let userInfo = [NSLocalizedDescriptionKey: description]
                let error = NSError(domain: Bundle.main.bundleIdentifier ?? "", code: 0, userInfo: userInfo)
                completion(nil, error)
                return
            }
            
            // ensure there is a valid http response
            guard let response = response as? HTTPURLResponse else {
                let description = "No response"
                let userInfo = [NSLocalizedDescriptionKey: description]
                let error = NSError(domain: Bundle.main.bundleIdentifier ?? "", code: 0, userInfo: userInfo)
                completion(nil, error)
                return
            }
            
            // ensure the response body was saved to a temporary location
            guard let location = location else {
                let description = "Invalid file"
                let userInfo = [NSLocalizedDescriptionKey: description]
                let error = NSError(domain: Bundle.main.bundleIdentifier ?? "", code: 0, userInfo: userInfo)
                completion(nil, error)
                return
            }
            
            // move the temporary file to the specified destination
            do {
                try FileManager.default.moveItem(at: location, to: destination)
                completion(response, nil)
            } catch {
                let description = "Failed to move"
                let userInfo = [NSLocalizedDescriptionKey: description]
                let error = NSError(domain: Bundle.main.bundleIdentifier ?? "", code: 0, userInfo: userInfo)
                completion(nil, error)
            }
        }
        
        // start the download task
        task.resume()
    }
    
    private func getToken(completion: @escaping (String?, Error?) -> Void) {
        guard let authUrl = URL(string: "https://iam.ng.bluemix.net/oidc/token?apikey=\(self.apiKey)&response_type=cloud_iam&grant_type=urn:ibm:params:oauth:grant-type:apikey") else {
                let description = "Bad url"
                let userInfo = [NSLocalizedDescriptionKey: description]
                let error = NSError(domain: Bundle.main.bundleIdentifier ?? "", code: 0, userInfo: userInfo)
                completion(nil, error)
                return
        }
        
        let sessionConfig = URLSessionConfiguration.default
        let session = URLSession(configuration: sessionConfig)
        var request = URLRequest(url: authUrl)
        request.httpMethod = "POST"
        
        let task = session.dataTask(with: request) { (data, response, error) in
            guard let data = data else {
                let description = "Couldn't authenticate"
                let userInfo = [NSLocalizedDescriptionKey: description]
                let error = NSError(domain: Bundle.main.bundleIdentifier ?? "", code: 0, userInfo: userInfo)
                completion(nil, error)
                return
            }
            
            let json: Any
            do {
                json = try JSONSerialization.jsonObject(with: data, options: [])
            } catch {
                let description = "Unable to parse json"
                let userInfo = [NSLocalizedDescriptionKey: description]
                let error = NSError(domain: Bundle.main.bundleIdentifier ?? "", code: 0, userInfo: userInfo)
                completion(nil, error)
                return
            }
            
            guard let parsedJson = json as? [String: Any] else {
                let description = "Unable to parse json"
                let userInfo = [NSLocalizedDescriptionKey: description]
                let error = NSError(domain: Bundle.main.bundleIdentifier ?? "", code: 0, userInfo: userInfo)
                completion(nil, error)
                return
            }
            
            guard let token = parsedJson["access_token"] as? String else {
                let description = "Unable to parse json"
                let userInfo = [NSLocalizedDescriptionKey: description]
                let error = NSError(domain: Bundle.main.bundleIdentifier ?? "", code: 0, userInfo: userInfo)
                completion(nil, error)
                return
            }
            
            completion(token, nil)
        }
        task.resume()
    }
    
    public func getLatestModelDate(bucketId: String, modelBranch: String = "master", completion: ((Date?, Error?) -> Void)? = nil) {
        let branch = modelBranch == "master" ? "" : "-\(modelBranch)"
        
        guard let url = URL(string: "https://\(self.endpoint)/\(bucketId)/\(bucketId)\(branch).mlmodel") else {
            let description = "Bad url"
            let userInfo = [NSLocalizedDescriptionKey: description]
            let error = NSError(domain: Bundle.main.bundleIdentifier ?? "", code: 0, userInfo: userInfo)
            completion?(nil, error)
            return
        }
        
        getToken() { token, error in
            guard let token = token else {
                let description = "Failed to authenticate"
                let userInfo = [NSLocalizedDescriptionKey: description]
                let error = NSError(domain: Bundle.main.bundleIdentifier ?? "", code: 0, userInfo: userInfo)
                completion?(nil, error)
                return
            }
            
            let sessionConfig = URLSessionConfiguration.default
            let session = URLSession(configuration: sessionConfig)
            var request = URLRequest(url: url)
            request.setValue("bearer \(token)", forHTTPHeaderField: "Authorization")
            request.httpMethod = "HEAD"
            
            let task = session.dataTask(with: request) { (data, response, error) in
                guard let httpResponse = response as? HTTPURLResponse else {
                    let description = "Couldn't fetch date"
                    let userInfo = [NSLocalizedDescriptionKey: description]
                    let error = NSError(domain: Bundle.main.bundleIdentifier ?? "", code: 0, userInfo: userInfo)
                    completion?(nil, error)
                    return
                }
                guard let modified = httpResponse.allHeaderFields["Last-Modified"] as? String else {
                    let description = "Couldn't fetch date"
                    let userInfo = [NSLocalizedDescriptionKey: description]
                    let error = NSError(domain: Bundle.main.bundleIdentifier ?? "", code: 0, userInfo: userInfo)
                    completion?(nil, error)
                    return
                }
                
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "EEEE, dd LLL yyyy HH:mm:ss zzz"
                let dateModified = dateFormatter.date(from: modified)
                
                completion?(dateModified, nil)
            }
            task.resume()
        }
    }
    
    public func getBucketList(resourceId: String, completion: (([String]?, Error?) -> Void)? = nil) {
        guard let url = URL(string: "https://\(self.endpoint)/") else {
            let description = "Bad url"
            let userInfo = [NSLocalizedDescriptionKey: description]
            let error = NSError(domain: Bundle.main.bundleIdentifier ?? "", code: 0, userInfo: userInfo)
            completion?(nil, error)
            return
        }
        
        getToken() { token, error in
            guard let token = token else {
                let description = "Failed to authenticate"
                let userInfo = [NSLocalizedDescriptionKey: description]
                let error = NSError(domain: Bundle.main.bundleIdentifier ?? "", code: 0, userInfo: userInfo)
                completion?(nil, error)
                return
            }
            
            let sessionConfig = URLSessionConfiguration.default
            let session = URLSession(configuration: sessionConfig)
            var request = URLRequest(url: url)
            request.setValue("bearer \(token)", forHTTPHeaderField: "Authorization")
            request.setValue(resourceId, forHTTPHeaderField: "ibm-service-instance-id")
            request.httpMethod = "GET"
            
            let task = session.dataTask(with: request) { (data, response, error) in
                guard let data = data else {
                    let description = "Failed get bucket"
                    let userInfo = [NSLocalizedDescriptionKey: description]
                    let error = NSError(domain: Bundle.main.bundleIdentifier ?? "", code: 0, userInfo: userInfo)
                    completion?(nil, error)
                    return
                }
                
                let parser = BucketListParser(data: data)
                parser.parse() { buckets in
                    completion?(buckets, nil)
                    return
                }
            }
            task.resume()
        }
    }
    
    /**
     Download a Core ML model to the local filesystem. The model is compiled and moved to the application support
     directory with a filename of `[classifier-id].mlmodelc`.
     - parameter classifierID: The classifierID of the model to download.
     - parameter failure: A function executed if an error occurs.
     - parameter success: A function executed after the Core ML model has been downloaded and compiled.
     */
    public func downloadModel(bucketId: String, modelBranch: String = "master", completion: ((Void?, Error?) -> Void)? = nil) {
        let branch = modelBranch == "master" ? "" : "-\(modelBranch)"
        
        guard let url = URL(string: "https://\(self.endpoint)/\(bucketId)/\(bucketId)\(branch).mlmodel") else {
            let description = "Bad url"
            let userInfo = [NSLocalizedDescriptionKey: description]
            let error = NSError(domain: Bundle.main.bundleIdentifier ?? "", code: 0, userInfo: userInfo)
            completion?(nil, error)
            return
        }
    
        getToken() { token, error in
            guard let token = token else {
                let description = "Failed to authenticate"
                let userInfo = [NSLocalizedDescriptionKey: description]
                let error = NSError(domain: Bundle.main.bundleIdentifier ?? "", code: 0, userInfo: userInfo)
                completion?(nil, error)
                return
            }
            
            // create temporary downloads directory
            let fileManager = FileManager.default
            let downloads: URL
            do {
                downloads = try fileManager.url(
                    for: .itemReplacementDirectory,
                    in: .userDomainMask,
                    appropriateFor: FileManager.default.temporaryDirectory,
                    create: true
                )
            } catch {
                let description = "Failed to create temporary downloads directory: \(error.localizedDescription)"
                let userInfo = [NSLocalizedDescriptionKey: description]
                let error = NSError(domain: Bundle.main.bundleIdentifier ?? "", code: 0, userInfo: userInfo)
                completion?(nil, error)
                return
            }
            
            // locate application support directory
            let appSupport: URL
            do {
                appSupport = try fileManager.url(
                    for: .applicationSupportDirectory,
                    in: .userDomainMask,
                    appropriateFor: nil,
                    create: true
                )
            } catch {
                let description = "Failed to locate application support directory: \(error.localizedDescription)"
                let userInfo = [NSLocalizedDescriptionKey: description]
                let error = NSError(domain: Bundle.main.bundleIdentifier ?? "", code: 0, userInfo: userInfo)
                completion?(nil, error)
                return
            }
            
            // specify file destinations
            let sourceModelURL = downloads.appendingPathComponent(bucketId + ".mlmodel", isDirectory: false)
            var compiledModelURL = appSupport.appendingPathComponent(bucketId + ".mlmodelc", isDirectory: false)
            
            // execute REST request
            self.download(url: url, to: sourceModelURL, token: token) { response, error in
                defer { try? fileManager.removeItem(at: sourceModelURL) }
                
                guard error == nil else {
                    completion?(nil, error!)
                    return
                }
                
                guard let statusCode = response?.statusCode else {
                    let description = "Did not receive response."
                    let userInfo = [NSLocalizedDescriptionKey: description]
                    let error = NSError(domain: Bundle.main.bundleIdentifier ?? "", code: 0, userInfo: userInfo)
                    completion?(nil, error)
                    return
                }
                
                guard (200..<300).contains(statusCode) else {
                    let description = "Status code was not acceptable: \(statusCode)."
                    let userInfo = [NSLocalizedDescriptionKey: description]
                    let error = NSError(domain: Bundle.main.bundleIdentifier ?? "", code: statusCode, userInfo: userInfo)
                    completion?(nil, error)
                    return
                }
                
                // compile model from source
                var compiledModelTemporaryURL: URL
                do {
                    compiledModelTemporaryURL = try MLModel.compileModel(at: sourceModelURL)
                } catch {
                    let description = "Could not compile Core ML model from source: \(error.localizedDescription)"
                    let userInfo = [NSLocalizedDescriptionKey: description]
                    let error = NSError(domain: Bundle.main.bundleIdentifier ?? "", code: 0, userInfo: userInfo)
                    completion?(nil, error)
                    return
                }
                defer { try? fileManager.removeItem(at: compiledModelTemporaryURL) }
                
                // move compiled model
                do {
                    if fileManager.fileExists(atPath: compiledModelURL.path) {
                        _ = try fileManager.replaceItemAt(compiledModelURL, withItemAt: compiledModelTemporaryURL)
                    } else {
                        try fileManager.copyItem(at: compiledModelTemporaryURL, to: compiledModelURL)
                    }
                } catch {
                    let description = "Failed to move compiled model: \(error.localizedDescription)"
                    let userInfo = [NSLocalizedDescriptionKey: description]
                    let error = NSError(domain: Bundle.main.bundleIdentifier ?? "", code: 0, userInfo: userInfo)
                    completion?(nil, error)
                    return
                }
                
                // exclude compiled model from device backups
                var urlResourceValues = URLResourceValues()
                urlResourceValues.isExcludedFromBackup = true
                do {
                    try compiledModelURL.setResourceValues(urlResourceValues)
                } catch {
                    let description = "Could not exclude compiled model from backup: \(error.localizedDescription)"
                    let userInfo = [NSLocalizedDescriptionKey: description]
                    let error = NSError(domain: Bundle.main.bundleIdentifier ?? "", code: 0, userInfo: userInfo)
                    completion?(nil, error)
                }
                
                completion?(nil, nil)
            }
        }
    }
}

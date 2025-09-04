//
//  AKUploader.swift
//  AppKeyIDSwift
//
//  Created by Tola Voeung on 4/9/25.
//

import Foundation
import SwiftUI
import PhotosUI


public enum ImageUploadState {
    // The upload session is starting. Called once.
    
    // An asset is about to be uploaded. Called for each asset.
    case assetStart(Int /* task id */)
    // Reports the progress in bytes of the image upload. Called multiple
    // times for each asset.
    case assetPogress(Int /* task id */,Int64 /* bytes uploaded */, Int64 /* total bytes */, Double /* total progress */)
   
    case assetUploadError(Int /* task id */, Error)
    
    case assetUploadDescription(String /* task description */)
    // The asset has been uploaded and saved
    case assetMainUploadEnd(Int, AKUploadUrl?/* AKUploadUrl */)
    
    // The upload session has been completed
    // Parameters are the array of uploaded assets and an
    // array of failed uploads.
    case transactionEnd(AKUploadUrl)
}

@MainActor public class UploadDelegate: NSObject, @preconcurrency URLSessionTaskDelegate {
    public typealias ProgressHandler = (ImageUploadState) -> Void
    var progressHandlersByTaskID = [Int: ProgressHandler]()
    var uploadUrl:AKUploadUrl? = nil
    
    public func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didSendBodyData bytesSent: Int64,
        totalBytesSent: Int64,
        totalBytesExpectedToSend: Int64
    ) {
        // Calculate and report the progress
        guard totalBytesExpectedToSend > 0 else { return }
        let progress = Double(totalBytesSent) / Double(totalBytesExpectedToSend)
        progressHandlersByTaskID[task.taskIdentifier]?(.assetPogress(task.taskIdentifier, totalBytesSent, totalBytesExpectedToSend, progress))
    }
    
    // An optional method to handle task completion (success or failure)
    public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: (any Error)?) {
        // Handle completion or error
        if let error = error {
            print("Upload failed with error: \(error.localizedDescription)")
            
            progressHandlersByTaskID[task.taskIdentifier]?(.assetUploadError(task.taskIdentifier, error))
            
        } else {
            print("Upload completed successfully!")
            
            progressHandlersByTaskID[task.taskIdentifier]?(.assetMainUploadEnd(task.taskIdentifier, uploadUrl))
        }
        
       
       
        
    }
}

@available(iOS 16.0, *)
@MainActor public class FileUploader:NSObject, URLSessionTaskDelegate {
    
    public override init() {
            // Initialization code
    }
    
    // Create a custom URLSession with our delegate
    lazy var session: URLSession = {
        return URLSession(configuration: .default, delegate: self.delegate, delegateQueue: .main)
    }()

    // The delegate instance that will handle progress
    private let delegate = UploadDelegate()

    
    public func uploadFileToAzure(upload:AKUploadItem, notCutting:Bool = false, progressHandler: @escaping UploadDelegate.ProgressHandler) async throws -> Int{
        
        guard let url = URL(string: upload.src) else {
            throw UploadError.invalidImage
        }
        
        guard let uiImage = upload.uiImage else {
            throw UploadError.invalidImage
        }
        
      
        var imageData: Data?
        
        if upload.contentType == "image/jpeg" {
            imageData = uiImage.jpegData(compressionQuality: 1.0)
        }
        else if upload.contentType == "image/png" {
            imageData = uiImage.pngData()
        }
        else{
            imageData = uiImage.jpegData(compressionQuality: 1.0)
        }
        
        let imageDetail = try await getImageDetail(url: url)!
        let uploadURL = try await AppKeyIDAPI.getUploadURL(id: upload.id, fileName: imageDetail.fileName, noCutting: notCutting)
        
        let taskId = try await uploadImageData(imageData!, contentType: upload.contentType, to: uploadURL.writeUrl, progressHandler: progressHandler)
        delegate.uploadUrl = uploadURL
        
        if notCutting {
            delegate.progressHandlersByTaskID[taskId]?(.transactionEnd(uploadURL))
        }
        return taskId
         
    }
    
    func getImageDetail(url:URL) async throws -> AKImageDetail? {
        var detail:AKImageDetail?
        
        let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [url.absoluteString], options: nil)
        fetchResult.enumerateObjects { object, index, stop in
            let phAsset = object as PHAsset
            let resources = PHAssetResource.assetResources(for: phAsset)
            if let file = resources.first {
                let options = PHContentEditingInputRequestOptions()
                options.isNetworkAccessAllowed = true
                
                let fileName = file.originalFilename.filter({$0 != " "})
                detail = AKImageDetail(fileName: fileName, localIdentifier: phAsset.localIdentifier, pixelWidth: phAsset.pixelWidth, pixelHeight: phAsset.pixelHeight, contentType: fileName.mimeType())
            }
        }
        
        return detail
    }
    
    public func uploadImageData(_ imageData: Data, contentType:String, to writeUrl: String,  progressHandler: @escaping UploadDelegate.ProgressHandler) async throws -> Int {
      
      
        let fileSize = imageData.count
        var request = URLRequest(url: URL(string: writeUrl)!)
        request.httpMethod = "PUT"

        // Required headers
        request.setValue("BlockBlob", forHTTPHeaderField: "x-ms-blob-type")
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        request.setValue(String(fileSize), forHTTPHeaderField: "Content-Length")
        request.setValue("2023-11-03", forHTTPHeaderField: "x-ms-version") // Example API version
        request.setValue(Date().description(with: .current), forHTTPHeaderField: "x-ms-date") // Current UTC date
           
        
        let task = session.uploadTask(with: request, from: imageData)
        
        // Store the progress handler using the task's identifier
        delegate.progressHandlersByTaskID[task.taskIdentifier] = progressHandler
        
        delegate.progressHandlersByTaskID[task.taskIdentifier]?(.assetStart(task.taskIdentifier))
        
        // Start the upload
        task.resume()
        
        return task.taskIdentifier
         
        
  }
    
    
     func uploadImageDataAsync(_ imageData: Data,  contentType:String, to writeUrl: String ) async throws {
      
      
        let fileSize = imageData.count
        var request = URLRequest(url: URL(string: writeUrl)!)
        request.httpMethod = "PUT"

        // Required headers
        request.setValue("BlockBlob", forHTTPHeaderField: "x-ms-blob-type")
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        request.setValue(String(fileSize), forHTTPHeaderField: "Content-Length")
        request.setValue("2023-11-03", forHTTPHeaderField: "x-ms-version") // Example API version
        request.setValue(Date().description(with: .current), forHTTPHeaderField: "x-ms-date") // Current UTC date
        
        let (_, response) = try await URLSession.shared.upload(for: request, from: imageData, delegate: self)
        guard let taskResponse = response as? HTTPURLResponse else {
            print("uploadImageData no response")
            throw UploadError.uploadFail
        }
       
     }
    
    public func uploadThumbnail(taskId:Int, upload:AKUploadItem, uploadURL:AKUploadUrl) async{
        do {
            if let writeUrlSmall = uploadURL.writeUrlSmall{
                if let small = upload.uiImage?.imageCut(cutSize: 300)?.pngData(){
                    
                    delegate.progressHandlersByTaskID[taskId]?(.assetUploadDescription("uploading small image"))
                    
                    let _ = try await uploadImageDataAsync(small, contentType: upload.contentType, to: writeUrlSmall)
                }
            }
            
            if let writeUrlMedium = uploadURL.writeUrlMedium{
                if let medium = upload.uiImage?.imageCut(cutSize: 600)?.pngData() {
                    
                    delegate.progressHandlersByTaskID[taskId]?(.assetUploadDescription("uploading medium image"))
                    
                    let _ = try await uploadImageDataAsync(medium, contentType: upload.contentType, to: writeUrlMedium)
                }
            }
            
            if let writeUrlLarge = uploadURL.writeUrlLarge{
                if let large = upload.uiImage?.imageCut(cutSize: 900)?.pngData(){
                    delegate.progressHandlersByTaskID[taskId]?(.assetUploadDescription("uploading large image"))
                    let _ = try await uploadImageDataAsync(large, contentType: upload.contentType, to: writeUrlLarge)
                    
                    delegate.progressHandlersByTaskID[taskId]?(.transactionEnd(uploadURL))
                    
                }
            }
        }
        catch{
            
        }
    }
    
    public func clear(taskId:Int){
        delegate.progressHandlersByTaskID[taskId] = nil
    }
    
}




enum ImageUploadError: Error {
   case invalidImage
   case uploadFail
   
   public var message: String {
       switch self {
       case .invalidImage:
           return "Your image is invalid"
       case .uploadFail:
           return "Whoop! Something went wrong while uploading to server"
           
       }
   
   }
}

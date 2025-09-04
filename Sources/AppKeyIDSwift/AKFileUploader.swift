//
//  AKFileUploader.swift
//  AppKeyIDSwift
//
//  Created by Tola Voeung on 1/9/25.
// https://www.swiftbysundell.com/articles/http-post-and-file-upload-requests-using-urlsession/
import Foundation
import SwiftUI
import PhotosUI
 
 public enum AKUploadState {
     // The upload session is starting. Called once.
     case transactionStart
     // An asset is about to be uploaded. Called for each asset.
     case assetStart(Int /* asset index */ , Int /* total uploads */, AKUploadItem)
     // Reports the progress in bytes of the image upload. Called multiple
     // times for each asset.
     case assetPogress(Int64 /* bytes uploaded */, Int64 /* total bytes */, AKUploadItem)
     // Unable to initialize asset. Nothing has been uploaded.
     case assetInitError(Error, AKUploadItem)
     // Unable to upload asset or save it
     case assetUploadError(Error, AKUploadItem)
     // The asset has been uploaded and saved
     case assetUploadEnd(AKUploadItem)
     // The upload session has been completed
     // Parameters are the array of uploaded assets and an
     // array of failed uploads.
     case transactionEnd(AKUploadUrl)
 }
  

@available(iOS 16.0, *)
@MainActor public class AKFileUploader:NSObject, @preconcurrency URLSessionTaskDelegate {
    
    typealias ProgressHandler = (Double) -> Void
    var progressHandlersByTaskID = [Int: ProgressHandler]()
    
    public static let shared = AKFileUploader()
    public var progress: Double? = 0
    
    func getImageDetail(url:URL) async throws -> AKImageDetail? {
        var detail:AKImageDetail?
        
        let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [url.absoluteString], options: nil)
        fetchResult.enumerateObjects { object, index, stop in
            let phAsset = object as PHAsset
            let resources = PHAssetResource.assetResources(for: phAsset)
            if let file = resources.first {
                let options = PHContentEditingInputRequestOptions()
                options.isNetworkAccessAllowed = true
//                let imageManager = PHImageManager.default()
//                let phOptions = PHImageRequestOptions()
//                phOptions.resizeMode = PHImageRequestOptionsResizeMode.exact
//                phOptions.isSynchronous = true;
                
                let fileName = file.originalFilename.filter({$0 != " "})
                detail = AKImageDetail(fileName: fileName, localIdentifier: phAsset.localIdentifier, pixelWidth: phAsset.pixelWidth, pixelHeight: phAsset.pixelHeight, contentType: fileName.mimeType())
            }
        }
        
        return detail
    }
    
    public func getFileUploadDetail(upload:AKUploadItem, notCutting:Bool = false ) async throws -> AKUploadUrl {
        do{
            guard let url = URL(string: upload.src) else {
                throw UploadError.invalidImage
            }
            
            guard let uiImage = upload.uiImage else {
                throw UploadError.invalidImage
            }
           
            let imageDetail = try await getImageDetail(url: url)!
            let uploadURL = try await AppKeyIDAPI.getUploadURL(id: upload.id, fileName: imageDetail.fileName, noCutting: notCutting)
            return uploadURL
        }
        catch{
            throw UploadError.invalidImage
        }
        
    }
    
   
    
    public typealias AKUploadCallback = (_ state: AKUploadState) -> Void
    
    public func uploadFileToAzure(upload:AKUploadItem, notCutting:Bool = false, onUpload: @escaping AKUploadCallback) async throws {
      do {
          
          guard let url = URL(string: upload.src) else {
              throw UploadError.invalidImage
          }
          
          guard let uiImage = upload.uiImage else {
              throw UploadError.invalidImage
          }
          
        
          var imageData: Data?
          let callback = onUpload
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
          
          if let data = imageData  {
              
              onUpload(.transactionStart)
              
              try await uploadImageData(data, contentType: upload.contentType, to: uploadURL.writeUrl)
              
              if notCutting {
                  
                  onUpload(.transactionEnd(uploadURL))
                  return
              }
              
              
              if let writeUrlSmall = uploadURL.writeUrlSmall{
                  if let small = upload.uiImage?.imageCut(cutSize: 300)?.pngData(){
                      try await uploadImageData(small, contentType: upload.contentType, to: writeUrlSmall)
                  }
              }
              
              if let writeUrlMedium = uploadURL.writeUrlMedium{
                  if let medium = upload.uiImage?.imageCut(cutSize: 600)?.pngData() {
                      try await uploadImageData(medium, contentType: upload.contentType, to: writeUrlMedium)
                  }
              }
              
              if let writeUrlLarge = uploadURL.writeUrlLarge{
                  if let large = upload.uiImage?.imageCut(cutSize: 900)?.pngData(){
                      try await uploadImageData(large, contentType: upload.contentType, to: writeUrlLarge)
                  }
              }
              
              onUpload(.transactionEnd(uploadURL))
              
          }
          else {
              throw UploadError.uploadFail
          }
          
      
      }
      catch {
          
          print( error.localizedDescription)
          throw UploadError.uploadFail
      }
    }
     
    
    func uploadImageData(_ imageData: Data, contentType:String, to writeUrl: String) async throws {
      
      
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
    
     
  
    public func urlSession(_ session: URLSession, task: URLSessionTask, didSendBodyData bytesSent: Int64, totalBytesSent: Int64, totalBytesExpectedToSend: Int64) {
      
      //let progress = Float(totalBytesSent) / Float(totalBytesExpectedToSend)
        
      
        // Calculate and report the progress
       guard totalBytesExpectedToSend > 0 else { return }
       let progress = Double(totalBytesSent) / Double(totalBytesExpectedToSend)
       progressHandlersByTaskID[task.taskIdentifier]?(progress)

      print("urlSession progress = \(progress)")
     
  }
}


//
//  AKExtension.swift
//  AppKeyIDSwift
//
//  Created by Tola Voeung on 2/9/25.
//
import Foundation
import SwiftUI
import PhotosUI


extension Formatter {
    static let iso8601: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .iso8601)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSXXXXX"
        return formatter
    }()
}
 
extension NSString {
    public func mimeType() -> String {
        if #available(iOS 14.0, *) {
            if let mimeType = UTType(filenameExtension: self.pathExtension)?.preferredMIMEType {
                return mimeType
            }
            else {
                return "application/octet-stream"
            }
        } else {
            return "application/octet-stream"
            // Fallback on earlier versions
        }
    }
}


extension String {
    public func mimeType() -> String {
        return (self as NSString).mimeType()
    }
}

extension UIImage {
   
   var csMimeType: String? {
       get {
           return self.value(forKey: "csmimetype") as? String
       }
       
       set(value) {
           self.setValue(value, forKey: "csmimetype")
       }
   }
   
   func imageCut(cutSize: CGFloat) -> UIImage? {
       
       let sizeOriginal = self.size
       if sizeOriginal.width > 0 && sizeOriginal.height > 0 {
           var newSize = sizeOriginal
           
           if sizeOriginal.width < sizeOriginal.height {
               // portrait
               if sizeOriginal.height > cutSize {
                   newSize.width = (cutSize * sizeOriginal.width) / sizeOriginal.height
                   newSize.height = cutSize
               }
               
           } else {
               // landscape
               if sizeOriginal.width > cutSize {
                   newSize.width = cutSize
                   newSize.height = (cutSize * sizeOriginal.height) / sizeOriginal.width
               }
           }
           
           let rect = CGRect(x: 0, y: 0, width: newSize.width, height: newSize.height)
           
           UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
           self.draw(in: rect)
           let newImage = UIGraphicsGetImageFromCurrentImageContext()
           UIGraphicsEndImageContext()
           
           return newImage
       }
       
       return nil
   }
    
}

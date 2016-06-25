//
//  DataRepresentable.swift
//  Winter
//
//  Created by hengyu on 16/6/20.
//  Copyright © 2016年 hengyu. All rights reserved.
//

import Foundation
import UIKit.UIImage

public protocol DataRepresentable {
    associatedtype Element = Self
    
    static func decode(with data: Data) -> Element?
    
    func encode() -> Data?
}

extension Data: DataRepresentable {
    public static func decode(with data: Data) -> Data? {
        return data
    }
    
    public func encode() -> Data? {
        return self
    }
}

extension String: DataRepresentable {
    public static func decode(with data: Data) -> String? {
        return String(data: data, encoding: .utf8)
    }
    
    public func encode() -> Data? {
        return data(using: .utf8)
    }
}

extension Date: DataRepresentable {
    public static func decode(with data: Data) -> Date? {
        if let sinceRefRaw = String.decode(with: data), sinceRef = TimeInterval(sinceRefRaw) {
            return Date(timeIntervalSinceReferenceDate: sinceRef)
        }
        return nil
    }
    
    public func encode() -> Data? {
        let sinceRef = String(timeIntervalSinceReferenceDate)
        return sinceRef.encode()
    }
}

extension UIImage {
    var hasAlpha: Bool {
        if let alpha = cgImage?.alphaInfo {
            let result: Bool
            switch alpha {
            case .none, .noneSkipFirst, .noneSkipLast:
                result = false
            default:
                result = true
            }
            return result
        }
        return false
    }
}

extension UIImage: DataRepresentable {
    private static var decodingLock = Lock()
    
    public class func decode(with data: Data) -> UIImage? {
        decodingLock.lock()
        let image = UIImage(data: data)
        decodingLock.unlock()
        return image
    }
    
    public func encode() -> Data? {
        return hasAlpha ? UIImagePNGRepresentation(self) : UIImageJPEGRepresentation(self, 1.0)
    }
}


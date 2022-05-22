//
//  DataRepresentable.swift
//  Winter
//
//  Created by hengyu on 16/6/20.
//  Copyright © 2016年 hengyu. All rights reserved.
//

import Foundation
#if os(macOS)
import AppKit.NSImage
#else
import UIKit.UIImage
#endif

// swiftlint:disable type_name

public protocol DataRepresentable {
    associatedtype T = Self

    static func decode(with data: Data) -> T?

    func encode() -> Data?
}

// swiftlint:enable type_name

extension Data: DataRepresentable {
    public static func decode(with data: Data) -> Data? {
        data
    }

    public func encode() -> Data? {
        self
    }
}

extension String: DataRepresentable {
    public static func decode(with data: Data) -> String? {
        String(data: data, encoding: .utf8)
    }

    public func encode() -> Data? {
        data(using: .utf8)
    }
}

extension Date: DataRepresentable {
    public static func decode(with data: Data) -> Date? {
        if let sinceRefRaw = String.decode(with: data), let sinceRef = TimeInterval(sinceRefRaw) {
            return Date(timeIntervalSinceReferenceDate: sinceRef)
        }
        return nil
    }

    public func encode() -> Data? {
        let sinceRef = String(timeIntervalSinceReferenceDate)
        return sinceRef.encode()
    }
}

#if os(macOS)

extension NSImage {
    private static var decodingLock: NSLock = .init()

    public class func decode(with data: Data) -> NSImage? {
        decodingLock.lock()
        let image = NSImage(data: data)
        decodingLock.unlock()
        return image
    }

    public func encode() -> Data? {
        tiffRepresentation
    }
}

#else

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
    private static var decodingLock: NSLock = .init()

    public class func decode(with data: Data) -> UIImage? {
        decodingLock.lock()
        let image = UIImage(data: data)
        decodingLock.unlock()
        return image
    }

    public func encode() -> Data? {
        hasAlpha ? pngData() : jpegData(compressionQuality: 1.0)
    }
}

#endif

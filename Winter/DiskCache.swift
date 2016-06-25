//
//  DiskCache.swift
//  Winter
//
//  Created by hengyu on 16/6/18.
//  Copyright © 2016年 hengyu. All rights reserved.
//

import Foundation

public class DiskCache<ObjectType : DataRepresentable where ObjectType.Element == ObjectType> {
    private let fileManager: FileManager = FileManager()
    private var size: UInt = 0
    
    public let path: String
    public let name: String
    public let capacity: UInt
    
    public private(set) var dispatchQueue: DispatchQueue
    public var completionQueue: DispatchQueue = DispatchQueue.main
    
    public init(name: String, capacity: UInt = UInt.max) {
        self.path = CacheConstant.basePath + "/" + name
        self.name = name
        self.capacity = 0
        self.dispatchQueue = DispatchQueue(label: CacheConstant.domain + ".disk." + name, attributes: .serial)
    }
    
    public func controlSize() {
        dispatchQueue.async(execute: {
            self.calculateSize()
            self.removeExpiredItems()
        })
    }
    
    public func object(forKey key: String, completion: (ObjectType?, ErrorProtocol?) -> Void) {
        dispatchQueue.async(execute: {
            do {
                let data = try self.data(forKey: key)
                let obj = ObjectType.decode(with: data)
                let error: Error? = (obj == nil) ? nil : Error(code: .ObjectNotFound)
                self.completionQueue.async(execute: {
                    completion(obj, error)
                })
            } catch {
                self.completionQueue.async(execute: {
                    completion(nil, error)
                })
            }
        })
    }
    
    public func setObject(_ obj: ObjectType, forKey key: String, completion: (() -> Void)? = nil) {
        dispatchQueue.async(execute: {
            var isDirectory = ObjCBool(false)
            if !self.fileManager.fileExists(atPath: self.path, isDirectory: &isDirectory) || isDirectory.boolValue == false {
                _ = try? self.fileManager.createDirectory(atPath: self.path, withIntermediateDirectories: true, attributes: nil)
            }
            if let data = obj.encode() {
                do {
                    try self.setData(data, forKey: key)
                } catch {
                }
            } else {
                //let error = Error(code: .EncodingFailed)
            }
            self.completionQueue.async(execute: {
                completion?()
            })
        })
    }
    
    public func removeObject(forKey key: String, completion: (() -> Void)? = nil) {
        dispatchQueue.async(execute: {
            let url = self.fileURL(forKey: key)
            _ = try? self.removeItem(at: url)
            self.completionQueue.async(execute: {
                completion?()
            })
        })
    }
    
    
    public func removeAllObjects(completion: (() -> Void)? = nil) {
        dispatchQueue.async(execute: {
            self.removeAllItems()
            self.completionQueue.async(execute: {
                completion?()
            })
        })
    }
    
    private func calculateSize() {
        let resourceKeys: Set<URLResourceKey> = [.totalFileAllocatedSizeKey]
        
        var calculatedSize: UInt = 0
        do {
            let contents = try fileManager.contentsOfDirectory(atPath: path)
            for pathComponent in contents {
                let contentPath = (path as NSString).appendingPathComponent(pathComponent)
                let contentURL = URL(fileURLWithPath: contentPath)
                do {
                    let resourceValues = try contentURL.resourceValues(forKeys: resourceKeys)
                    if let contentSize = resourceValues.totalFileAllocatedSize where contentSize > 0 {
                        calculatedSize += UInt(contentSize)
                    }
                } catch {
                }
            }
        } catch {
        }
        size = calculatedSize
    }
    
    private func removeExpiredItems() {
        guard size > capacity else { return }
        guard let contents = try? fileManager.contentsOfDirectory(atPath: path) else { return }
        
        let resourceKeys: Set<URLResourceKey> = [.contentModificationDateKey]
        let sortedContents = contents.sorted(isOrderedBefore: { lsh, rsh in
            let lURL = URL(fileURLWithPath: lsh)
            let rURL = URL(fileURLWithPath: rsh)
            guard let lValues = try? lURL.resourceValues(forKeys: resourceKeys), lDate = lValues.contentModificationDate else { return true }
            guard let rValues = try? rURL.resourceValues(forKeys: resourceKeys), rDate = rValues.contentModificationDate else { return false }
            return lDate < rDate
        })
        let sortedURLs = sortedContents.map() { URL(fileURLWithPath: $0) }
        for url in sortedURLs where size > capacity {
            _ = try? removeItem(at: url)
        }
    }
    
    private func fileURL(forKey key: String) -> URL {
        let name = key.trimmingCharacters(in: .whitespacesAndNewlines)
        let filePath = path + "/" + name
        let url = URL(fileURLWithPath: filePath, isDirectory: false)
        return url
    }
    
    private func removeAllItems() {
        do {
            let contents = try fileManager.contentsOfDirectory(atPath: path)
            for pathComponent in contents {
                let contentPath = (path as NSString).appendingPathComponent(pathComponent)
                let contentURL = URL(fileURLWithPath: contentPath)
                _ = try? fileManager.removeItem(at: contentURL)
            }
            self.size = 0
        } catch {
        }
    }
    
    private func removeItem(at url: URL) throws {
        let resourceKeys: Set<URLResourceKey> = [.totalFileAllocatedSizeKey]
        guard let values = try? url.resourceValues(forKeys: resourceKeys), size = values.totalFileAllocatedSize where size > 0 else {
            try fileManager.removeItem(at: url)
            return
        }
        
        do {
            try fileManager.removeItem(at: url)
            let substractedSize = UInt(size)
            if substractedSize > self.size {
                self.size = 0
            } else {
                self.size -= substractedSize
            }
        } catch {
            throw error
        }
    }
    
    private func data(forKey key: String) throws -> Data {
        let url = fileURL(forKey: key)
        let data = try Data(contentsOf: url)
        return data
    }
    
    private func setData(_ data: Data, forKey key: String) throws {
        let fileUrl = fileURL(forKey: key)
        let resourceKeys: Set<URLResourceKey> = [.totalFileAllocatedSizeKey]
        var previousSize: UInt = 0
        if let values = try? fileUrl.resourceValues(forKeys: resourceKeys), let oldSize = values.totalFileAllocatedSize where oldSize > 0 {
            previousSize = UInt(oldSize)
        }
        
        do {
            try data.write(to: fileUrl, options: .atomicWrite)
            var currentSize: UInt = 0
            if let values = try? fileUrl.resourceValues(forKeys: resourceKeys), let newSize = values.totalFileAllocatedSize where newSize > 0 {
                currentSize = UInt(newSize)
            }
            size += currentSize
            if size > previousSize {
                size -= previousSize
            } else {
                size = 0
            }
        } catch {
            throw error
        }
    }
}




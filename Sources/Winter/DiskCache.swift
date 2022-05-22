//
//  DiskCache.swift
//  Winter
//
//  Created by hengyu on 16/6/18.
//  Copyright © 2016年 hengyu. All rights reserved.
//

import Foundation

public class DiskCache<ObjectType: DataRepresentable> where ObjectType.T == ObjectType {
    private let fileManager: FileManager = .init()
    private var size: Int = 0

    public let path: String
    public let name: String
    public let capacity: Int

    public private(set) var dispatchQueue: DispatchQueue
    public var completionQueue: DispatchQueue = .main

    public init(
        name: String,
        directoryURL: URL = CacheConstant.baseURL,
        capacity: Int = Int.max
    ) {
        self.path = directoryURL.appendingPathComponent(name, isDirectory: true).path
        self.name = name
        self.capacity = 0
        // serial
        self.dispatchQueue = DispatchQueue(label: CacheConstant.domain + ".disk." + name)
    }

    public func controlSize() {
        dispatchQueue.async {
            self.calculateSize()
            self.removeExpiredItems()
        }
    }

    open func dateOfObject(forKey key: String) -> Date? {
        let url = fileURL(forKey: key)
        let resourceKeys: Set<URLResourceKey> = [.contentModificationDateKey]
        if
            let values = try? url.resourceValues(forKeys: resourceKeys),
            let date = values.contentModificationDate
        {
            return date
        }
        return nil
    }

    public func object(forKey key: String, completion: @escaping (ObjectType?, Error?) -> Void) {
        dispatchQueue.async {
            do {
                let data = try self.data(forKey: key)
                let obj = ObjectType.decode(with: data)
                let error: WError? = (obj == nil) ? nil : WError(code: .objectNotFound)
                self.completionQueue.async {
                    completion(obj, error)
                }
            } catch {
                self.completionQueue.async {
                    completion(nil, error)
                }
            }
        }
    }

    public func setObject(_ obj: ObjectType, forKey key: String, completion: (() -> Void)? = nil) {
        dispatchQueue.async {
            var isDirectory = ObjCBool(false)
            if !self.fileManager.fileExists(atPath: self.path, isDirectory: &isDirectory)
                || isDirectory.boolValue == false {
                try? self.fileManager.createDirectory(
                    atPath: self.path,
                    withIntermediateDirectories: true,
                    attributes: nil
                )
            }
            if let data = obj.encode() {
                do {
                    try self.setData(data, forKey: key)
                } catch {
                }
            } else {
                // let error = WError(code: .encodingFailed)
            }
            self.completionQueue.async {
                completion?()
            }
        }
    }

    public func removeObject(forKey key: String, completion: (() -> Void)? = nil) {
        dispatchQueue.async {
            let url = self.fileURL(forKey: key)
            _ = try? self.removeItem(at: url)
            self.completionQueue.async {
                completion?()
            }
        }
    }

    public func removeAllObjects(completion: (() -> Void)? = nil) {
        dispatchQueue.async {
            self.removeAllItems()
            self.completionQueue.async {
                completion?()
            }
        }
    }

    private func calculateSize() {
        let resourceKeys: Set<URLResourceKey> = [.totalFileAllocatedSizeKey]

        var calculatedSize: Int = 0
        do {
            let contents = try fileManager.contentsOfDirectory(atPath: path)
            for pathComponent in contents {
                let contentPath = (path as NSString).appendingPathComponent(pathComponent)
                let contentURL = URL(fileURLWithPath: contentPath)
                do {
                    let resourceValues = try contentURL.resourceValues(forKeys: resourceKeys)
                    if let contentSize = resourceValues.totalFileAllocatedSize, contentSize > 0 {
                        calculatedSize += Int(contentSize)
                    }
                } catch {
                }
            }
        } catch {
        }
        size = calculatedSize
    }

    private func removeExpiredItems() {
        guard
            size > capacity,
            let contents = try? fileManager.contentsOfDirectory(atPath: path)
        else { return }

        let resourceKeys: Set<URLResourceKey> = [.contentModificationDateKey]
        let sortedContents = contents.sorted { lsh, rsh in
            let lURL = URL(fileURLWithPath: lsh)
            let rURL = URL(fileURLWithPath: rsh)

            guard
                let lValues = try? lURL.resourceValues(forKeys: resourceKeys),
                let lDate = lValues.contentModificationDate
            else { return true }

            guard
                let rValues = try? rURL.resourceValues(forKeys: resourceKeys),
                let rDate = rValues.contentModificationDate
            else { return false }

            return lDate < rDate
        }
        let sortedURLs = sortedContents.map { URL(fileURLWithPath: $0) }
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
        guard
            let values = try? url.resourceValues(forKeys: resourceKeys),
            let size = values.totalFileAllocatedSize,
            size > 0
        else {
            try fileManager.removeItem(at: url)
            return
        }

        do {
            try fileManager.removeItem(at: url)
            let substractedSize = size
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
        var previousSize: Int = 0
        if
            let values = try? fileUrl.resourceValues(forKeys: resourceKeys),
            let oldSize = values.totalFileAllocatedSize,
            oldSize > 0
        {
            previousSize = oldSize
        }

        do {
            try data.write(to: fileUrl, options: .atomicWrite)
            var currentSize: Int = 0
            if
                let values = try? fileUrl.resourceValues(forKeys: resourceKeys),
                let newSize = values.totalFileAllocatedSize,
                newSize > 0
            {
                currentSize = newSize
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

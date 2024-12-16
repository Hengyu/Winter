//
//  DiskCache.swift
//  Winter
//
//  Created by hengyu on 16/6/18.
//  Copyright © 2016年 hengyu. All rights reserved.
//

import Foundation

public final class DiskCache<ObjectType: DataRepresentable & Sendable>: Sendable where ObjectType.T == ObjectType {
    nonisolated(unsafe) private let fileManager: FileManager = .init()
    nonisolated(unsafe) private var cacheSize: Int = 0

    public let path: String
    public let name: String
    public let capacity: Int
    public let dispatchQueue: DispatchQueue
    public let completionQueue: DispatchQueue

    public init(
        name: String,
        directoryURL: URL = CacheConstant.baseURL,
        capacity: Int = Int.max,
        completionQueue: DispatchQueue = .main
    ) {
        self.path = directoryURL.appendingPathComponent(name, isDirectory: true).path
        self.name = name
        self.capacity = 0
        // serial
        self.dispatchQueue = DispatchQueue(label: CacheConstant.domain + ".disk." + name)
        self.completionQueue = completionQueue
    }

    public func controlSize() {
        dispatchQueue.async {
            self.calculateSize()
            self.removeExpiredItems()
        }
    }

    public func dateOfObject(forKey key: String) -> Date? {
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

    public func object(forKey key: String, completion: @escaping @Sendable (ObjectType?, Error?) -> Void) {
        dispatchQueue.async {
            do {
                let data = try self.data(forKey: key)
                let obj = ObjectType.decode(with: data)
                self.completionQueue.async {
                    completion(obj, nil)
                }
            } catch {
                self.completionQueue.async {
                    completion(nil, error)
                }
            }
        }
    }

    @available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
    public func object(forKey key: String) async throws -> ObjectType? {
        try await withUnsafeThrowingContinuation { continuation in
            dispatchQueue.async {
                do {
                    let data = try self.data(forKey: key)
                    if let obj = ObjectType.decode(with: data) {
                        continuation.resume(returning: obj)
                    } else {
                        continuation.resume(throwing: WError(code: .decodingFailed))
                    }
                } catch {
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    public func setObject(_ object: ObjectType, forKey key: String, completion: (@Sendable (Error?) -> Void)? = nil) {
        dispatchQueue.async {
            do {
                try self.createDirectoryIfNeeded()
                if let data = object.encode() {
                    try self.setData(data, forKey: key)
                    self.completionQueue.async {
                        completion?(nil)
                    }
                } else {
                    self.completionQueue.async {
                        completion?(WError(code: .encodingFailed))
                    }
                }
            } catch {
                self.completionQueue.async {
                    completion?(error)
                }
            }
        }
    }

    @available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
    public func setObject(_ object: ObjectType, forKey key: String) async throws {
        try await withUnsafeThrowingContinuation { (continuation: UnsafeContinuation<Void, Error>) in
            dispatchQueue.async {
                do {
                    try self.createDirectoryIfNeeded()
                } catch {
                    continuation.resume(throwing: error)
                }

                if let data = object.encode() {
                    do {
                        try self.setData(data, forKey: key)
                    } catch {
                        continuation.resume(throwing: error)
                    }
                } else {
                    continuation.resume(throwing: WError(code: .encodingFailed))
                }
            }
        }
    }

    public func removeObject(forKey key: String, completion: (@Sendable (Error?) -> Void)? = nil) {
        dispatchQueue.async {
            let url = self.fileURL(forKey: key)
            do {
                try self.removeItem(at: url)
                self.completionQueue.async {
                    completion?(nil)
                }
            } catch {
                self.completionQueue.async {
                    completion?(error)
                }
            }
        }
    }

    @available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
    public func removeObject(forKey key: String) async throws {
        try await withUnsafeThrowingContinuation { (continuation: UnsafeContinuation<Void, Error>) in
            dispatchQueue.async {
                let url = self.fileURL(forKey: key)
                do {
                    try self.removeItem(at: url)
                    continuation.resume(returning: ())
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    public func removeAllObjects(completion: (@Sendable (Error?) -> Void)? = nil) {
        dispatchQueue.async {
            do {
                try self.removeAllItems()
                self.completionQueue.async {
                    completion?(nil)
                }
            } catch {
                self.completionQueue.async {
                    completion?(error)
                }
            }
        }
    }

    @available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
    public func removeAllObjects() async throws {
        try await withUnsafeThrowingContinuation { (continuation: UnsafeContinuation<Void, Error>) in
            dispatchQueue.async {
                do {
                    try self.removeAllItems()
                    continuation.resume(returning: ())
                } catch {
                    continuation.resume(throwing: error)
                }
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
        cacheSize = calculatedSize
    }

    private func removeExpiredItems() {
        guard
            cacheSize > capacity,
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
        for url in sortedURLs where cacheSize > capacity {
            _ = try? removeItem(at: url)
        }
    }

    private func fileURL(forKey key: String) -> URL {
        let name = key.trimmingCharacters(in: .whitespacesAndNewlines)
        let filePath = path + "/" + name
        let url = URL(fileURLWithPath: filePath, isDirectory: false)
        return url
    }

    private func removeAllItems() throws {
        let contents = try fileManager.contentsOfDirectory(atPath: path)
        for pathComponent in contents {
            let contentPath = (path as NSString).appendingPathComponent(pathComponent)
            let contentURL = URL(fileURLWithPath: contentPath)
            _ = try? fileManager.removeItem(at: contentURL)
        }
        self.cacheSize = 0
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
            if substractedSize > self.cacheSize {
                self.cacheSize = 0
            } else {
                self.cacheSize -= substractedSize
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
            cacheSize += currentSize
            if cacheSize > previousSize {
                cacheSize -= previousSize
            } else {
                cacheSize = 0
            }
        } catch {
            throw error
        }
    }

    private func createDirectoryIfNeeded() throws {
        var isDirectory = ObjCBool(false)
        if !fileManager.fileExists(atPath: path, isDirectory: &isDirectory)
            || !isDirectory.boolValue {
            try fileManager.createDirectory(atPath: path, withIntermediateDirectories: true)
        }
    }
}

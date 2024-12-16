//
//  Cache.swift
//  Winter
//
//  Created by hengyu on 16/6/23.
//  Copyright © 2016年 hengyu. All rights reserved.
//

import Foundation
#if os(iOS) || os(tvOS)
import UIKit.UIApplication
#endif

public struct CacheConstant {
    static let domain: String = "hengyu.Winter"
    static let basePath: String = {
        let cachesPath = NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true)[0]
        let basePath = cachesPath + "/" + domain
        return basePath
    }()

    public static let baseURL: URL = URL(fileURLWithPath: basePath, isDirectory: true)
}

public final class Cache<ObjectType: DataRepresentable & Sendable>: Sendable where ObjectType.T == ObjectType {
    public let name: String
    /// The maximum cache size in bytes. Default is 100MB.
    public let capacity: Int
    public let directoryURL: URL

    private let diskCache: DiskCache<ObjectType>
    private let memoryCache: MemoryCache<ObjectType>

    public let dispatchQueue: DispatchQueue
    public let completionQueue: DispatchQueue

    public init(
        name: String,
        directoryURL: URL = CacheConstant.baseURL,
        capacity: Int = 100 * 1024,
        completionQueue: DispatchQueue = .main
    ) {
        self.name = name
        self.capacity = capacity
        self.directoryURL = directoryURL
        self.diskCache = DiskCache(name: name, directoryURL: directoryURL, capacity: capacity, completionQueue: completionQueue)
        self.memoryCache = MemoryCache(name: name, capacity: capacity, completionQueue: completionQueue)
        self.dispatchQueue = DispatchQueue(label: CacheConstant.domain + ".cache." + name, attributes: .concurrent)
        self.completionQueue = completionQueue
        #if os(iOS) || os(tvOS) || os(watchOS)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(Cache.applicationDidReceiveMemoryWarning),
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil
        )
        #endif
    }

    public func dateOfObject(forKey key: String) -> Date? {
        diskCache.dateOfObject(forKey: key)
    }

    public func object(forKey key: String, completion: @escaping @Sendable (ObjectType?, Error?) -> Void) {
        memoryCache.object(forKey: key) { obj in
            if let obj {
                self.completionQueue.async { completion(obj, nil) }
            } else {
                self.diskCache.object(forKey: key) { obj2, error in
                    self.completionQueue.async { completion(obj2, error) }
                }
            }
        }
    }

    @available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
    public func object(forKey key: String) async throws -> ObjectType? {
        if let object = await memoryCache.object(forKey: key) {
            return object
        } else {
            return try await diskCache.object(forKey: key)
        }
    }

    public func setObject(_ obj: ObjectType, forKey key: String, completion: (@Sendable () -> Void)? = nil) {
        if let completion {
            let group = DispatchGroup()
            group.enter()
            diskCache.setObject(obj, forKey: key) { _ in
                group.enter()
            }
            group.enter()
            memoryCache.setObject(obj, forKey: key) {
                group.leave()
            }
            group.notify(queue: completionQueue, execute: completion)
        } else {
            diskCache.setObject(obj, forKey: key)
            memoryCache.setObject(obj, forKey: key)
        }
    }

    @available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
    public func setObject(_ object: ObjectType, forKey key: String) async throws {
        try await diskCache.setObject(object, forKey: key)
        await memoryCache.setObject(object, forKey: key)
    }

    public func removeObject(forKey key: String, completion: (@Sendable () -> Void)? = nil) {
        if let completion {
            let group = DispatchGroup()
            group.enter()
            diskCache.removeObject(forKey: key) { _ in
                group.leave()
            }
            group.enter()
            memoryCache.removeObject(forKey: key) {
                group.leave()
            }
            group.notify(queue: completionQueue, execute: completion)
        } else {
            diskCache.removeObject(forKey: key)
            memoryCache.removeObject(forKey: key)
        }
    }

    @available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
    public func removeObject(forKey key: String) async throws {
        try await diskCache.removeObject(forKey: key)
        await memoryCache.removeObject(forKey: key)
    }

    public func removeAllObjects(completion: (@Sendable () -> Void)? = nil) {
        if let completion = completion {
            let group = DispatchGroup()
            group.enter()
            diskCache.removeAllObjects { _ in
                group.leave()
            }
            group.enter()
            memoryCache.removeAllObjects {
                group.leave()
            }
            group.notify(queue: completionQueue, execute: completion)
        } else {
            diskCache.removeAllObjects()
            memoryCache.removeAllObjects()
        }
    }

    @available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
    public func removeAllObjects() async throws {
        try await diskCache.removeAllObjects()
        await memoryCache.removeAllObjects()
    }

    @objc
    private func applicationDidReceiveMemoryWarning() {
        memoryCache.removeAllObjects()
    }
}

//
//  MemoryCache.swift
//  Winter
//
//  Created by hengyu on 16/6/20.
//  Copyright © 2016年 hengyu. All rights reserved.
//

import Foundation

internal final class ObjectContainer<T>: NSObject {
    let object: T

    init(object: T) {
        self.object = object
    }
}

extension ObjectContainer: Sendable where T: Sendable { }

public final class MemoryCache<ObjectType: DataRepresentable & Sendable>: Sendable where ObjectType.T == ObjectType {
    nonisolated(unsafe) private let cache: Foundation.NSCache<NSString, ObjectContainer<ObjectType>>

    public let name: String
    public let capacity: Int
    public let dispatchQueue: DispatchQueue
    public let completionQueue: DispatchQueue

    public init(name: String, capacity: Int, completionQueue: DispatchQueue = .main) {
        self.name = name
        self.capacity = capacity
        self.dispatchQueue = DispatchQueue(label: CacheConstant.domain + ".memory." + name)
        self.completionQueue = completionQueue
        self.cache = Foundation.NSCache<NSString, ObjectContainer<ObjectType>>()
        self.cache.name = name
        self.cache.countLimit = capacity
    }

    public func object(forKey key: String, completion: @escaping @Sendable (ObjectType?) -> Void) {
        dispatchQueue.async {
            let container = self.cache.object(forKey: key as NSString)
            self.completionQueue.async {
                completion(container?.object)
            }
        }
    }

    @available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
    public func object(forKey key: String) async -> ObjectType? {
        await withCheckedContinuation { continuation in
            dispatchQueue.async {
                let container = self.cache.object(forKey: key as NSString)
                continuation.resume(returning: container?.object)
            }
        }
    }

    public func setObject(_ obj: ObjectType, forKey key: String, completion: (@Sendable () -> Void)? = nil) {
        dispatchQueue.async {
            let container = ObjectContainer(object: obj)
            self.cache.setObject(container, forKey: key as NSString)
            self.completionQueue.async {
                completion?()
            }
        }
    }

    @available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
    public func setObject(_ obj: ObjectType, forKey key: String) async {
        await withUnsafeContinuation { continuation in
            dispatchQueue.async {
                let container = ObjectContainer(object: obj)
                self.cache.setObject(container, forKey: key as NSString)
                continuation.resume(returning: ())
            }
        }
    }

    public func removeObject(forKey key: String, completion: (@Sendable () -> Void)? = nil) {
        dispatchQueue.async {
            self.cache.removeObject(forKey: key as NSString)
            self.completionQueue.async {
                completion?()
            }
        }
    }

    @available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
    public func removeObject(forKey key: String) async {
        await withUnsafeContinuation { continuation in
            dispatchQueue.async {
                self.cache.removeObject(forKey: key as NSString)
                continuation.resume(returning: ())
            }
        }
    }

    public func removeAllObjects(completion: (@Sendable () -> Void)? = nil) {
        dispatchQueue.async {
            self.cache.removeAllObjects()
            self.completionQueue.async {
                completion?()
            }
        }
    }

    @available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
    public func removeAllObjects() async {
        await withUnsafeContinuation { continuation in
            dispatchQueue.async {
                self.cache.removeAllObjects()
                continuation.resume(returning: ())
            }
        }
    }
}

//
//  MemoryCache.swift
//  Winter
//
//  Created by hengyu on 16/6/20.
//  Copyright © 2016年 hengyu. All rights reserved.
//

import Foundation

internal class ObjectContainer<T>: NSObject {
    let object: T
    init(object: T) {
        self.object = object
    }
}

public class MemoryCache<ObjectType: DataRepresentable> where ObjectType.T == ObjectType {
    private let cache: Foundation.NSCache<NSString, ObjectContainer<ObjectType>>

    public let name: String
    public let capacity: UInt

    public private(set) var dispatchQueue: DispatchQueue
    public var completionQueue: DispatchQueue = DispatchQueue.main

    public init(name: String, capacity: UInt = UInt.max) {
        self.name = name
        self.capacity = 0
        self.dispatchQueue = DispatchQueue(label: CacheConstant.domain + ".memory." + name)
        self.cache = Foundation.NSCache<NSString, ObjectContainer<ObjectType>>()
        self.cache.name = name
        self.cache.countLimit = Int(capacity)
    }

    public func object(forKey key: String, completion: @escaping (ObjectType?, Error?) -> Void) {
        dispatchQueue.async(execute: {
            let container = self.cache.object(forKey: key as NSString)
            let error: WError? = (container == nil) ? nil : WError(code: .objectNotFound)
            self.completionQueue.async {
                completion(container?.object, error)
            }
        })
    }

    public func setObject(_ obj: ObjectType, forKey key: String, completion: (() -> Void)? = nil) {
        dispatchQueue.async(execute: {
            let container = ObjectContainer(object: obj)
            self.cache.setObject(container, forKey: key as NSString)
            self.completionQueue.async(execute: {
                completion?()
            })
        })
    }

    public func removeObject(forKey key: String, completion: (() -> Void)? = nil) {
        dispatchQueue.async(execute: {
            self.cache.removeObject(forKey: key as NSString)
            self.completionQueue.async(execute: {
                completion?()
            })
        })
    }

    public func removeAllObjects(completion: (() -> Void)? = nil) {
        dispatchQueue.async(execute: {
            self.cache.removeAllObjects()
            self.completionQueue.async(execute: {
                completion?()
            })
        })
    }
}

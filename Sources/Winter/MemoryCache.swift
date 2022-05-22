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
    public let capacity: Int

    public private(set) var dispatchQueue: DispatchQueue
    public var completionQueue: DispatchQueue = DispatchQueue.main

    public init(name: String, capacity: Int) {
        self.name = name
        self.capacity = capacity
        self.dispatchQueue = DispatchQueue(label: CacheConstant.domain + ".memory." + name)
        self.cache = Foundation.NSCache<NSString, ObjectContainer<ObjectType>>()
        self.cache.name = name
        self.cache.countLimit = capacity
    }

    public func object(forKey key: String, completion: @escaping (ObjectType?, Error?) -> Void) {
        dispatchQueue.async {
            let container = self.cache.object(forKey: key as NSString)
            let error: WError? = (container != nil) ? nil : WError(code: .objectNotFound)
            self.completionQueue.async {
                completion(container?.object, error)
            }
        }
    }

    public func setObject(_ obj: ObjectType, forKey key: String, completion: (() -> Void)? = nil) {
        dispatchQueue.async {
            let container = ObjectContainer(object: obj)
            self.cache.setObject(container, forKey: key as NSString)
            self.completionQueue.async {
                completion?()
            }
        }
    }

    public func removeObject(forKey key: String, completion: (() -> Void)? = nil) {
        dispatchQueue.async {
            self.cache.removeObject(forKey: key as NSString)
            self.completionQueue.async {
                completion?()
            }
        }
    }

    public func removeAllObjects(completion: (() -> Void)? = nil) {
        dispatchQueue.async {
            self.cache.removeAllObjects()
            self.completionQueue.async {
                completion?()
            }
        }
    }
}

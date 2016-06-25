//
//  Cache.swift
//  Winter
//
//  Created by hengyu on 16/6/23.
//  Copyright © 2016年 hengyu. All rights reserved.
//

import Foundation

internal struct CacheConstant {
    static let domain: String = "hengyu.Winter"
    static let basePath: String = {
        let cachesPath = NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true)[0]
        let basePath = cachesPath + "/" + domain
        return basePath
    }()
}

public class Cache<ObjectType : DataRepresentable where ObjectType.Element == ObjectType> {
    public let name: String
    public let capacity: UInt
    
    private let diskCache: DiskCache<ObjectType>
    private let memoryCache: MemoryCache<ObjectType>
    
    public private(set) var dispatchQueue: DispatchQueue
    public var completionQueue: DispatchQueue = DispatchQueue.main
    
    public init(name: String, capacity: UInt = .max) {
        self.name = name
        self.capacity = capacity
        self.diskCache = DiskCache(name: name, capacity: capacity)
        self.memoryCache = MemoryCache(name: name, capacity: capacity)
        self.dispatchQueue = DispatchQueue(label: CacheConstant.domain + ".cache." + name, attributes: .concurrent)
        self.diskCache.completionQueue = dispatchQueue
        self.memoryCache.completionQueue = dispatchQueue
        NotificationCenter.default().addObserver(self, selector: #selector(Cache.applicationDidReceiveMemoryWarning), name: NSNotification.Name.UIApplicationDidReceiveMemoryWarning, object: nil)
    }
    
    deinit {
        NotificationCenter.default().removeObserver(self, name: NSNotification.Name.UIApplicationDidReceiveMemoryWarning, object: nil)
    }
    
    public func object(forKey key: String, completion: (ObjectType?, ErrorProtocol?) -> Void) {
        memoryCache.object(forKey: key, completion: { obj, _ in
            if let obj = obj {
                self.completionQueue.async(execute: { completion(obj, nil) })
            } else {
                self.diskCache.object(forKey: key, completion: { obj2, err2 in
                    self.completionQueue.async(execute: { completion(obj2, err2) })
                })
            }
        })
    }
    
    public func setObject(_ obj: ObjectType, forKey key: String, completion: (() -> Void)? = nil) {
        if let completion = completion {
            var count = 2
            diskCache.setObject(obj, forKey: key) {
                count -= 1
                if count == 0 {
                    self.completionQueue.async(execute: completion)
                }
            }
            memoryCache.setObject(obj, forKey: key) {
                count -= 1
                if count == 0 {
                    self.completionQueue.async(execute: completion)
                }
            }
        } else {
            diskCache.setObject(obj, forKey: key)
            memoryCache.setObject(obj, forKey: key)
        }
    }
    
    public func removeObject(forKey key: String, completion: (() -> Void)? = nil) {
        if let completion = completion {
            var count = 2
            diskCache.removeObject(forKey: key) {
                count -= 1
                if count == 0 {
                    self.completionQueue.async(execute: completion)
                }
            }
            memoryCache.removeObject(forKey: key) {
                count -= 1
                if count == 0 {
                    self.completionQueue.async(execute: completion)
                }
            }
        } else {
            diskCache.removeObject(forKey: key)
            memoryCache.removeObject(forKey: key)
        }
    }
    
    
    public func removeAllObjects(completion: (() -> Void)? = nil) {
        if let completion = completion {
            var count = 2
            diskCache.removeAllObjects() {
                count -= 1
                if count == 0 {
                    self.completionQueue.async(execute: completion)
                }
            }
            memoryCache.removeAllObjects() {
                count -= 1
                if count == 0 {
                    self.completionQueue.async(execute: completion)
                }
            }
        } else {
            diskCache.removeAllObjects()
            memoryCache.removeAllObjects()
        }
    }
    
    @objc private func applicationDidReceiveMemoryWarning() {
        memoryCache.removeAllObjects()
    }
}

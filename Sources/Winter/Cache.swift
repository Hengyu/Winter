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

internal struct CacheConstant {
    static let domain: String = "hengyu.Winter"
    static let basePath: String = {
        let cachesPath = NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true)[0]
        let basePath = cachesPath + "/" + domain
        return basePath
    }()
}

public class Cache<ObjectType: DataRepresentable> where ObjectType.T == ObjectType {
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
        #if os(iOS) || os(tvOS)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(Cache.applicationDidReceiveMemoryWarning),
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil
        )
        #endif
    }

    public func object(forKey key: String, completion: @escaping (ObjectType?, Error?) -> Void) {
        memoryCache.object(forKey: key) { obj, _ in
            if let obj = obj {
                self.completionQueue.async { completion(obj, nil) }
            } else {
                self.diskCache.object(forKey: key) { obj2, err2 in
                    self.completionQueue.async { completion(obj2, err2) }
                }
            }
        }
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
            diskCache.removeAllObjects {
                count -= 1
                if count == 0 {
                    self.completionQueue.async(execute: completion)
                }
            }
            memoryCache.removeAllObjects {
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

    @objc
    private func applicationDidReceiveMemoryWarning() {
        memoryCache.removeAllObjects()
    }
}

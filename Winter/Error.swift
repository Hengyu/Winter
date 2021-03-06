//
//  Error.swift
//  Winter
//
//  Created by hengyu on 16/6/21.
//  Copyright © 2016年 hengyu. All rights reserved.
//

import Foundation

public enum ErrorCode: Int {
    case ObjectNotFound
    case EncodingFailed
}

public class Error: NSError {
    public init(code: Int, userInfo dict: [NSObject : AnyObject]? = [:]) {
        super.init(domain: "hengyu.Winter", code: code, userInfo: dict)
    }
    
    public convenience init(code: ErrorCode) {
        self.init(code: code.rawValue)
    }
    
    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
}

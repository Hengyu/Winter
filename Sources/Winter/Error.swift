//
//  Error.swift
//  Winter
//
//  Created by hengyu on 16/6/21.
//  Copyright © 2016年 hengyu. All rights reserved.
//

import Foundation

public enum WErrorCode: Int, Sendable {
    case objectNotFound
    case encodingFailed
}

public class WError: NSError {
    public init(code: Int, userInfo dict: [String: Any]? = [:]) {
        super.init(domain: "hengyu.Winter", code: code, userInfo: dict)
    }

    public convenience init(code: WErrorCode) {
        self.init(code: code.rawValue)
    }

    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
}

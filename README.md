# Winter

![](https://img.shields.io/badge/iOS-11.0%2B-green)
![](https://img.shields.io/badge/macOS-10.13%2B-green)
![](https://img.shields.io/badge/Swift-5-orange?logo=Swift&logoColor=white)
![](https://img.shields.io/github/last-commit/hengyu/Winter)

![Winter](winter.png)

**Winter** is a lightweight *generic* cache framework written in __Swift 5.7__. For the __Swift 3__ version, please refer to the [*master*](https://github.com/Hengyu/Winter/tree/master) branch.

## Table of contents

* [Requirements](#requirements)
* [Installation](#installation)
* [Usage](#usage)
* [License](#license) 

## Requirements

- iOS 11.0+, tvOS 11.0+, macOS 10.13+, watchOS 6.0+
- Swift 5.7

## Installation

`Winter` could be installed via [Swift Package Manager](https://www.swift.org/package-manager/). Open Xcode and go to **File** -> **Add Packages...**, search `https://github.com/hengyu/Winter.git`, and add the package as one of your project's dependency.

### DataRepresentable protocol

Encode and decode methods should be implemented if a type conforms to `DataRepresentable` protocol.

```swift
extension GHMember: DataRepresentable {
    public class func decode(with data: Data) -> GHMember? {
    	// decode to the desired object using the given data
        if let raw = String.decode(with: data), mem = GHMember(rawString: raw) {
            return mem
        }
        return nil
    }
    
    public func encode() -> Data? {
    	// encode the instance to data
        return self.rawString?.encode()
    }
}    
```

## Usage

The usage is quite simple, just import the `Winter` framework and create a cache object manager:

```swift
let cache = Winter.Cache<Data>(name: "data") // initialize a cache 
cache.setObject(myData, forKey: "example") // add an object
cache.object(forKey: "example") { obj, err in
    // get an object 
    // ...
}
```

Winter provides a memory and disk cache for `UIImage`, `Data`, `Date`, `String` or any other type that can be read or written as data.

## License

**Winter** is available under the [MIT License](LICENSE).

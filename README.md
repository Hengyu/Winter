
![Winter](winter.png)
# Winter

Winter is a lightweight *generic* cache framework written in __Swift 5.7__. For the __Swift 3__ version, please refer to the [*master*](https://github.com/Hengyu/Winter/tree/master) branch. 

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

## Key features

- Generic `DataRepresentable` protocol to be able to cache any type you want.
- `Cache` class to create a type safe cache storage by a given name for a specified
`DataRepresentable`-compliant type.
- Basic memory and disk cache functionality.
- `DataRepresentable` protocol are implemented for `UIImage`, `Data`, and `String`.
- Support for iOS, tvOS, watchOS and macOS.

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


## Requirements

- iOS 10.0+
- Swift 5.7

## License

**Winter** is available under the [MIT License](LICENSE).

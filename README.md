
![Winter](winter.png)
# Winter

Winter is a lightweight *generic* cache framework written in __Swift 3.0__. The usage is quite simple.

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
- iOS support (macOS, tvOS support in the future).

## Installation

Manually:

1. Drag `Winter.xcodeproj` to your project in the _Project Navigator_.
2. Select your project and then your app target. Open the _Build Phases_ panel.
3. Expand the _Target Dependencies_ group, and add `Winter.framework`.
4. Click on the `+` button at the top left of the panel and select _New Copy Files Phase_. Set _Destination_ to _Frameworks_, and add `Winter.framework`.

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

- iOS 8.0+
- Swift 3.0

Since 'NS' prefix has been removed from `Foundation` in `Swift 3`, using `Cache` directly will cause inconsistency. You may need to specify a framework prefix while using class `Cache`, or use the keyword `typealias`.
 
```swift
let foundationCache = Foundation.Cache<Key, Object>(name: "fCache") // creates a foundation cache
let winterCache = Winter.Cache<DataRepresentable>(name: "wCache") // creates a winter cache

typelias WCache = Winter.Cache
let myCache = WCahce<DataRepresentable>(name: "myCache") // creates a winter cache using typealias

```

## License

**Winter** is available under the MIT license. See the [LICENSE](LICENSE.md) file for more info.

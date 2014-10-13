Jetstream is an elegant model framework written in Swift

## Features

- [x] Change observation
- [x] Fire-and-forget observation
- [x] Modular architecture
- [x] Comprehensive Unit Test Coverage
- [x] Complete Documentation

## Requirements

- iOS 7.0+ / Mac OS X 10.9+
- Xcode 6.0

## Communication

- If you **found a bug**, fix it and submit a pull request, or open an issue.
- If you **have a feature request**, implement it and submit a pull request or open an issue.
- If you **want to contribute**, submit a pull request.

## Installation

Jetstream will be available as a [CocoaPod](http://cocoapods.org) once support for Swift lands. IN the meanwhile, follow these steps:

1. Add Jetstream as a [submodule](http://git-scm.com/docs/git-submodule): `git submodule add https://github.com/uber/jetstream-ios.git`
2. Open the `Jetstream` folder, and drag `Jetstream.xcodeproj` into the project navigator of your app.
3. In Xcode, select your project, navigate to the General tab and click the + - icon in the "Embedded Binaries" section. Select `Jetstream.framework`.

---

## Usage

### Creating models

Jetstream works with two basic consepts: All your model objects extend from the superclass `ModelObject` and one of your ModelObject instances will be the root for your model tree encapsulated by a `Scope`.

Let's model a canvas of shapes:

```swift
public class Canvas: ModelObject {
    dynamic var name: String?
    dynamic var shapes = [Shape]()
}

enum ShapeType: Int {
    case Circle = 0
    case Rectangle
}

public class Shape: ModelObject {
    dynamic var type: ShapeType = .Circle
    dynamic var x: Float = 0
    dynamic var y: Float = 0
    dynamic var width: Float = 100
    dynamic var height: Float = 100
}
```

Supported types are `String`, `UInt`, `Int`, `UInt8`, `Int8`, `UInt16`, `Int16`, `UInt32`, `Int32`, `Float`, `Double`, `Bool`, `ModelObject` and `[ModelObject]`

## License

Jetstream is released under the MIT license. See LICENSE for details.

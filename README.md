Jetstream for iOS is an elegant model framework written in Swift. It includes support for the Jetstream Sync protocol to sync local and remote models.  Out of the box it has a single Websocket transport adapter with the ability to add custom transport adapters.

## Features

- [x] Change observation
- [x] Fire-and-forget observation
- [x] Modular architecture
- [x] Comprehensive Unit Test Coverage

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

# Usage

### Creating models

Jetstream works with two basic concepts: All your model objects extend from the superclass `ModelObject` and one of your ModelObject instances will be the root for your model tree encapsulated by a `Scope`.

Let's model a canvas of shapes:

```swift
public class Shape: ModelObject {
    dynamic var x: Float = 0
    dynamic var y: Float = 0
    dynamic var width: Float = 100
    dynamic var height: Float = 100
    dynamic var type: ShapeType = .Circle
}

public class Canvas: ModelObject {
    dynamic var name: String?
    dynamic var shapes = [Shape]()
}
```
Once you've defined your model classes, instante a canvas and mark it as a scope root.

```swift
var cancas = Canvas()
canvas.isScopeRoot = true
```
This will create a new scope and assing `canvas` as the root of the scope. The root object or any branches or leafs attached now belong to the scope. This lets you start observing changes happening to any models that have been attached to the tree:

```swift
canvas.observePropertyChange(self, key: "shapes") { (element: Shape) in
    // A new shape was just added to our shapes-collection. Let's add listeners on it

    element.observeChange(self, keys: ["x", "y", "width", "height"]) {
        // Any of the provided properties have changed
    }

    element.observeDetach(self) {
        // The shape has been removed from the scope 
        // (i.e. it has been removed from the shapes collection)
    }
}

canvas.observeCollectionAdd(self, key: "shapes") { (element: Shape) in
    // A new shape was just added to our shapes-collection
}

canvas.observeChange(self, key: "name") {
    // The name of our canvas changed
}

```

You create a model by subclassing ModelObject and defining properties of the model as dynamic variables. Getters, private variables and constants are not counted as properties of the model and will not be observed.

Supported types are `String`, `UInt`, `Int`, `UInt8`, `Int8`, `UInt16`, `Int16`, `UInt32`, `Int32`, `Float`, `Double`, `Bool`, `ModelObject`, `[ModelObject]`, `UIColor` and `NSDate` 

As Jetstream relies on Objective-C runtime to detect changes to properties only types that can be represented in Objective-C can be used as property types. Unfortunately Swift enums can not be represented in Objective-C and can thus not be used. To use enums types, declare them in a Objective-C header file.

## License

Jetstream is released under the MIT license. See LICENSE for details.


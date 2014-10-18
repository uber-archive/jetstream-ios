Jetstream for iOS is an elegant MVVM model framework written in Swift. It includes support for the Jetstream Sync protocol to sync local and remote models.  Out of the box it has a single Websocket transport adapter with the ability to add custom transport adapters.

## Features

- [x] Change observation
- [x] Fire-and-forget observation
- [x] Modular architecture
- [x] Comprehensive Unit Test Coverage

## Requirements

- iOS 7.0+ / Mac OS X 10.9+
- Xcode 6.0

## Installation

Jetstream will be available as a [CocoaPod](http://cocoapods.org) once support for Swift lands. In the meanwhile, follow these steps:

1. Add Jetstream as a [submodule](http://git-scm.com/docs/git-submodule): `git submodule add https://github.com/uber/jetstream-ios.git`
2. Open the `Jetstream` folder, and drag `Jetstream.xcodeproj` into the project navigator of your app.
3. In Xcode, select your project, navigate to the General tab and click the + - icon in the "Embedded Binaries" section. Select `Jetstream.framework`.

# Quick start

Jetstream works with two basic concepts: All your model objects extend from the superclass `ModelObject` and one of your ModelObject instances will be the root for your model tree which is wrapped by a `Scope`.

Let's model a canvas of shapes:

```
public class Shape: ModelObject {
    dynamic var x: Float = 0
    dynamic var y: Float = 0
    dynamic var width: Float = 100
    dynamic var height: Float = 100
    dynamic var color: UIColor = UIColor.redColor()
}

public class Canvas: ModelObject {
    dynamic var name: String?
    dynamic var shapes = [Shape]()
}
```
Once you've defined your model classes, instante a canvas and mark it as a scope root.

```
var canvas = Canvas()
canvas.isScopeRoot = true
```
This will create a new scope and assing `canvas` as the root of the scope. The root object or any branches or leafs attached now belong to the scope. This lets you start observing changes happening to any models that have been attached to the tree:

```
Class CanvasViewController: UIViewController {
	…
	var model: Canvas
	
	func init() {
	    canvas.observeCollectionAdd(self, key: "shapes") { (element: Shape) in
            // A new shape was just added to our shapes-collection.
            view.addChild(ShapeView(shape: element))        
        }
    }
}

Class ShapeView: UIView {
	…
	init(shape: Shape) {
		self.shape = shape
	    shape.observeChange(self, keys: ["x", "y", "width", "height"]) {
             self.frame = {{shape.x, shape.y}, {shape.width, shape.height}}
        }
        shape.observeChange(self, key: "color") {
             self.backgroundColor = shape.color
        }
        shape.observeDetach(self) {
            // The shape model instance has been removed from the scope
            removeFromParentView()
        }
    }
}
```
This is all that is needed to create an application that binds itself to a view and works no matter how your model is changed. In fact, if you use Jetstreams built-in Websocket support to connect to the Jetstream server, changes coming in from remote users would update your UI perfectly without any changes to the code.

This is in essence how Jetstream works. You define a classes that model the data of your application. Your ViewControllers and Views then observe changes on the model to update their UI. In our canvas of shapes example, our ViewController listens to changes on the shapes-collection. Whenever a shape is added, it creates a ShapeView instance, adds it as a child view, and pass the Shape model to it. The ShapeView will bind to all the properties of the Shape and update its frame whenever. The ShapeView also observes whenever the Shape is detached (i.e. removed from the shapes-collection) and removes it from its parent view.

# Usage

## About models
You create a model by subclassing ModelObject and defining properties of the model as `dynamic` variables. Getters, private variables and constants are not observed by the model.

Supported types are `String`, `UInt`, `Int`, `UInt8`, `Int8`, `UInt16`, `Int16`, `UInt32`, `Int32`, `Float`, `Double`, `Bool`, `ModelObject`, `[ModelObject]`, `UIColor` and `NSDate` 

As Jetstream relies on Objective-C runtime to detect changes to properties only types that can be represented in Objective-C can be used as property types. Unfortunately Swift enums can not be represented in Objective-C and can thus not be used. To use enums types, declare them in a Objective-C header file.

## Observation
You have a number of methods to observe changes on model objects.

```
// Observe property changes on models
model.observeChange(self) { ... } // Observe all changes
model.observeChange(self, key: "width") { ... } // Observe a single property
model.observeChange(self, keys: ["width", "height"]) { ... } // Observe a set of properties
```
All of these methods queue up their notifications and fire only one time per run-loop. This is usually the behavior you want. When updating your view whenever properties change, you usually don't want to run view update code for every single property change, but do an update whenever all of the changes have been applied. For example, if the elements width and height properties have both changed, all of the observers will only fire off once in the next run-loop.

In some cases you might actually do want have the change observers fire off the callback for every single property change, which you can do using the immediate variants of the change observers:

```
// Observe property changes on models without queueing them up
model.observeChangeImmediately(self) { ... }
model.observeChangeImmediately(self, key: "width") { ... }
model.observeChangeImmediately(self, keys: ["width", "height"]) { ... }
```
Whenever collections change, they fire of the property change observers, but they also fire off two other observers:

```
// Observe collection changes
model.observeCollectionAdd(self, key: "collection") { (element: ElementType) in ... }
model.observeCollectionRemove(self, key: "collection") { (element: ElementType) in ... }
```
Callbacks fire immediately whenever an element is added or removed from the collection and the callback receives the element as an argument.

A very powerful feature is the ability to observe changes in the properties of a model object or **any** of it's children and its children's children. This is useful when your UI needs to re-render itself when a model object or any of its children 

```
// Observe changes of an entire model object and its children
model.observeTreeChange(self) { ... } // Tree has changed
```
Tree changes are always queued up as they would otherwise degrade performance.

Usually you're also interested whenever a model object is attached or detached from a scope. A model object is attached to a scope whenever it is inserted somewhere in a tree of model objects that have a scope. This might mean it's been added to a collection or assigned to a property of a parent model object that is part of a scope. A model object is detached when it loses its last parent with a scope (again, this might occur when the model object is removed from a collection or when the property of a parent model object is nilled out).

```
// Observe scope attachments and detachments
model.observeAttach(self) { (scope: Scope) in ... } // Attached to a scope
model.observeDettach(self) { (scope: Scope) in ... } // Detached to a scope
```
Attach and detach events traverse through all the children of the model object, so when you create a tree of model objects that have no scope and then attach the root of that tree to a parent with a scope, the whole tree would fire its attach observers.

Related, but slightly different is observing changes in parenting. Each model object with a scope has at least one parent (except for the root node), identified by a parent model object and a key which is the name of either the property or collection to which it has been attached to. A model object can have multiple parents. It might be mounted to properties of multiple parents, or it might be mounted on multiple different keys of the same parent model object. Whenever any changes in their parent relationships occur, you can observe these changes.

```
// Observe scope attachments and detachments
model.observeAddedToParent(self) { (parent: ModelObject, key: String) in ... } // Added to a parent
model.observeRemovedFromParent(self) { (parent: ModelObject, key:String) in ... } // Removed from a parent
```

## Scope
(Needs doc)

## Syncing
(Needs doc)

# Communication

- If you **found a bug**, open an issue or submit a fix via a pull request.
- If you **have a feature request**, open an issue or submit a implementation via a pull request.
- If you **want to contribute**, submit a pull request.

# License

Jetstream is released under the MIT license. See LICENSE for details.


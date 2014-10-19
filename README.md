Jetstream for iOS is an elegant MVVM model framework written in Swift. It includes support for the Jetstream Sync protocol to sync local and remote models. Out of the box it has a single Websocket transport adapter with the ability to add custom transport adapters.

## Features

- [x] Change observation
- [x] Fire-and-forget observation
- [x] Synchronization protocol to create multi-user applications
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

## Models
You create a model by subclassing ModelObject and defining properties of the model as `dynamic` variables. Getters, private variables and constants are not observed by the model.

Supported types are `String`, `UInt`, `Int`, `Float`, `Double`, `Bool`, `ModelObject`, `[ModelObject]`, `UIColor` and `NSDate`, `UInt8`, `Int8`, `UInt16`, `Int16`, `UInt32`, `Int32`

As Jetstream relies on Objective-C runtime to detect changes to properties only types that can be represented in Objective-C can be used as property types. Unfortunately Swift enums can not be represented in Objective-C and can thus not be used. To use enums types, declare them in a Objective-C header file.

## Observation
You have a number of methods to observe changes on model objects. Jetstream uses [Signals](http://github.com/artman/Signals) for all of its events. While you can subscribe to a number of signals that fire whenever changes occur on a model object, Jetstream provides a number observer methods that wrap around these signals to provide queueing and an even cleaner interface.

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

To unsubscribe from events you can either call `model.removeObserver(listener)` to remove all observations for a given listener, or you can use the function returned by all of the observer methods to cancel that specific observation:
```
// Cancel a single observation
var cancelObservation = model.observeTreeChange(self) { ... }
...
cancelObservation() // Cancels the observation
```

## Scope
### Reading changes from a scope
A scope wraps around a model tree and keeps tabs on what models have been added to the tree. It lets you access all models in the tree by UUID and lets you listen to changes that happen to all of your models as a digest of sync fragments. Sync fragments represent changes to the models in the scope and they come in three types:

* **Add**: Adds a new model to the scope
* **Remove**: Removes a model from the scope and all its parents
* **Change**: Updates properties on an existing model

When you make changes to models in a scope, add new models by assigning them to properties or collections or remove models by removing them from collections setting the property under which they are mounted to the tree to nil, the scope registers these changes and combines them to a number of sync fragments. You can listen to these changes by listening to the onChanges [signal](http://github.com/artman/Signals) on the scope:

```
// Listening to changes
scope.onChanges.listen(self) { fragments in
    // fragments is an Array of SyncFragments that describe the changes that happened
}
```
The onChanges signal fires whenever changes have been made to models in the tree. It queue up changes for a fraction of a second and deliver them all at once. The scope is intelligent enough to combine subsequent changes and deliver only required fragments. For example, if you add a model to a tree (resulting in an Add fragment) and immediately remove it from the tree (resulting in a Remove fragment), both fragments will cancel themselves out and neither one will be delivered on the onChanges signal.

### Applying changes to a scope
With the onChanges signal you can easily detect changes that happen on your local model. But you can also apply sync fragments to update your local model:

```
// Apply sync fragments
var fragments = [SyncFragments]()
...
scope.applySyncFragments(fragments) // Applies the changes to your model
```

Since SyncFragments can serialize themselves to a JSON-serializable dictionary using `syncFragment.serialize()` and unserialize themselves from a dictionary using `SyncFragment.unserialize(dictionary)`, you have an easy tool to build many kinds of extensions to Jetstream. For example, you could easily persist all the changes made to a scope by writing all sync fragments to disk, and on startup restore the previous state by reading the data from disk and apply them to the scope.

There's one particular built-in extension that makes great use of this functionality: Synchronization.

#Synchronization
Jetstream comes out of the box with a synchronization mechanism that lets you create multi-user applications in minutes.

(Some more about syncing here...)

# Communication

- If you **found a bug**, open an issue or submit a fix via a pull request.
- If you **have a feature request**, open an issue or submit a implementation via a pull request.
- If you **want to contribute**, submit a pull request.

# License

Jetstream is released under the MIT license. See LICENSE for details.


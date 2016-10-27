# IQCoreDataBrowser
IQCoreDataBrowser is a lightweight [UITableViewController](https://developer.apple.com/library/prerelease/ios/documentation/UIKit/Reference/UITableViewController_Class/index.html) subclass that lets the developer browse the Core Data context content. IQCoreDataBrowser is meant to be used while developing your app, not as part of it!

## Usage
### Instantiating IQCoreDataBrowser
Instantiate IQCoreDataBrowser with one of the following methods:
```objc
-(id)initWithContext:(NSManagedObjectContext*)moc;
``` 
Use this method to start browsing the context content at entity level. You get a list of entities and the number of entries for each. By selecting an entity, you go to the list entries for that entity. You can keep navigating the context by the relationships of your entities.
```objc
- (id)initWithTitle:(NSString*)title 
       fetchRequest:(NSFetchRequest*)fetchRequest
            context:(NSManagedObjectContext*)moc;
```
Use this method to browse the result of the `fetchRequest`. You can browse from there by the relationships of your entities.
```objc
- (id)initWithTitle:(NSString*)title
         entityName:(NSString*)entityName
          predicate:(NSPredicate*)predicate
            context:(NSManagedObjectContext*)moc;
```
Same as above but specifying the `entityName` and `predicate` instead of a `fetchRequest`.
```objc
- (id)initWithObject:(NSManagedObject*)object;
```
Use this method to display the detail view of the `object`. You can keep browsing by the relationships in your entities.
```objc
- (id)initWithTitle:(NSString*)title 
         objectList:(NSArray*)objects 
            context:(NSManagedObjectContext*)moc;
```
Displays the list of `objects`.

### Presenting IQCoreDataBrowser
Once created, you can present the instance of `IQCoreDataBrowser` by using the helper method:
```objc
- (void)presentFromViewController:(UIViewController*)vc;
```
Which just embeds it into a `UINavigationController` and presents the later from `vc`.

### Making objects more human friendly
By default, IQCoreDataBrowser uses the `objectID` and whatever attribute it things is your identifier (it takes the first indexed attribute) to display objects in lists. This can be not very useful for debugging. If you want to customize how your `NSManagedObject` subclasses are listed, just have them implement the `IQCoreDataBrowserProtocol`, which defines the following methods:
```objc
@protocol IQCoreDataBrowserProtocol <NSObject>
@optional
- (NSString*)coreDataBrowserTitle;
- (NSString*)coreDataBrowserDetail;
@end
```
Implementing those two methods will drastically improve the readability of the object listings.

### Example
Instantiating and presenting IQCOreDataBrowser:
```objc
#import <IQCoreDataBrowser.h>

- (void)debugAction:(id)sender {
  NSManagedObjectContext *moc = ...
  IQCoreDataBrowser *vc = [[IQCoreDataBrowser alloc] initWithContext:moc];
  [vc presentFromViewController:self];
}
```
## Installation with CocoaPods
[CocoaPods](http://cocoapods.org) is a dependency manager for Objective-C, which automates and simplifies the process of using 3rd-party libraries like AFNetworking in your projects.

### Podfile
```ruby
pod 'IQCoreDataBrowser', :git => 'https://github.com/InQBarna/iq-core-data-browser.git'
```

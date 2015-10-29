//
//  IQCoreDataBrowser.h
//
//  Created by David Romacho on 07/10/15.
//  Copyright © 2015 InQBarna Kenkyuu Jo. All rights reserved.
//

#import <CoreData/CoreData.h>
#import <UIKit/UIKit.h>

@protocol IQCoreDataBrowserProtocol <NSObject>
@optional
- (NSString*)coreDataBrowserTitle;
- (NSString*)coreDataBrowserDetail;
@end

@interface IQCoreDataBrowser : UITableViewController

- (id)initWithContext:(NSManagedObjectContext*)moc;

- (id)initWithTitle:(NSString*)title
       fetchRequest:(NSFetchRequest*)fetchRequest
            context:(NSManagedObjectContext*)moc;

- (id)initWithTitle:(NSString*)title
         entityName:(NSString*)entityName
          predicate:(NSPredicate*)predicate
            context:(NSManagedObjectContext*)moc;

- (id)initWithObject:(NSManagedObject*)object;

- (id)initWithTitle:(NSString*)title objectList:(NSArray*)objects context:(NSManagedObjectContext*)moc;

- (void)presentFromViewController:(UIViewController*)vc;
@end

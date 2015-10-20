//
//  IQCoreDataBrowser.m
//
//  Created by David Romacho on 07/10/15.
//  Copyright © 2015 InQBarna Kenkyuu Jo. All rights reserved.
//

#import "IQCoreDataBrowser.h"

typedef enum {
    IQCoreDataBrowserModeContext = 0,
    IQCoreDataBrowserModePredicate,
    IQCoreDataBrowserModeObjectList,
    IQCoreDataBrowserModeObject
} IQCoreDataBrowserMode;

@interface IQCoreDataBrowser ()<NSFetchedResultsControllerDelegate>
@property (nonatomic, assign) IQCoreDataBrowserMode         mode;
@property (nonatomic, strong) NSManagedObjectContext        *moc;
@property (nonatomic, strong) NSManagedObject               *object;
@property (nonatomic, strong) NSPredicate                   *predicate;
@property (nonatomic, strong) NSEntityDescription           *entityDescription;
@property (nonatomic, strong) NSArray                       *entities;
@property (nonatomic, strong) NSArray                       *objects;
@property (nonatomic, strong) NSArray                       *attributes;
@property (nonatomic, strong) NSArray                       *relationships;
@property (nonatomic, strong) NSFetchedResultsController    *fetchedResultsController;
@end

@implementation IQCoreDataBrowser

#pragma mark -
#pragma mark UIViewController methods

- (void)viewDidLoad
{
    [super viewDidLoad];
    if(self.navigationController.presentingViewController) {
        self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Done"
                                                                                 style:UIBarButtonItemStyleDone
                                                                                target:self
                                                                                 action:@selector(dismiss)];
    }
}

#pragma mark -
#pragma mark IQCoreDataBrowser methods

- (void)presentFromViewController:(UIViewController*)vc {
    UINavigationController *nc = [[UINavigationController alloc] initWithRootViewController:self];
    if(UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        nc.modalPresentationStyle = UIModalPresentationFormSheet;
    } else {
        nc.modalPresentationStyle = UIModalPresentationFullScreen;
    }

    [vc presentViewController:nc animated:YES completion:nil];
}

- (id)initWithContext:(NSManagedObjectContext*)moc
{
    NSParameterAssert(moc.persistentStoreCoordinator.managedObjectModel != nil);
    
    self = [self initWithStyle:UITableViewStylePlain];
    if(self) {
        self.title = @"Entities";
        self.mode = IQCoreDataBrowserModeContext;
        self.moc = moc;
        
        self.entities = [moc.persistentStoreCoordinator.managedObjectModel.entities sortedArrayUsingDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"name" ascending:YES]]];
    }
    return self;
}

- (id)initWithTitle:(NSString*)title
         entityName:(NSString*)entityName
          predicate:(NSPredicate*)predicate
            context:(NSManagedObjectContext*)moc
{
    NSParameterAssert(moc.persistentStoreCoordinator.managedObjectModel != nil);
    NSParameterAssert(entityName != nil);
    NSDictionary *tmp = [moc.persistentStoreCoordinator.managedObjectModel entitiesByName];
    NSEntityDescription *description = [tmp objectForKey:entityName];
    NSParameterAssert(description);
    
    self = [self initWithStyle:UITableViewStylePlain];
    if(self) {
        self.title = title;
        self.mode = IQCoreDataBrowserModePredicate;
        self.moc = moc;
        self.predicate = predicate;
        self.entityDescription = description;
        
        NSFetchRequest *fr = [NSFetchRequest fetchRequestWithEntityName:description.name];
        fr.predicate = predicate;
        
        NSString *keyPath = [self.class identifierKeyPathForEntityDescription:description];
        if(!keyPath) {
            NSAttributeDescription *d = description.attributesByName.allValues.firstObject;
            keyPath = d.name;
        }
        
        NSAssert(keyPath, @"Don't know how to sort entity '%@'", entityName);
        fr.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:keyPath ascending:YES]];
        
        self.fetchedResultsController = [[NSFetchedResultsController alloc] initWithFetchRequest:fr
                                                                            managedObjectContext:moc
                                                                              sectionNameKeyPath:nil
                                                                                       cacheName:nil];
        
        NSError *error = nil;
        if(![self.fetchedResultsController performFetch:&error]) {
            NSLog(@"%@", error);
        }
    }
    return self;
}

- (id)initWithTitle:(NSString*)title objectList:(NSArray*)objects context:(NSManagedObjectContext*)moc
{
    NSParameterAssert(moc.persistentStoreCoordinator.managedObjectModel != nil);
    
    self = [self initWithStyle:UITableViewStylePlain];
    if(self) {
        self.title = title;
        self.mode = IQCoreDataBrowserModeObjectList;
        self.moc = moc;
        self.objects = objects.copy;
    }
    return self;
}

- (id)initWithObject:(NSManagedObject*)object
{
    NSParameterAssert(object.managedObjectContext.persistentStoreCoordinator.managedObjectModel != nil);
    
    self = [self initWithStyle:UITableViewStylePlain];
    if(self) {
        self.title = [self titleForObject:object];
        self.mode = IQCoreDataBrowserModeObject;
        self.moc = object.managedObjectContext;
        self.object = object;
        self.entityDescription = object.entity;
        self.attributes = [self.entityDescription.attributesByName.allValues sortedArrayUsingDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"name" ascending:YES]]];
        
        self.relationships = [self.entityDescription.relationshipsByName.allValues sortedArrayUsingDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"name" ascending:YES]]];
    }
    return self;
}

- (void)configureCell:(UITableViewCell*)cell forEntity:(NSEntityDescription*)entityDescription
{
    // Set title
    cell.textLabel.text = entityDescription.name;
    
    // Set detail
    NSFetchRequest *fr = [NSFetchRequest fetchRequestWithEntityName:entityDescription.name];
    NSError *error = nil;
    NSUInteger count = [self.moc countForFetchRequest:fr error:&error];
    if(count != NSNotFound) {
        cell.detailTextLabel.text = [NSString stringWithFormat:@"%@ objects", @(count)];
        if(count) {
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        } else {
            cell.accessoryType = UITableViewCellAccessoryNone;
        }
        cell.detailTextLabel.textColor = [UIColor darkGrayColor];
    } else {
        cell.detailTextLabel.text = @"Error";
        cell.accessoryType = UITableViewCellAccessoryNone;
        cell.detailTextLabel.textColor = [UIColor redColor];
    }
}

- (void)configureCell:(UITableViewCell*)cell forObject:(NSManagedObject*)object
{
    // Set title
    cell.textLabel.text = [self titleForObject:object];
    cell.detailTextLabel.text = [self detailForObject:object];
    cell.detailTextLabel.textColor = [UIColor darkGrayColor];
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
}

- (void)configureCell:(UITableViewCell*)cell forAttribute:(NSAttributeDescription*)attribute
{
    id value = [self.object valueForKey:attribute.name];
    cell.textLabel.text = [NSString stringWithFormat:@"%@ (%@)",
                           attribute.name,
                           [self.class nameForAttributeType:attribute.attributeType]];
    
    if(value) {
        cell.detailTextLabel.text = [value description];
        cell.detailTextLabel.textColor = [UIColor darkGrayColor];
    } else {
        cell.detailTextLabel.text = @"nil";
        cell.detailTextLabel.textColor = [UIColor orangeColor];
    }

    cell.accessoryType = UITableViewCellAccessoryNone;
}

- (void)configureCell:(UITableViewCell*)cell forRelationship:(NSRelationshipDescription*)r
{
    cell.textLabel.text = r.name;
    
    id value = [self.object valueForKey:r.name];
    
    NSString *detail = r.toMany ? @"To Many " : @"To One ";
    detail = [detail stringByAppendingString:r.destinationEntity.name];
    NSUInteger count = 0;

    if(r.toMany) {
        if(r.ordered) {
            detail = [detail stringByAppendingString:@", Ordered"];
            NSOrderedSet *os = value;
            count = os.count;
        } else {
            NSSet *s = value;
            count = s.count;
        }
    } else {
        if(value) {
            count = 1;
        }
    }

    cell.accessoryType = UITableViewCellAccessoryNone;
    if(!value) {
        detail = [detail stringByAppendingString:@", nil"];
        cell.detailTextLabel.textColor = [UIColor orangeColor];
    } else {

        if(r.toMany) {
            detail = [detail stringByAppendingFormat:@", %@ objects", @(count).stringValue];
            if(count > 0) {
                cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            }
        } else {
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        }
        cell.detailTextLabel.textColor = [UIColor darkGrayColor];        
    }
    cell.detailTextLabel.text = detail;
}

- (UITableViewCell*)cellForIndexPath:(NSIndexPath*)indexPath inTableView:(UITableView*)tableView
{
    NSString *reuseIdentifier = @(self.mode).stringValue;
    UITableViewCell *result = [tableView dequeueReusableCellWithIdentifier:reuseIdentifier];
    if(!result) {
        result = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle
                                        reuseIdentifier:reuseIdentifier];
        
        result.textLabel.font = [UIFont systemFontOfSize:12.0f];
        result.detailTextLabel.font = [UIFont systemFontOfSize:10.0f];
    }
    
    return result;
}

- (NSString*)titleForObject:(NSManagedObject*)object
{
    NSString *result = nil;
    
    if([object respondsToSelector:@selector(coreDataBrowserTitle)]) {
        result = [(id<IQCoreDataBrowserProtocol>)object coreDataBrowserTitle];
    }
    
    if(!result) {
        NSString *keyPath = [self.class identifierKeyPathForEntityDescription:object.entity];
        if(keyPath) {
            id val = [object valueForKey:keyPath];
            
            if([val isKindOfClass:[NSString class]]) {
                result = val;
            }
            
            if([val respondsToSelector:@selector(stringValue)]) {
                result = [val stringValue];
            }
        }
    }
    
    if(!result) {
        result = object.objectID.URIRepresentation.absoluteString;
    }
    
    return result;
}

- (NSString*)detailForObject:(NSManagedObject*)object
{
    NSString *result = nil;
    
    if([object respondsToSelector:@selector(coreDataBrowserDetail)]) {
        result = [(id<IQCoreDataBrowserProtocol>)object coreDataBrowserDetail];
    }
    
    if(!result) {
        result = object.objectID.URIRepresentation.absoluteString;
    }
    
    return result;
}


+ (NSString*)identifierKeyPathForEntityDescription:(NSEntityDescription*)entityDescription
{
    NSSortDescriptor *sd = [NSSortDescriptor sortDescriptorWithKey:@"name" ascending:YES];
    NSArray *attributes = [entityDescription.attributesByName.allValues sortedArrayUsingDescriptors:@[sd]];
    
    for(NSAttributeDescription *a in attributes) {
        if(a.indexed) {
            if([a.attributeValueClassName isEqualToString:NSStringFromClass([NSString class])]) {
                return a.name;
            }
            if([a.attributeValueClassName isEqualToString:NSStringFromClass([NSNumber class])]) {
                return a.name;
            }
        }
    }
    
    return nil;
}

+ (NSString*)nameForAttributeType:(NSAttributeType)type {
    switch (type) {
        case NSUndefinedAttributeType: return @"Undefined";
        case NSInteger16AttributeType: return @"Integer 16";
        case NSInteger32AttributeType: return @"Integer 32";
        case NSInteger64AttributeType: return @"Integer 64";
        case NSDecimalAttributeType: return @"Decimal";
        case NSDoubleAttributeType: return @"Double";
        case NSFloatAttributeType: return @"Float";
        case NSStringAttributeType: return @"String";
        case NSBooleanAttributeType: return @"Boolean";
        case NSDateAttributeType: return @"Date";
        case NSBinaryDataAttributeType: return @"Binary Data";
        case NSTransformableAttributeType: return @"Transformable";
        case NSObjectIDAttributeType: return @"Object ID";
        default:
            NSAssert(NO, @"Unknown attribute type %@", @(type));
            return nil;
    }
}

- (void)dismiss {
    [self dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark -
#pragma mark UITableViewDataSource methods

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    switch (self.mode) {
        case IQCoreDataBrowserModeContext:
        case IQCoreDataBrowserModePredicate:
        case IQCoreDataBrowserModeObjectList: return 1;
        case IQCoreDataBrowserModeObject: return 2;
        default:
            NSAssert(NO, @"Unknown mode %@", @(self.mode));
            return 0;
    }
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    switch (self.mode) {
        case IQCoreDataBrowserModeContext: return self.entities.count;
        case IQCoreDataBrowserModePredicate: return self.fetchedResultsController.fetchedObjects.count;
        case IQCoreDataBrowserModeObjectList: return self.objects.count;
        case IQCoreDataBrowserModeObject: return (section == 0) ? self.attributes.count : self.relationships.count;

        default:
            NSAssert(NO, @"Unknown mode %@", @(self.mode));
            return 0;
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = [self cellForIndexPath:indexPath inTableView:tableView];
    
    switch (self.mode) {
        case IQCoreDataBrowserModeContext: {
            NSEntityDescription *d = [self.entities objectAtIndex:indexPath.row];
            [self configureCell:cell forEntity:d];
        } break;

        case IQCoreDataBrowserModePredicate: {
            NSManagedObject *o = [self.fetchedResultsController objectAtIndexPath:indexPath];
            [self configureCell:cell forObject:o];
        } break;
            
        case IQCoreDataBrowserModeObjectList: {
            NSManagedObject *o = [self.objects objectAtIndex:indexPath.row];
            [self configureCell:cell forObject:o];
        } break;
            
        case IQCoreDataBrowserModeObject: {
            if(indexPath.section == 0) {
                NSAttributeDescription *a = [self.attributes objectAtIndex:indexPath.row];
                [self configureCell:cell forAttribute:a];
            } else if(indexPath.section == 1) {
                NSRelationshipDescription *r = [self.relationships objectAtIndex:indexPath.row];
                [self configureCell:cell forRelationship:r];
            }
        } break;
            
        default:
            NSAssert(NO, @"Unknown mode %@", @(self.mode));
            break;
    }
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    IQCoreDataBrowser *vc = nil;
    switch (self.mode) {
        case IQCoreDataBrowserModeContext: {
            NSEntityDescription *e = [self.entities objectAtIndex:indexPath.row];
            vc = [[IQCoreDataBrowser alloc] initWithTitle:e.name
                                               entityName:e.name
                                                predicate:nil
                                                  context:self.moc];
        } break;
            
        case IQCoreDataBrowserModePredicate: {
            NSManagedObject *o = [self.fetchedResultsController objectAtIndexPath:indexPath];
            vc = [[IQCoreDataBrowser alloc] initWithObject:o];
        } break;

        case IQCoreDataBrowserModeObjectList: {
            NSManagedObject *o = [self.objects objectAtIndex:indexPath.row];
            vc = [[IQCoreDataBrowser alloc] initWithObject:o];
        } break;
            
        case IQCoreDataBrowserModeObject:
            if(indexPath.section == 1) { // relationships
                NSRelationshipDescription *r = [self.relationships objectAtIndex:indexPath.row];
                if(r.toMany) {
                    if(r.ordered) {
                        NSOrderedSet *os = [self.object valueForKey:r.name];
                        if(os.count) {
                            vc = [[IQCoreDataBrowser alloc] initWithTitle:r.name
                                                               objectList:os.array
                                                                  context:self.moc];
                        }
                    } else {
                        NSSet *s = [self.object valueForKey:r.name];
                        if(s.count) {
                            vc = [[IQCoreDataBrowser alloc] initWithTitle:r.name
                                                               objectList:s.allObjects
                                                                  context:self.moc];
                        }
                    }
                } else {
                    NSManagedObject *o = [self.object valueForKey:r.name];
                    if(o) {
                        vc = [[IQCoreDataBrowser alloc] initWithObject:o];
                    }
                }
            }
            break;
            
        default:
            NSAssert(NO, @"Unknown mode %@", @(self.mode));
            break;
    }
    
    if(vc) {
        [self.navigationController pushViewController:vc animated:YES];
    }
}

- (NSString*)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    switch (self.mode) {
        case IQCoreDataBrowserModeObject:
            return (section == 0) ? @"Attributes" : @"Relationships";
            break;
            
        default:
            return nil;
    }
}

@end

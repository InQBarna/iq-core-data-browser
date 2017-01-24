//
// Author: David Romacho <david.romacho@inqbarna.com>
//
// Copyright (c) 2016 InQBarna Kenkyuu Jo (http://inqbarna.com/)
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

#import "IQCoreDataBrowser.h"

typedef enum {
    IQCoreDataBrowserModeContext = 0,
    IQCoreDataBrowserModePredicate,
    IQCoreDataBrowserModeObjectList,
    IQCoreDataBrowserModeObject
} IQCoreDataBrowserMode;

NS_ASSUME_NONNULL_BEGIN
@interface IQCoreDataBrowser ()<NSFetchedResultsControllerDelegate, UISearchBarDelegate>
@property (nonatomic) IQCoreDataBrowserMode                 mode;
@property (nonatomic, nullable) NSManagedObjectContext      *moc;
@property (nonatomic, nullable) NSManagedObject             *object;
@property (nonatomic, nullable) NSFetchRequest              *fetchRequest;
@property (nonatomic, nullable) NSEntityDescription         *entityDescription;
@property (nonatomic, nullable) NSArray                     *entities;
@property (nonatomic, nullable) NSMutableArray              *objects;
@property (nonatomic, nullable) NSArray                     *attributes;
@property (nonatomic, nullable) NSArray                     *relationships;
@property (nonatomic, nullable) NSFetchedResultsController  *fetchedResultsController;
@property (nonatomic, nullable) UISearchBar                 *searchBar;
@property (nonatomic, nullable) NSNumberFormatter           *numberFormatter;
@end
NS_ASSUME_NONNULL_END

@implementation IQCoreDataBrowser

#pragma mark -
#pragma mark NSObject methods

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark -
#pragma mark UIViewController methods

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    if(self.mode != IQCoreDataBrowserModeObjectList) {
        UISearchBar *searchBar = [[UISearchBar alloc] initWithFrame:CGRectMake(0.0f, 0.0f, self.tableView.frame.size.width, 44.0f)];
        searchBar.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        searchBar.delegate = self;
        searchBar.keyboardType = UIKeyboardTypeDefault;
        searchBar.autocapitalizationType = UITextAutocapitalizationTypeNone;
        self.tableView.tableHeaderView = searchBar;
        self.searchBar = searchBar;
    }
    
    [self reloadTableView];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    if(self.navigationController.presentingViewController) {
        UIBarButtonItem *item = [[UIBarButtonItem alloc] initWithTitle:@"Done"
                                                                 style:UIBarButtonItemStyleDone
                                                                target:self
                                                                action:@selector(dismiss)];
        self.navigationItem.rightBarButtonItem = item;
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
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(reloadTableView)
                                                     name:NSManagedObjectContextObjectsDidChangeNotification
                                                   object:moc];
    }
    return self;
}

- (id)initWithTitle:(NSString*)title
       fetchRequest:(NSFetchRequest*)fetchRequest
            context:(NSManagedObjectContext*)moc
{
    NSParameterAssert(moc.persistentStoreCoordinator.managedObjectModel != nil);
    NSParameterAssert(fetchRequest != nil);
    NSParameterAssert(fetchRequest.entityName);
    
    NSString *entityName = fetchRequest.entityName;
    NSDictionary *entitiesByName = [moc.persistentStoreCoordinator.managedObjectModel entitiesByName];
    NSEntityDescription *entityDescription = [entitiesByName objectForKey:entityName];
    NSAssert(entityDescription, @"No NSEntityDescription for '%@'", entityName);
    
    self = [self initWithStyle:UITableViewStylePlain];
    if(self) {
        self.title = title;
        self.mode = IQCoreDataBrowserModePredicate;
        self.moc = moc;
        self.fetchRequest = fetchRequest;
        self.entityDescription = entityDescription;
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
    NSDictionary *entitiesByName = [moc.persistentStoreCoordinator.managedObjectModel entitiesByName];
    NSEntityDescription *entityDescription = [entitiesByName objectForKey:entityName];
    NSAssert(entityDescription, @"No NSEntityDescription for '%@'", entityName);
    
    NSString *keyPath = [self.class identifierKeyPathForEntityDescription:entityDescription];
    if(!keyPath) {
        NSAttributeDescription *d = entityDescription.attributesByName.allValues.firstObject;
        keyPath = d.name;
    }
    
    NSAssert(keyPath, @"Don't know how to sort entity '%@'", entityName);
    NSArray *sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:keyPath ascending:YES]];
    
    NSFetchRequest *fetchRequest = [NSFetchRequest fetchRequestWithEntityName:entityDescription.name];
    fetchRequest.predicate = predicate;
    fetchRequest.sortDescriptors = sortDescriptors;
    
    return [self initWithTitle:title fetchRequest:fetchRequest context:moc];
}

- (id)initWithTitle:(NSString*)title
         objectList:(NSArray<NSManagedObject*>*)objects
            context:(NSManagedObjectContext*)moc
{
    NSParameterAssert(moc.persistentStoreCoordinator.managedObjectModel != nil);
    
    self = [self initWithStyle:UITableViewStylePlain];
    if(self) {
        self.title = title;
        self.mode = IQCoreDataBrowserModeObjectList;
        self.moc = moc;
        self.objects = objects.mutableCopy;
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(reloadTableView)
                                                     name:NSManagedObjectContextObjectsDidChangeNotification
                                                   object:moc];
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
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(reloadTableView)
                                                     name:NSManagedObjectContextObjectsDidChangeNotification
                                                   object:self.moc];
    }
    return self;
}

- (NSPredicate*)searchPredicateForEntity:(NSEntityDescription*)entity text:(NSString*)text
{
    if(!self.numberFormatter) {
        self.numberFormatter = [[NSNumberFormatter alloc] init];
        self.numberFormatter.numberStyle = NSNumberFormatterDecimalStyle;
    }
    NSNumber *numericValue = [self.numberFormatter numberFromString:text];
    
    if(text.length) {
        NSMutableArray *predicates = [NSMutableArray array];
        for(NSAttributeDescription *ad in entity.attributesByName.allValues) {
            if(ad.attributeType == NSStringAttributeType) {
                NSPredicate *p = [NSPredicate predicateWithFormat:@"%K CONTAINS[cd] %@", ad.name, text];
                if(p) {
                    [predicates addObject:p];
                }
            } else if(numericValue) {
            
                NSNumber *value;
                
                if(ad.attributeType == NSInteger16AttributeType) {
                    value = @(numericValue.shortValue);
                } else if(ad.attributeType == NSInteger32AttributeType) {
                    value = @(numericValue.integerValue);
                } else if(ad.attributeType == NSInteger64AttributeType) {
                    value = @(numericValue.unsignedLongLongValue);
                } else if(ad.attributeType == NSDoubleAttributeType) {
                    value = @(numericValue.doubleValue);
                } else if(ad.attributeType == NSFloatAttributeType) {
                    value = @(numericValue.floatValue);
                }
                
                if(value) {
                    NSPredicate *p = [NSPredicate predicateWithFormat:@"%K == %@", ad.name, value];
                    [predicates addObject:p];
                }
            }
        }
        
        if(predicates.count) {
            NSPredicate *result = [NSCompoundPredicate orPredicateWithSubpredicates:predicates];
            return result;
        }
    }
    
    return nil;
}

- (NSEntityDescription*)entityWithName:(NSString*)entityName
{
    NSAssert(entityName, @"No entity name provided");
    NSEntityDescription *entity = [self.moc.persistentStoreCoordinator.managedObjectModel.entitiesByName objectForKey:entityName];
    
    NSAssert(entity, @"Could not find entity with name '%@'", entityName);
    return entity;
}

- (void)reloadTableView
{
    NSString *searchText = self.searchBar.text;
    
    switch (self.mode) {
        case IQCoreDataBrowserModeContext: {
            NSArray *entities = [self.moc.persistentStoreCoordinator.managedObjectModel.entities sortedArrayUsingDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"name" ascending:YES]]];
            
            if(searchText.length) {
                NSPredicate *p = [NSPredicate predicateWithFormat:@"%K CONTAINS[cd] %@", @"name", searchText];
                entities = [entities filteredArrayUsingPredicate:p];
            }
            self.entities = entities;
        } break;
            
        case IQCoreDataBrowserModePredicate: {
            
            NSFetchRequest *fetchRequest = [self.fetchRequest copy];
            NSEntityDescription *entity = [self entityWithName:fetchRequest.entityName];
            NSPredicate *filter = [self searchPredicateForEntity:entity text:searchText];
            
            if(fetchRequest.predicate) {
                filter = [NSCompoundPredicate andPredicateWithSubpredicates:@[filter, fetchRequest.predicate]];
            } else {
                fetchRequest.predicate = filter;
            }
            
            self.fetchedResultsController = [[NSFetchedResultsController alloc] initWithFetchRequest:fetchRequest
                                                                                managedObjectContext:self.moc
                                                                                  sectionNameKeyPath:nil
                                                                                           cacheName:nil];
            self.fetchedResultsController.delegate = self;
            
            NSError *error = nil;
            if(![self.fetchedResultsController performFetch:&error]) {
                NSLog(@"%@", error);
            }
        } break;
            
        case IQCoreDataBrowserModeObjectList: {
        } break;
            
        case IQCoreDataBrowserModeObject: {
            
            NSArray<NSAttributeDescription*> *attributes = [self.entityDescription.attributesByName.allValues sortedArrayUsingDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"name" ascending:YES]]];
            
            NSArray<NSRelationshipDescription*> *relationships = [self.entityDescription.relationshipsByName.allValues sortedArrayUsingDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"name" ascending:YES]]];
            
            if(searchText.length) {
                NSPredicate *p = [NSPredicate predicateWithFormat:@"%K CONTAINS[cd] %@", @"name" , searchText];
                
                relationships = [relationships filteredArrayUsingPredicate:p];
                
                NSMutableArray *tmp = [NSMutableArray array];
                
                [attributes enumerateObjectsUsingBlock:^(NSAttributeDescription * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop)
                 {
                     if([p evaluateWithObject:obj]) {
                         [tmp addObject:obj];
                         
                     } else if(obj.attributeType == NSStringAttributeType) {
                         NSString *value = [self.object valueForKey:obj.name];
                         if([value isKindOfClass:[NSString class]]) {
                             NSRange range = [value rangeOfString:searchText
                                                          options:NSCaseInsensitiveSearch | NSDiacriticInsensitiveSearch];
                             if(range.location != NSNotFound) {
                                 [tmp addObject:obj];
                             }
                         }
                     } else if(obj.attributeType == NSInteger16AttributeType ||
                               obj.attributeType == NSInteger32AttributeType ||
                               obj.attributeType == NSInteger64AttributeType ||
                               obj.attributeType == NSDoubleAttributeType ||
                               obj.attributeType == NSFloatAttributeType)
                     {
                         NSNumber *value = [self.object valueForKey:obj.name];
                         if([value isKindOfClass:[NSNumber class]]) {
                             NSRange range = [value.stringValue rangeOfString:searchText
                                                                      options:NSCaseInsensitiveSearch | NSDiacriticInsensitiveSearch];
                             if(range.location != NSNotFound) {
                                 [tmp addObject:obj];
                             }
                         }
                     }
                 }];
                
                attributes = tmp.copy;
            }
            self.attributes = attributes;
            self.relationships = relationships;
        } break;
            
        default:
            break;
    }
    
    [self.tableView reloadData];
    
    if(self.mode == IQCoreDataBrowserModeObject) {
        self.title = [self titleForObject:self.object];
    }
}

- (NSAttributedString*)highlightText:text
{
    NSMutableAttributedString *result = [[NSMutableAttributedString alloc] initWithString:text
                                                                               attributes:@{NSForegroundColorAttributeName : [UIColor blackColor]}];
    
    if(self.searchBar.text) {
        NSRange range = [text rangeOfString:self.searchBar.text options:NSCaseInsensitiveSearch];
        if(range.location != NSNotFound) {
            [result addAttributes:@{NSForegroundColorAttributeName : [UIColor blueColor]} range:range];
        }
    }
    
    return result;
}

- (void)configureCell:(UITableViewCell*)cell forEntity:(NSEntityDescription*)entityDescription
{
    // Set title
    cell.textLabel.attributedText = [self highlightText:entityDescription.name];
    
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
    cell.textLabel.attributedText = [self highlightText:[self titleForObject:object]];
    
    // Set detail
    cell.detailTextLabel.textColor = [UIColor darkGrayColor];
    cell.detailTextLabel.attributedText = [self highlightText:[self detailForObject:object]];
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
}

- (void)configureCell:(UITableViewCell*)cell forAttribute:(NSAttributeDescription*)attribute
{
    id value = [self.object valueForKey:attribute.name];
    NSString *title = [NSString stringWithFormat:@"%@ (%@)",
                       attribute.name,
                       [self.class nameForAttributeType:attribute.attributeType]];
    cell.textLabel.attributedText = [self highlightText:title];
    
    if(value) {
        cell.detailTextLabel.textColor = [UIColor darkGrayColor];
        cell.detailTextLabel.attributedText = [self highlightText:[value description]];
        
    } else {
        cell.detailTextLabel.textColor = [UIColor orangeColor];
        cell.detailTextLabel.text = @"nil";
    }
    
    cell.accessoryType = UITableViewCellAccessoryNone;
}

- (void)configureCell:(UITableViewCell*)cell forRelationship:(NSRelationshipDescription*)r
{
    cell.textLabel.attributedText = [self highlightText:r.name];
    
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

- (void)saveContext {
    NSError *error = nil;
    if (![self.moc save:&error]) {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Could not save context" message:error.localizedDescription preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
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
            } else if (self.allowsEditing) { // attributes
                NSAttributeDescription *attribute = self.attributes[indexPath.row];
                NSAttributeType type = attribute.attributeType;
                
                // integer, decimal, double, float, string, boolean
                if (type >= NSInteger16AttributeType && type <= NSBooleanAttributeType)
                {
                    NSString *title = [NSString stringWithFormat:@"Value for '%@'", attribute.name];
                    
                    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title message:nil preferredStyle:UIAlertControllerStyleAlert];
                    
                    [alert addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
                        if (type >= NSInteger16AttributeType && type <= NSInteger64AttributeType || type == NSBooleanAttributeType)
                        {
                            textField.keyboardType = UIKeyboardTypeNumberPad;
                        }
                        else if (type >= NSDecimalAttributeType && type <= NSFloatAttributeType)
                        {
                            textField.keyboardType = UIKeyboardTypeDecimalPad;
                        }
                        
                        id value = [self.object valueForKey:attribute.name];
                        textField.text = [NSString stringWithFormat:@"%@", value];
                    }];
                    
                    [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                        NSString *text = alert.textFields[0].text;
                        if (type >= NSInteger16AttributeType && type <= NSInteger64AttributeType)
                        {
                            NSNumber *number = @([text longLongValue]);
                            [self.object setValue:number forKey:attribute.name];
                        }
                        else if (type >= NSDecimalAttributeType && type <= NSFloatAttributeType)
                        {
                            NSNumber *number = @([text doubleValue]);
                            [self.object setValue:number forKey:attribute.name];
                        }
                        else if (type == NSStringAttributeType)
                        {
                            [self.object setValue:text forKey:attribute.name];
                        }
                        else if (type == NSBooleanAttributeType)
                        {
                            NSNumber *number = @([text boolValue]);
                            [self.object setValue:number forKey:attribute.name];
                        }
                        [self saveContext];
                    }]];
                    
                    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
                    
                    [self presentViewController:alert animated:YES completion:nil];
                }
                
                [tableView deselectRowAtIndexPath:indexPath animated:YES];
            }
            break;
            
        default:
            NSAssert(NO, @"Unknown mode %@", @(self.mode));
            break;
    }
    
    if(vc) {
        vc.allowsEditing = self.allowsEditing;
        [self.navigationController pushViewController:vc animated:YES];
    }
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    return (self.mode == IQCoreDataBrowserModePredicate || self.mode == IQCoreDataBrowserModeObjectList);
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    switch (self.mode) {
        case IQCoreDataBrowserModeContext:
        case IQCoreDataBrowserModeObject:
            // not deletable
            break;
            
        case IQCoreDataBrowserModePredicate: {
            NSManagedObject *o = [self.fetchedResultsController objectAtIndexPath:indexPath];
            if (editingStyle == UITableViewCellEditingStyleDelete) {
                [self.moc deleteObject:o];
                [self saveContext];
                // NSFetchResultsController will update table
            }
        } break;
            
        case IQCoreDataBrowserModeObjectList: {
            NSManagedObject *o = self.objects[indexPath.row];
            if (editingStyle == UITableViewCellEditingStyleDelete) {
                [self.moc deleteObject:o];
                [self saveContext];
                // no NSFetchResultsController to update table, done by code
                [self.objects removeObject:o];
                [self.tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
                
/*
                UIAlertController *alert = [UIAlertController alertControllerWithTitle:[self titleForObject:o] message:nil preferredStyle:UIAlertControllerStyleAlert];
                
                [alert addAction:[UIAlertAction actionWithTitle:@"Remove from Relationship" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                    //TODO
                    self.tableView.editing = NO;
                }]];

                [alert addAction:[UIAlertAction actionWithTitle:@"Delete Object" style:UIAlertActionStyleDestructive handler:^(UIAlertAction * _Nonnull action) {
                    [self.moc deleteObject:o];
                    [self.objects removeObject:o];
                    [self.tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
                    self.tableView.editing = NO;
                }]];
                
                [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {
                    self.tableView.editing = NO;
                }]];

                [self presentViewController:alert animated:YES completion:nil];
*/
            }
        } break;
            
        default:
            NSAssert(NO, @"Unknown mode %@", @(self.mode));
            break;
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

#pragma mark - NSFetchedResultsControllerDelegate methods

- (void)controllerWillChangeContent:(NSFetchedResultsController *)controller
{
    [self.tableView beginUpdates];
}

- (void)controller:(NSFetchedResultsController *)controller
   didChangeObject:(id)anObject
       atIndexPath:(NSIndexPath *)indexPath
     forChangeType:(NSFetchedResultsChangeType)type
      newIndexPath:(NSIndexPath *)newIndexPath
{
    UITableView *tableView = self.tableView;
    
    switch(type) {
            
        case NSFetchedResultsChangeInsert:
            [tableView insertRowsAtIndexPaths:@[newIndexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
            break;
            
        case NSFetchedResultsChangeDelete: {
            [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
        } break;
            
        case NSFetchedResultsChangeUpdate:
            [tableView reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
            break;
            
        case NSFetchedResultsChangeMove:
            if([indexPath isEqual:newIndexPath]) {
                break;
            }
            [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
            [tableView insertRowsAtIndexPaths:@[newIndexPath] withRowAnimation:UITableViewRowAnimationFade];
            break;
    }
}

- (void)controller:(NSFetchedResultsController *)controller
  didChangeSection:(id )sectionInfo
           atIndex:(NSUInteger)sectionIndex
     forChangeType:(NSFetchedResultsChangeType)type
{
}

- (void)controllerDidChangeContent:(NSFetchedResultsController *)controller
{
    [self.tableView endUpdates];
}

#pragma mark -
#pragma mark UISearchBarDelegate methods

// called when text ends editing
- (void)searchBarTextDidEndEditing:(UISearchBar *)searchBar
{
    [self reloadTableView];
}

// called when text changes (including clear)
- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText
{
    [self reloadTableView];
}

// called before text changes
- (BOOL)searchBar:(UISearchBar *)searchBar shouldChangeTextInRange:(NSRange)range replacementText:(NSString *)text
{
    return YES;
}

// called when keyboard search button pressed
- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar
{
    [self reloadTableView];
}

// called when cancel button pressed
- (void)searchBarCancelButtonClicked:(UISearchBar *)searchBar
{
    searchBar.text = nil;
    [self reloadTableView];
}

@end

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
@property (nonatomic, assign) IQCoreDataBrowserMode                 mode;
@property (nonatomic, strong, nullable) NSManagedObjectContext      *moc;
@property (nonatomic, strong, nullable) NSManagedObject             *object;
@property (nonatomic, strong, nullable) NSFetchRequest              *fetchRequest;
@property (nonatomic, strong, nullable) NSEntityDescription         *entityDescription;
@property (nonatomic, strong, nullable) NSArray                     *entities;
@property (nonatomic, copy,   nullable) NSArray                     *objects;
@property (nonatomic, copy,   nullable) NSArray                     *allObjects;
@property (nonatomic, copy,   nullable) NSArray                     *attributes;
@property (nonatomic, copy,   nullable) NSArray                     *relationships;
@property (nonatomic, strong, nullable) NSFetchedResultsController  *fetchedResultsController;
@property (nonatomic, strong, nullable) UISearchBar                 *searchBar;
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
        self.allObjects = objects;
        
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
    if(text.length) {
        NSMutableArray *predicates = [NSMutableArray array];
        for(NSAttributeDescription *ad in entity.attributesByName.allValues) {
            if(ad.attributeType == NSStringAttributeType) {
                NSPredicate *p = [NSPredicate predicateWithFormat:@"%K CONTAINS[cd] %@", ad.name, text];
                if(p) {
                    [predicates addObject:p];
                }
            } else if(ad.attributeType == NSInteger16AttributeType ||
                      ad.attributeType == NSInteger32AttributeType ||
                      ad.attributeType == NSInteger64AttributeType ||
                      ad.attributeType == NSDoubleAttributeType ||
                      ad.attributeType == NSFloatAttributeType) {
                NSPredicate *p = [NSPredicate predicateWithFormat:@"%K CONTAINS[cd] %@", ad.name, text];
                if(p) {
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
            
            NSError *error = nil;
            if(![self.fetchedResultsController performFetch:&error]) {
                NSLog(@"%@", error);
            }
        } break;
            
        case IQCoreDataBrowserModeObjectList: {
            self.objects = self.allObjects;
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

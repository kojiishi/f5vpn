//
//  SCNetworkSetArrayController.m
//  f5vpn
//
//  Created by Koji Ishii on 9/7/13.
//  Copyright (c) 2013 Koji Ishii. All rights reserved.
//

#import "SCNetworkSetArrayController.h"

@implementation SCNetworkSetArrayController

- (id)init {
    self = [super init];
    [self updateObjects];
    return self;
}

- (void)awakeFromNib {
    [self updateObjects];
}

- (void)updateObjects {
    SCPreferencesRef prefs = SCPreferencesCreate(NULL, CFSTR("SystemConfiguration"), NULL);
    NSArray* locations = (__bridge NSArray*)SCNetworkSetCopyAll(prefs);
    for (id item in locations) {
        SCNetworkSetRef networkSet = (__bridge SCNetworkSetRef)item;
        NSString *name = (__bridge NSString *)SCNetworkSetGetName(networkSet);
        [self addObject:[NSDictionary dictionaryWithObjectsAndKeys:
            item, @"key", name, @"name", nil]];
        NSLog(@"Location=%@", name);
    }
    CFRelease((__bridge CFArrayRef)locations);
    CFRelease(prefs);
}

- (NSString *)selectedName {
    for (NSDictionary* value in self.selectedObjects) {
        NSString* name = [value valueForKey:@"name"];
        return name;
    }
    return nil;
}

- (void)setSelectedName:(NSString *)name {
    int count = 0;
    for (NSDictionary* value in self.selectedObjects) {
        NSString* name1 = [value valueForKey:@"name"];
        if ([name isEqualToString:name1]) {
            self.selectionIndex = count;
            return;
        }
        count++;
    }
}

@end

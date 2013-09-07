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

- (SCNetworkSetRef)selectedSCNetworkSet {
    for (NSDictionary* value in self.selectedObjects) {
        return (__bridge SCNetworkSetRef)[value valueForKey:@"key"];
    }
    return nil;    
}

- (NSString *)selectedName {
    for (NSDictionary* value in self.selectedObjects) {
        NSString* name = [value valueForKey:@"name"];
        return name;
    }
    return nil;
}

- (void)setSelectedName:(NSString *)name {
    NSLog(@"setSelectedName:%@", name);
    int count = 0;
    for (NSDictionary* value in self.content) {
        NSString* name1 = [value valueForKey:@"name"];
        if ([name isEqualToString:name1]) {
            self.selectionIndex = count;
            return;
        }
        count++;
    }
}

- (void)setCurrentNetworkSet {
#ifdef DOES_NOT_WORK
    SCNetworkSetRef networkSet = self.selectedSCNetworkSet;
    if (!networkSet)
        return;
    NSLog(@"SCNetworkSetSetCurrent:%@", SCNetworkSetGetName(networkSet));
    if (!SCNetworkSetSetCurrent(networkSet))
        NSLog(@"Cannot set current NetworkSet");
#else
    NSString* name = self.selectedName;
    NSLog(@"SCNetworkSetSetCurrent:%@", name);
    NSTask* task = [[NSTask alloc] init];
    task.launchPath = @"/usr/sbin/scselect";
    task.arguments = [NSArray arrayWithObjects:name, nil];
    [task launch];
    [task waitUntilExit];
#endif
}

@end

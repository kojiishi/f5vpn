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

#define USE_SCSELECT
// SCNetworkSetSetCurrent does not work (probably) unless setsid'ed

- (void)setCurrentNetworkSet {
#ifdef USE_SCSELECT
    [self setCurrentNetworkSetName:self.selectedName];
#else
    [self setCurrentNetworkSet:self.selectedSCNetworkSet];
#endif
}

- (void)setCurrentNetworkSet:(SCNetworkSetRef)networkSet {
    if (!networkSet)
        return;
#ifdef USE_SCSELECT
    [self setCurrentNetworkSetName:(__bridge NSString *)SCNetworkSetGetName(networkSet)];
#else
    NSLog(@"SCNetworkSetSetCurrent:%@", SCNetworkSetGetName(networkSet));
    if (!SCNetworkSetSetCurrent(networkSet))
        NSLog(@"Cannot set current NetworkSet");
#endif
}

- (void)setCurrentNetworkSetName:(NSString *)name {
    NSLog(@"SCNetworkSetSetCurrent:%@", name);
#ifdef USE_SCSELECT
    NSTask* task = [[NSTask alloc] init];
    task.launchPath = @"/usr/sbin/scselect";
    task.arguments = [NSArray arrayWithObjects:name, nil];
    [task launch];
    [task waitUntilExit];
#else
#endif
}

@end

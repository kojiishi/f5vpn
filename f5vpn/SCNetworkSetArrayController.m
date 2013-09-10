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
    CFArrayRef locations = SCNetworkSetCopyAll(prefs);
    for (id item in (__bridge NSArray*)locations) {
        SCNetworkSetRef networkSet = (__bridge SCNetworkSetRef)item;
        NSString *name = (__bridge NSString *)SCNetworkSetGetName(networkSet);
        [self addObject:name];
        NSLog(@"Location=%@", name);
    }
    CFRelease(locations);
    CFRelease(prefs);
}

- (NSString *)selectedName {
    for (NSString* name in self.selectedObjects)
        return name;
    return nil;
}

- (void)setSelectedName:(NSString *)name {
    NSUInteger index = [self.content indexOfObject:name];
    NSLog(@"setSelectedName:%@ (%ld)", name, (unsigned long)index);
    if (index == NSNotFound)
        return;
    self.selectionIndex = index;
}

// SCNetworkSetSetCurrent does not work (probably) unless setsid'ed
#define USE_SCSELECT

- (void)setCurrentNetworkSet {
#ifdef USE_SCSELECT
    [SCNetworkSetArrayController setCurrentNetworkSetName:self.selectedName];
#else
    [self setCurrentNetworkSet:self.selectedSCNetworkSet];
#endif
}

+ (NSString *)currentNetworkSetName {
    SCPreferencesRef prefs = SCPreferencesCreate(NULL, CFSTR("SystemConfiguration"), NULL);
    SCNetworkSetRef networkSet = SCNetworkSetCopyCurrent(prefs);
    NSString *name = (__bridge NSString*)SCNetworkSetGetName(networkSet);
    NSLog(@"Current=%@", name);
    CFRelease(networkSet);
    CFRelease(prefs);
    return name;
}

+ (void)setCurrentNetworkSetName:(NSString *)name {
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

//
//  AppDelegate.m
//  f5vpn
//
//  Created by Koji Ishii on 9/7/13.
//  Copyright (c) 2013 Koji Ishii. All rights reserved.
//

#import "AppDelegate.h"

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    [_appController loadPrefs];
}

@end

//
//  AppDelegate.m
//  f5vpn
//
//  Created by Koji Ishii on 9/7/13.
//  Copyright (c) 2013 Koji Ishii. All rights reserved.
//

#import "AppDelegate.h"

@implementation AppDelegate

#define LoginURLKey @"LoginURL"

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    [self login];
}

- (void)login
{
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    NSURL* url = [defaults URLForKey:LoginURLKey];
    if (!url) {
        NSString* urlString = @"http://www.apple.com";
        url = [NSURL URLWithString:urlString];
        [defaults setURL:url forKey:LoginURLKey];
    }
}

- (void)webView:(WebView *)sender didFinishLoadForFrame:(WebFrame *)frame
{
    NSLog(@"didFinishLoadForFrame");
}

@end

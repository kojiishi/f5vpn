//
//  AppDelegate.m
//  f5vpn
//
//  Created by Koji Ishii on 9/7/13.
//  Copyright (c) 2013 Koji Ishii. All rights reserved.
//

#import "AppDelegate.h"
#include <SystemConfiguration/SCNetworkConfiguration.h>

@implementation AppDelegate

#define LoginURLKey @"LoginURL"

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    [self login];
    [self updateNetworkSetList];
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

    NSURLRequest* req = [NSURLRequest requestWithURL:url];
    [[self.webView mainFrame] loadRequest:req];
}

- (void)webView:(WebView *)sender didFinishLoadForFrame:(WebFrame *)frame
{
    NSLog(@"didFinishLoadForFrame");

    // Fill authentication form
    DOMDocument *dom = [sender mainFrameDocument];
    DOMElement *form = [dom getElementById:@"auth_form"];
    if (form) {
        DOMElement *user = [dom getElementById:@"input_1"];
        DOMElement *pwd = [dom getElementById:@"input_2"];
        if (user && pwd) {
            [user setAttribute:@"value" value:NSUserName()];
            [pwd focus];
        }
        return;
    }

    [self updateStatus:dom];
}

- (void)updateStatus:(DOMDocument *)dom {
    DOMElement *status = [dom getElementById:@"status"];
    if (!status)
        return;
    NSString *text = [status innerText];
    NSLog(@"Status=%@", text);
}

- (void)updateNetworkSetList {
    SCPreferencesRef prefs = SCPreferencesCreate(NULL, CFSTR("SystemConfiguration"), NULL);
    NSArray* locations = (__bridge NSArray*)SCNetworkSetCopyAll(prefs);
    for (id item in locations) {
        SCNetworkSetRef networkSet = (__bridge SCNetworkSetRef)item;
        NSString *name = (__bridge NSString *)SCNetworkSetGetName(networkSet);
        [self.networkSetList addObject:[NSDictionary dictionaryWithObjectsAndKeys:
            item, @"key", name, @"name", nil]];
        NSLog(@"Location=%@", name);
    }
    CFRelease((__bridge CFArrayRef)locations);
    CFRelease(prefs);
}

@end

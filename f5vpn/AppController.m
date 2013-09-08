//
//  AppController.m
//  f5vpn
//
//  Created by Koji Ishii on 9/7/13.
//  Copyright (c) 2013 Koji Ishii. All rights reserved.
//

#import "AppController.h"

#define LoginURLKey @"LoginURL"
#define NetworkSetKey @"Location"

@implementation AppController

- (void)awakeFromNib
{
    [self login];
}

- (void)loadPrefs {
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    NSString* networkSetName = [defaults stringForKey:NetworkSetKey];
    if (networkSetName)
        self.networkSetList.selectedName = networkSetName;
}

- (void)savePrefs {
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    [defaults setValue:self.networkSetList.selectedName forKey:NetworkSetKey];
}

- (void)login
{
    NSURLRequest* req = [NSURLRequest requestWithURL:[self loginURL]];
    [[self.webView mainFrame] loadRequest:req];
}

- (NSURL*)loginURL
{
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    NSURL* url = [defaults URLForKey:LoginURLKey];
    if (url)
        return url;
    NSString* urlString = [defaults stringForKey:LoginURLKey];
    if (!urlString)
        urlString = @"http://www.apple.com";
    url = [NSURL URLWithString:urlString];
    [defaults setURL:url forKey:LoginURLKey];
    return url;
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

- (void)updateStatus {
    DOMDocument *dom = [self.webView mainFrameDocument];
    [self updateStatus:dom];
}

- (void)updateStatus:(DOMDocument *)dom {
    NSLog(@"updateStatus");
    if (statusTimer) {
        [statusTimer invalidate];
        statusTimer = nil;
    }
    
    DOMElement *status = [dom getElementById:@"status"];
    if (!status)
        return;

    NSString *text = [status innerText];
    NSLog(@"Status=%@", text);
    if ([text isEqualToString:@"Connected"] == YES) {
        NSLog(@"Connected");
        if (!isConnected) {
            isConnected = true;
            networkSetBeforeConnected = [SCNetworkSetArrayController currentNetworkSetName];
            [self.networkSetList setCurrentNetworkSet];
        }
        return;
    }
    
    NSTimer* timer = [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(updateStatus) userInfo:nil repeats:NO];
    statusTimer = timer;
}

- (void)disconnect {
    if (networkSetBeforeConnected) {
        [SCNetworkSetArrayController setCurrentNetworkSetName:networkSetBeforeConnected];
        networkSetBeforeConnected = nil;
    }
}

@end

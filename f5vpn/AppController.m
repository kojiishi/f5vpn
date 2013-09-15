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
{
    NSStatusItem* statusItem;
    NSString* networkSetBeforeConnected;
    BOOL isStatusEventListenerAttached;
    BOOL isConnected;
}

- (void)awakeFromNib
{
    [self login];
}

- (void)loadPrefs {
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    NSString* networkSetName = [defaults stringForKey:NetworkSetKey];
    if (networkSetName)
        _networkSetList.selectedName = networkSetName;
}

- (void)savePrefs {
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    [defaults setValue:_networkSetList.selectedName forKey:NetworkSetKey];
}

- (void)login
{
    [self login:nil];
}

- (IBAction)login:(id)sender {
    NSURLRequest* req = [NSURLRequest requestWithURL:[self loginURL]];
    [[_webView mainFrame] loadRequest:req];
}

- (NSURL*)loginURL
{
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    NSURL* url = [defaults URLForKey:LoginURLKey];
    if (url)
        return url;
    NSString* urlString = [defaults stringForKey:LoginURLKey];
    if (urlString)
        return [NSURL URLWithString:urlString];
    url = [[NSBundle mainBundle] URLForResource:@"NoURL" withExtension:@"html"];
//    [defaults setURL:url forKey:LoginURLKey];
    return url;
}

- (void)disconnect
{
    // This method does not disconnect--ok for now as far as applicationWillTerminate is the only caller
    [self didDisconnect];
}

- (void)webView:(WebView *)sender didStartProvisionalLoadForFrame:(WebFrame *)frame
{
    NSLog(@"didStartProvisionalLoadForFrame");
    [_progressIndicator startAnimation:self];
}

- (void)webView:(WebView *)sender didReceiveTitle:(NSString *)title forFrame:(WebFrame *)frame
{
    NSLog(@"didReceiveTitle(%@)", title);
}

- (void)webView:(WebView *)sender didFailProvisionalLoadWithError:(NSError *)error forFrame:(WebFrame *)frame
{
    NSLog(@"didFailProvisionalLoadWithError");
    [self showError:error];
}

- (void)webView:(WebView *)sender didFailLoadWithError:(NSError *)error forFrame:(WebFrame *)frame
{
    NSLog(@"didFailLoadWithError");
    [self showError:error];
}

- (void)webView:(WebView *)sender didFinishLoadForFrame:(WebFrame *)frame
{
    NSLog(@"didFinishLoadForFrame");
    [_progressIndicator stopAnimation:self];
    isStatusEventListenerAttached = NO;

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
    
    DOMElement *status = [dom getElementById:@"status"];
    if (!status)
        return;

    if (!isStatusEventListenerAttached) {
        NSLog(@"addEventListener");
        [status addEventListener:@"DOMSubtreeModified" listener:self useCapture:YES];
        isStatusEventListenerAttached = YES;
    }

    NSString *statusText = [status innerText];
    NSLog(@"Status=%@", statusText);

    if (!statusItem)
        statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength];
    [statusItem setTitle:statusText];

    if ([statusText isEqualToString:@"Connected"])
        [self didConnect];
    else if ([statusText isEqualToString:@"Disconnected"])
        [self didDisconnect];
}

- (void)handleEvent:(DOMEvent *)evt;
{
    NSLog(@"handleEvent");
    [self updateStatus];
}

- (void)didConnect {
    NSLog(@"Connected");
    if (isConnected)
        return;
    isConnected = YES;
    networkSetBeforeConnected = [SCNetworkSetArrayController currentNetworkSetName];
    [self.networkSetList setCurrentNetworkSet];
}

- (void)didDisconnect {
    NSLog(@"Disconnected");
    isConnected = NO;
    if (networkSetBeforeConnected) {
        [SCNetworkSetArrayController setCurrentNetworkSetName:networkSetBeforeConnected];
        networkSetBeforeConnected = nil;
    }
}

- (void)showError:(NSError*)error
{
    [_progressIndicator stopAnimation:self];
    [[NSAlert alertWithError:error] beginSheetModalForWindow:_window modalDelegate:nil didEndSelector:nil contextInfo:nil];
}

@end

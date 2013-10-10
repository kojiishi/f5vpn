//
//  AppController.m
//  f5vpn
//
//  Created by Koji Ishii on 9/7/13.
//  Copyright (c) 2013 Koji Ishii. All rights reserved.
//

#import "AppController.h"
#import <CoreWLAN/CoreWLAN.h>

//#define ENABLE_StatusItem
#define LoginURLKey @"LoginURL"
#define EnableNetworkSetKey @"EnableLocation"
#define NetworkSetDefaultKey @"LocationDefault"
#define NetworkSetVPNKey @"LocationVPN"
#define NetworkSetSSIDKeyFormat @"LocationSSID%@"

@implementation AppController
{
#ifdef ENABLE_StatusItem
    NSStatusItem* statusItem;
#endif
    BOOL isStatusEventListenerAttached;
    BOOL isConnected;
    NSArray* _interfaces;
    SCNetworkReachabilityRef _reachabilityRef;
    dispatch_queue_t _reachabilityQueue;
}

- (void)awakeFromNib
{
    NSLog(@"awakeFromNib");
    [self observeWifi];
    [self login];
}

- (void)windowWillClose:(NSNotification*)notification
{
    NSLog(@"windowWillClose");
    [self didDisconnect];
    [self savePrefs];
}

- (void)loadPrefs
{
    NSLog(@"loadPrefs");
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    self.isLocationEnabled.state = [defaults boolForKey:EnableNetworkSetKey] ? NSOnState : NSOffState;
    [self updateLocation];
}

- (void)savePrefs
{
    NSLog(@"savePrefs");
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    [defaults setBool:(self.isLocationEnabled.state == NSOnState) forKey:EnableNetworkSetKey];
    [self saveLocation];
}

- (void)login
{
    [self login:nil];
}

- (IBAction)login:(id)sender
{
    NSURL* url = [self loginURL];
    if (!url.isFileURL && !_reachabilityRef) {
        [self observeReachability:url];
        if (![self isLoginReachable])
            return;
    }
    NSURLRequest* req = [NSURLRequest requestWithURL:url];
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
    [_progressIndicator stopAnimation:self];
    [self showError:error];
}

- (void)webView:(WebView *)sender didFailLoadWithError:(NSError *)error forFrame:(WebFrame *)frame
{
    NSLog(@"didFailLoadWithError");
    [_progressIndicator stopAnimation:self];
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
            [self didReadyToLogin];
        }
        return;
    }
    
    [self updateConnectionStatus:dom];
}

- (void)updateConnectionStatus {
    DOMDocument *dom = [self.webView mainFrameDocument];
    [self updateConnectionStatus:dom];
}

- (void)updateConnectionStatus:(DOMDocument *)dom {
    NSLog(@"updateConnectionStatus");
    
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

#ifdef ENABLE_StatusItem
    if (!statusItem)
        statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength];
    [statusItem setTitle:statusText];
#endif

    if ([statusText isEqualToString:@"Connected"])
        [self didConnect];
    else if ([statusText isEqualToString:@"Disconnected"])
        [self didDisconnect];
}

- (void)handleEvent:(DOMEvent *)evt;
{
    NSLog(@"handleEvent");
    [self updateConnectionStatus];
}

- (void)didReadyToLogin
{
    [self notifyState:@"Ready to login" networkSetName:nil];
}

- (void)didConnect {
    NSLog(@"Connected");
    if (isConnected)
        return;

    [self saveLocation];
    isConnected = YES;
    [self updateLocationWithState:@"Connected"];
}

- (void)didDisconnect {
    NSLog(@"Disconnected");
    if (!isConnected)
        return;

    [self saveLocation];
    isConnected = NO;
    [self updateLocationWithState:@"Disconnected"];
}

- (void)updateLocationWithState:(NSString*)state
{
    NSString* networkSetName = [self updateLocation];
    [self notifyState:state networkSetName:networkSetName];
}

- (NSString*)updateLocation
{
    if (self.isLocationEnabled.state != NSOnState)
        return nil;

    NSString* key = self.currentLocationKey;
    if (!key)
        return nil;

    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    NSString* networkSetName = [defaults stringForKey:key];
    NSLog(@"updateLocation: %@=%@", key, networkSetName);
    if (!networkSetName)
        return nil;
    if ([networkSetName isEqualToString:[SCNetworkSetArrayController currentNetworkSetName]])
        return nil;

    [SCNetworkSetArrayController setCurrentNetworkSetName:networkSetName];
    return networkSetName;
}

- (void)saveLocation
{
    if (self.isLocationEnabled.state != NSOnState)
        return;

    NSString* key = self.currentLocationKey;
    if (!key)
        return;

    NSString* networkSetName = [SCNetworkSetArrayController currentNetworkSetName];
    if (!networkSetName)
        return;

    NSLog(@"saveLocation: %@=%@", key, networkSetName);
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    [defaults setValue:networkSetName forKey:key];
}

- (NSString*)currentLocationKey
{
    if (isConnected)
        return NetworkSetVPNKey;

    CWInterface* interface = [CWInterface interface];
    if (interface && interface.serviceActive) {
        NSString* ssid = interface.ssid;
        if (ssid)
            return [NSString stringWithFormat:NetworkSetSSIDKeyFormat, ssid];
    }

    return NetworkSetDefaultKey;
}

- (void)observeWifi
{
    NSNotificationCenter* center = [NSNotificationCenter defaultCenter];
    [center addObserver:self selector:@selector(SSIDDidChange:) name:CWSSIDDidChangeNotification object:nil];

    // For CoreWLAN to send notifications, we need to hold open CWInterface instances.
    // http://stackoverflow.com/questions/15047338/is-there-a-nsnotificationcenter-notification-for-wifi-network-changes

    NSSet* interfaceNames = [CWInterface interfaceNames];
    NSMutableArray* interfaces = [[NSMutableArray alloc] initWithCapacity:[interfaceNames count]];
    for (NSString* name in interfaceNames) {
        NSLog(@"CWInterface: %@", name);
        CWInterface* interface = [CWInterface interfaceWithName:name];
        if (interface)
            [interfaces addObject:interface];
    }
    _interfaces = [interfaces copy];
}

- (void)SSIDDidChange:(NSNotification*)notification
{
    NSLog(@"SSIDDidChange");
    [self updateLocationWithState:@"Wi-Fi network changed"];
}

- (void)notifyState:(NSString*)state networkSetName:(NSString*)networkSetName
{
    NSUserNotification* notification = [[NSUserNotification alloc] init];
    notification.title = state;
    if (networkSetName)
        notification.subtitle = [NSString stringWithFormat:@"Location changed to %@", networkSetName];
    [[NSUserNotificationCenter defaultUserNotificationCenter] deliverNotification:notification];
}

#pragma mark - Reachability

- (BOOL)isLoginReachable
{
    NSAssert(_reachabilityRef, @"reachabilityRef");
    SCNetworkReachabilityFlags flags;
    if (!SCNetworkReachabilityGetFlags(_reachabilityRef, &flags)) {
        NSLog(@"SCNetworkReachabilityGetFlags failed");
        return NO;
    }
    NSLog(@"SCNetworkReachabilityGetFlags=%x", flags);
    return (flags & kSCNetworkReachabilityFlagsReachable);
}

- (void)reachabilityChanged:(SCNetworkReachabilityFlags)flags
{
    NSLog(@"reachabilityChanged: %x", flags);
    if (flags & kSCNetworkReachabilityFlagsReachable)
        [self login];
}

static void reachabilityCallback(SCNetworkReachabilityRef target, SCNetworkReachabilityFlags flags, void* info)
{
    AppController* me = (__bridge AppController*)info;
    [me reachabilityChanged:flags];
}

- (void)observeReachability:(NSURL*)url
{
    NSString* host = url.host;
    _reachabilityRef = SCNetworkReachabilityCreateWithName(NULL, [host UTF8String]);
    if (!_reachabilityRef) {
        NSLog(@"SCNetworkReachabilityCreateWithName failed: %@", host);
        return; // TODO
    }

    _reachabilityQueue = dispatch_queue_create("ec.koji.f5vpn.reachability", NULL);
    if (!_reachabilityQueue) {
        NSLog(@"dispatch_queue_create failed");
        return; // TODO
    }

    if (!SCNetworkReachabilitySetDispatchQueue(_reachabilityRef, _reachabilityQueue)) {
        NSLog(@"SCNetworkReachabilitySetDispatchQueue failed");
        return; // TODO
    }

    SCNetworkReachabilityContext context = { 0, NULL, NULL, NULL, NULL };
    context.info = (__bridge void*)self;
    if (!SCNetworkReachabilitySetCallback(_reachabilityRef, reachabilityCallback, &context)) {
        NSLog(@"SCNetworkReachabilitySetCallback failed");
        return; // TODO
    }
}

#pragma mark - Utilities

- (void)showError:(NSError*)error
{
    [[NSAlert alertWithError:error] beginSheetModalForWindow:_window modalDelegate:nil didEndSelector:nil contextInfo:nil];
}

@end

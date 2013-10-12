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

typedef NS_ENUM(NSUInteger, VPNConnectionState) {
    Disconnected,
    LoginPrompted,
    Connecting,
    Connected,
};

@implementation AppController
{
    NSStatusItem* statusItem;
    BOOL isStatusEventListenerAttached;
    VPNConnectionState _connectionState;
    SCNetworkReachabilityFlags _reachabilityFlags;
    NSDate* _unreachableSince;
    NSArray* _interfaces;
    SCNetworkReachabilityRef _reachabilityRef;
}

- (void)awakeFromNib
{
    NSLog(@"awakeFromNib");
}

- (void)loadPrefs
{
    NSLog(@"loadPrefs");
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    self.isLocationEnabled.state = [defaults boolForKey:EnableNetworkSetKey] ? NSOnState : NSOffState;
    [self updateLocation];
    [self observeWifi];
    [self loginIfReachable];
}

- (void)savePrefs
{
    NSLog(@"savePrefs");
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    [defaults setBool:(self.isLocationEnabled.state == NSOnState) forKey:EnableNetworkSetKey];
    [self saveLocation];
}

- (void)windowWillClose:(NSNotification*)notification
{
    NSLog(@"windowWillClose");
    [self didDisconnect];
    [self savePrefs];
}

#pragma mark - Login

- (IBAction)login:(id)sender
{
    [self login];
}

- (void)loginIfReachable
{
    NSURL* url = [self loginURL];
    if (!url.isFileURL && !_reachabilityRef) {
        [self observeReachability:url];
        if (![self isReachable])
            return;
    }
    [self loginWithUrl:url];
}

- (void)login
{
    [self loginWithUrl:[self loginURL]];
}

- (void)loginWithUrl:(NSURL*)url
{
    NSLog(@"Login %@", url);
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

- (void)disconnect
{
    [self didDisconnect];
    [[_webView mainFrame] loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:@"about:blank"]]];
}

#pragma mark - WebView events

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
    NSLog(@"didFailProvisionalLoadWithError: %@", error);
    [_progressIndicator stopAnimation:self];
    if (error.domain == NSURLErrorDomain && error.code == NSURLErrorNotConnectedToInternet) { // The Internet connection appears to be offline.
        [self disconnect];
        return;
    }
    [self showError:error];
}

- (void)webView:(WebView *)sender didFailLoadWithError:(NSError *)error forFrame:(WebFrame *)frame
{
    NSLog(@"didFailLoadWithError: %@", error);
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
    if (!status) {
        [self didDisconnect];
        return;
    }

    if (!isStatusEventListenerAttached) {
        NSLog(@"addEventListener");
        [status addEventListener:@"DOMSubtreeModified" listener:self useCapture:YES];
        isStatusEventListenerAttached = YES;
    }

    NSString *statusText = [status innerText];
    NSLog(@"Status=%@", statusText);

    if ([statusText isEqualToString:@"Connected"])
        [self didConnect];
    else if ([statusText isEqualToString:@"Disconnected"])
        [self didDisconnect];
    else
        [self didConnecting];
}

- (void)handleEvent:(DOMEvent *)evt;
{
    NSLog(@"handleEvent");
    [self updateConnectionStatus];
}

#pragma mark - Connection States

- (void)didReadyToLogin
{
    [self didChangeConnectionState:LoginPrompted];
}

- (void)didConnecting
{
    [self didChangeConnectionState:Connecting];
}

- (void)didConnect
{
    [self didChangeConnectionState:Connected];
}

- (void)didDisconnect
{
    [self didChangeConnectionState:Disconnected];
}

- (void)didChangeConnectionState:(VPNConnectionState)connectionState
{
    NSLog(@"didChangeConnectionState:%u", (unsigned)connectionState);
    if (_connectionState == connectionState)
        return;

    [self saveLocation];
    _connectionState = connectionState;
    NSString* networkSetName = [self updateLocation];
    [self notifyState:connectionState networkSetName:networkSetName];
}

#pragma mark - Locations (NetworkSets)

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
    if (_connectionState == Connected)
        return NetworkSetVPNKey;

    CWInterface* interface = [CWInterface interface];
    if (interface && interface.serviceActive) {
        NSString* ssid = interface.ssid;
        if (ssid)
            return [NSString stringWithFormat:NetworkSetSSIDKeyFormat, ssid];
    }

    return NetworkSetDefaultKey;
}

#pragma mark - Wi-Fi

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
    [self updateLocation];
}

#pragma mark - Reachability

- (void)reachabilityChanged:(SCNetworkReachabilityFlags)flags
{
    NSLog(@"reachabilityChanged: %x (was %x), connection=%u", flags, _reachabilityFlags, (unsigned)_connectionState);
    NSAssert(_reachabilityRef, @"observeReachability was stopped");

    SCNetworkReachabilityFlags changes = flags ^ _reachabilityFlags;
    _reachabilityFlags = flags;

    if (!(changes & kSCNetworkReachabilityFlagsReachable))
        return;
    if (!(flags & kSCNetworkReachabilityFlagsReachable)) {
        _unreachableSince = [NSDate date];
        return;
    }

    // Ignore short period of time.
    // Short off and on can happen while connecting to VPN,
    // or when changing Locations.
    if (_unreachableSince) {
        NSTimeInterval interval = [_unreachableSince timeIntervalSinceNow];
        NSLog(@"Was unreachable for %lf seconds", -interval);
        if (interval >= -10)
            return;
    }

    [self login];
}

static void reachabilityCallback(SCNetworkReachabilityRef target, SCNetworkReachabilityFlags flags, void* info)
{
    AppController* me = (__bridge AppController*)info;
    [me reachabilityChanged:flags];
}

- (void)observeReachability:(NSURL*)url
{
    NSLog(@"observeReachability %@", url);
    NSAssert(!_reachabilityRef, @"reachabilityRef");

    NSString* host = url.host;
    _reachabilityRef = SCNetworkReachabilityCreateWithName(NULL, [host UTF8String]);
    if (!_reachabilityRef) {
        NSLog(@"SCNetworkReachabilityCreateWithName failed: %@", host);
        return;
    }

    // Get and save the current flags to detect changes correctly.
    SCNetworkReachabilityFlags flags;
    if (!SCNetworkReachabilityGetFlags(_reachabilityRef, &flags))
        NSLog(@"SCNetworkReachabilityGetFlags failed");
    NSLog(@"isReachable=%x", flags);
    _reachabilityFlags = flags;

    if (!SCNetworkReachabilitySetDispatchQueue(_reachabilityRef, dispatch_get_main_queue())) {
        NSLog(@"SCNetworkReachabilitySetDispatchQueue failed");
        return; // TODO
    }

    SCNetworkReachabilityContext context = { 0, (__bridge void*)self, NULL, NULL, NULL };
    if (!SCNetworkReachabilitySetCallback(_reachabilityRef, reachabilityCallback, &context)) {
        NSLog(@"SCNetworkReachabilitySetCallback failed");
        return; // TODO
    }
}

- (void)stopObserveReachability
{
    NSLog(@"stopObserveReachability");
    if (!_reachabilityRef)
        return;

    SCNetworkReachabilitySetDispatchQueue(_reachabilityRef, NULL);

    CFRelease(_reachabilityRef);
    _reachabilityRef = NULL;
}

- (BOOL)isReachable
{
    NSAssert(_reachabilityRef, @"_reachabilityRef");
    return _reachabilityFlags & kSCNetworkReachabilityFlagsReachable;
}

#pragma mark - Utilities

- (void)notifyState:(VPNConnectionState)state networkSetName:(NSString*)networkSetName
{
    if (!statusItem)
        statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength];
    NSUserNotification* notification = [[NSUserNotification alloc] init];
    switch (state) {
        case Disconnected:
            [statusItem setTitle:@"🔴"];
            notification.title = @"Disconnected";
            break;
        case LoginPrompted:
            [statusItem setTitle:@"\u2753"]; // BLACK QUESTION MARK ORNAMENT
            notification.title = @"Ready to Login";
            break;
        case Connecting:
            [statusItem setTitle:@"🌀"];
            notification.title = @"Connecting...";
            break;
        case Connected:
            [statusItem setTitle:@"🔵"];
            notification.title = @"Connected";
            break;
        default:
            NSAssert(NO, @"state=%u", (unsigned)state);
            break;
    }

    if (networkSetName)
        notification.subtitle = [NSString stringWithFormat:@"Location changed to %@", networkSetName];
    [[NSUserNotificationCenter defaultUserNotificationCenter] deliverNotification:notification];
}

- (void)showError:(NSError*)error
{
    [[NSAlert alertWithError:error] beginSheetModalForWindow:_window modalDelegate:nil didEndSelector:nil contextInfo:nil];
}

@end

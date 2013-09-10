//
//  AppController.h
//  f5vpn
//
//  Created by Koji Ishii on 9/7/13.
//  Copyright (c) 2013 Koji Ishii. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <WebKit/WebKit.h>
#import "SCNetworkSetArrayController.h"

@interface AppController : NSObject {
    NSTimer* statusTimer;
    BOOL isConnected;
    NSString* networkSetBeforeConnected;
}

@property (unsafe_unretained) IBOutlet NSWindow *window;
@property (weak) IBOutlet WebView *webView;
@property (weak) IBOutlet NSProgressIndicator *progressIndicator;
@property (weak) IBOutlet SCNetworkSetArrayController *networkSetList;
- (IBAction)login:(id)sender;
- (void)loadPrefs;
- (void)savePrefs;
- (void)disconnect;

@end

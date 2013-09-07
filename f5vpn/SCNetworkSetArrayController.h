//
//  SCNetworkSetArrayController.h
//  f5vpn
//
//  Created by Koji Ishii on 9/7/13.
//  Copyright (c) 2013 Koji Ishii. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#include <SystemConfiguration/SCNetworkConfiguration.h>

@interface SCNetworkSetArrayController : NSArrayController

- (SCNetworkSetRef)selectedSCNetworkSet;
@property (retain) NSString* selectedName;

- (void)setCurrentNetworkSet;
- (void)setCurrentNetworkSet:(SCNetworkSetRef)networkSet;
- (void)setCurrentNetworkSetName:(NSString*)name;

@end

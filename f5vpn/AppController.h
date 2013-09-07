//
//  AppController.h
//  f5vpn
//
//  Created by Koji Ishii on 9/7/13.
//  Copyright (c) 2013 Koji Ishii. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <WebKit/WebKit.h>

@interface AppController : NSObject

@property (weak) IBOutlet WebView *webView;
@property (weak) IBOutlet NSArrayController *networkSetList;

@end

//
//  AppDelegate.m
//  Replica
//
//  Created by h4ck on 18/11/1.
//  Copyright © 2018年 字节时代（https://byteage.com） All rights reserved.
//

#import "AppDelegate.h"

@interface AppDelegate ()

@property (weak) IBOutlet NSWindow *window;
@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    // Insert code here to initialize your application
    NSDictionary *info = [[NSBundle mainBundle]infoDictionary];
    NSString *title = [NSString stringWithFormat:@"Replica %@ (Build %@)",info[@"CFBundleShortVersionString"],info[@"CFBundleVersion"]];
    [self.window setTitle:title];
}

- (void)applicationWillTerminate:(NSNotification *)aNotification {
    // Insert code here to tear down your application
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender
{
    return YES;
}

@end

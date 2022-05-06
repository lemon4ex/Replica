//
//  NSSavePanel+Replica.h
//  Replica
//
//  Created by h4ck on 18/11/3.
//  Copyright © 2018年 字节时代（https://byteage.com） All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface NSSavePanel (Replica)
+ (void)showSavePanelModal:(NSString *)nameValue message:(NSString *)message fileTypes:(NSArray *)fileTypes canCreateDirectories:(BOOL)canCreateDirectories completionHandler:(void (^)(NSSavePanel *panel,NSInteger result))completionHandler;
@end

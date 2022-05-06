//
//  NSOpenPanel+Replica.h
//  Replica
//
//  Created by h4ck on 18/11/3.
//  Copyright © 2018年 字节时代（https://byteage.com） All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface NSOpenPanel (Replica)
+ (void)showOpenPanelModal:(NSString *)directory message:(NSString *)message fileTypes:(NSArray *)fileTypes multipleSelection:(BOOL)multipleSelection canChooseDirectories:(BOOL)canChooseDirectories canChooseFiles:(BOOL)canChooseFiles canCreateDirectories:(BOOL)canCreateDirectories completionHandler:(void (^)(NSOpenPanel *panel,NSInteger result))completionHandler;
@end

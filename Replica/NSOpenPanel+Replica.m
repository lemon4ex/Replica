//
//  NSOpenPanel+Replica.m
//  Replica
//
//  Created by h4ck on 18/11/3.
//  Copyright © 2018年 字节时代（https://byteage.com） All rights reserved.
//

#import "NSOpenPanel+Replica.h"

@implementation NSOpenPanel (Replica)
+ (void)showOpenPanelModal:(NSString *)directory message:(NSString *)message fileTypes:(NSArray *)fileTypes multipleSelection:(BOOL)multipleSelection canChooseDirectories:(BOOL)canChooseDirectories canChooseFiles:(BOOL)canChooseFiles canCreateDirectories:(BOOL)canCreateDirectories completionHandler:(void (^)(NSOpenPanel *panel,NSInteger result))completionHandler
{
    NSOpenPanel *panel = [NSOpenPanel openPanel];
    [panel setDirectory:directory];
    panel.message = message;
    [panel setAllowsMultipleSelection:multipleSelection];
    [panel setCanChooseDirectories:canChooseDirectories];
    [panel setCanChooseFiles:canChooseFiles];
    [panel setAllowedFileTypes:fileTypes];
    [panel setAllowsOtherFileTypes:NO];
    [panel setCanCreateDirectories:canCreateDirectories];
    NSInteger result = [panel runModal];
    completionHandler(panel,result);
}
@end

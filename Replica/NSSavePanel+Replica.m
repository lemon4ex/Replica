//
//  NSSavePanel+Replica.m
//  Replica
//
//  Created by h4ck on 18/11/3.
//  Copyright © 2018年 字节时代（https://byteage.com） All rights reserved.
//

#import "NSSavePanel+Replica.h"

@implementation NSSavePanel (Replica)
+ (void)showSavePanelModal:(NSString *)nameValue message:(NSString *)message fileTypes:(NSArray *)fileTypes canCreateDirectories:(BOOL)canCreateDirectories completionHandler:(void (^)(NSSavePanel *panel,NSInteger result))completionHandler
{
    NSSavePanel *panel = [NSSavePanel savePanel];
    [panel setNameFieldStringValue:nameValue];
    [panel setMessage:message];
    [panel setAllowsOtherFileTypes:NO];
    [panel setAllowedFileTypes:fileTypes];
    [panel setExtensionHidden:NO];
    [panel setCanCreateDirectories:canCreateDirectories];
    NSInteger result = [panel runModal];
    completionHandler(panel,result);
}
@end

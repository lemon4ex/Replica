//
//  ShellExecute.m
//  Replica
//
//  Created by h4ck on 18/11/3.
//  Copyright © 2018年 字节时代（https://byteage.com） All rights reserved.
//

#import "ShellExecute.h"

@implementation ShellExecute
+ (RETaskOutput *)installXcodeCLI{
    return [NSTask execute:@"/usr/bin/xcode-select" workingDirectory:nil arguments:@[@"--install"]];
}

+ (BOOL)checkXcodeCLI {
    if ([NSTask execute:@"/usr/bin/xcode-select" workingDirectory:nil arguments:@[@"-p"]].status != 0) {
        return NO;
    }
    
    return YES;
}

+ (NSString *)makeTempFolder{
    RETaskOutput *tempTask = [NSTask execute:@"/usr/bin/mktemp" workingDirectory:nil arguments:@[@"-d",@"-t",[NSBundle mainBundle].bundleIdentifier]];
    if(tempTask.status != 0) {
        return nil;
    }
    return [tempTask.output stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

+ (BOOL)codesign:(NSString *)file certificate:(NSString *)certificate entitlements:(NSString *)entitlements beforeBlock:(BOOL(^)(NSString *file,NSString *certificate,NSString *entitlements))beforeBlock afterBlock:(BOOL(^)(NSString *file,NSString *certificate,NSString *entitlements,RETaskOutput *taskOutput))afterBlock
{
    if (beforeBlock && !beforeBlock(file,certificate,entitlements)) {
        return NO;
    }
    NSMutableArray *arguments = [NSMutableArray arrayWithArray:@[@"-vvv",@"-fs",certificate,@"--no-strict"]];
    if([[NSFileManager defaultManager]fileExistsAtPath:entitlements]) {
        [arguments addObject:[NSString stringWithFormat:@"--entitlements=%@",entitlements]];
    }
    [arguments addObject:file];
    RETaskOutput *output = [NSTask execute:@"/usr/bin/codesign" workingDirectory:nil arguments:arguments];
    if (afterBlock) {
        return afterBlock(file,certificate,entitlements,output);
    }

    return (output.status == 0);
}
@end

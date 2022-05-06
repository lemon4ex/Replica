//
//  ShellExecute.h
//  Replica
//
//  Created by h4ck on 18/11/3.
//  Copyright © 2018年 字节时代（https://byteage.com） All rights reserved.
//

#import <Foundation/Foundation.h>
#import "NSTask+Replica.h"

@interface ShellExecute : NSObject
+ (RETaskOutput *)installXcodeCLI;
+ (BOOL)checkXcodeCLI;
+ (NSString *)makeTempFolder;
+ (BOOL)codesign:(NSString *)file certificate:(NSString *)certificate entitlements:(NSString *)entitlements beforeBlock:(BOOL(^)(NSString *file,NSString *certificate,NSString *entitlements))beforeBlock afterBlock:(BOOL(^)(NSString *file,NSString *certificate,NSString *entitlements,RETaskOutput *taskOutput))afterBlock;
@end

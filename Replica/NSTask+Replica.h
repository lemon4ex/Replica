//
//  NSTask+Replica.h
//  Replica
//
//  Created by h4ck on 18/11/1.
//  Copyright © 2018年 字节时代（https://byteage.com） All rights reserved.
//

#import <Foundation/Foundation.h>

@interface RETaskOutput : NSObject
@property (nonatomic) NSInteger status;
@property (nonatomic) NSString *output;
@end

@interface NSTask (Replica)
- (RETaskOutput *)launchSyncronous;
+ (RETaskOutput *)execute:(NSString *)launchPath workingDirectory:(NSString *)workingDirectory arguments:(NSArray *)arguments;
@end

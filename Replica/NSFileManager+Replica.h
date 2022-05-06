//
//  NSFileManager+Replica.h
//  Replica
//
//  Created by h4ck on 18/11/1.
//  Copyright © 2018年 字节时代（https://byteage.com） All rights reserved.
//

#import <Foundation/Foundation.h>

typedef BOOL (^FindRuleBlock)(NSString *path,BOOL isDirectory);
typedef BOOL (^FoundFileBlock)(NSString *path,BOOL isDirectory);

@interface NSFileManager (Replica)
+ (BOOL)recursiveDirectorySearch:(NSString *)path findRuleBlock:(FindRuleBlock)findRuleBlock foundFileBlock:(FoundFileBlock)foundFileBlock;
+ (BOOL)recursiveDirectorySearch:(NSString *)path extensions:(NSArray *)extensions specificFiles:(NSArray *)specificFiles foundFileBlock:(FoundFileBlock)foundFileBlock;
@end

//
//  NSFileManager+Replica.m
//  Replica
//
//  Created by h4ck on 18/11/1.
//  Copyright © 2018年 字节时代（https://byteage.com） All rights reserved.
//

#import "NSFileManager+Replica.h"

@implementation NSFileManager (Replica)

+ (BOOL)recursiveDirectorySearch:(NSString *)path findRuleBlock:(FindRuleBlock)findRuleBlock foundFileBlock:(FoundFileBlock)foundFileBlock{
    NSFileManager *fileManager = [self defaultManager];
    NSArray *files = [fileManager contentsOfDirectoryAtPath:path error:nil];
    BOOL isDirectory = YES;
    for (NSString *file in files) {
        NSString *currentFile = [path stringByAppendingPathComponent:file];
        BOOL exist = [fileManager fileExistsAtPath:currentFile isDirectory:&isDirectory];
        
        if(!exist) continue;
        
        if (isDirectory) {
            if (![self recursiveDirectorySearch:currentFile findRuleBlock:findRuleBlock foundFileBlock:foundFileBlock]) {
                return NO;
            }
        }
        
        if (findRuleBlock && !findRuleBlock(currentFile, isDirectory)) {
            continue;
        }
        
        if(foundFileBlock && !foundFileBlock(currentFile, isDirectory))
        {
            return NO;
        }
    }
    
    return YES;
}

+ (BOOL)recursiveDirectorySearch:(NSString *)path extensions:(NSArray *)extensions specificFiles:(NSArray *)specificFiles foundFileBlock:(FoundFileBlock)foundFileBlock{
    return [self recursiveDirectorySearch:path findRuleBlock:^BOOL(NSString *filePath, BOOL isDirectory) {
        NSString *fileName = filePath.lastPathComponent;
        if ([extensions containsObject:fileName.pathExtension] || [specificFiles containsObject:fileName])
        {
            return YES;
        }
        return NO;
    } foundFileBlock:foundFileBlock];
}
@end

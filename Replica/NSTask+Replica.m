//
//  NSTask+Replica.m
//  Replica
//
//  Created by h4ck on 18/11/1.
//  Copyright © 2018年 字节时代（https://byteage.com） All rights reserved.
//

#import "NSTask+Replica.h"

@implementation RETaskOutput


@end

@implementation NSTask (Replica)
- (RETaskOutput *)launchSyncronous {
    self.standardInput = [NSFileHandle fileHandleWithNullDevice];
    NSPipe *pipe = [NSPipe pipe];
    self.standardOutput = pipe;
    self.standardError = pipe;
    NSFileHandle *readingPipeFile = [pipe fileHandleForReading];
    [self launch];
    
    NSMutableData *data = [NSMutableData data];
    while([self isRunning]) {
        [data appendData:readingPipeFile.availableData];
    }
    
    [readingPipeFile closeFile];
    [self terminate];
    NSString *output = [[NSString alloc]initWithData:data encoding:NSUTF8StringEncoding];
    NSInteger status = self.terminationStatus;
    RETaskOutput *taskOutput = [[RETaskOutput alloc]init];
    taskOutput.status = status;
    taskOutput.output = output;
    return taskOutput;
}

+ (RETaskOutput *)execute:(NSString *)launchPath workingDirectory:(NSString *)workingDirectory arguments:(NSArray *)arguments{
    NSTask *task = [[NSTask alloc]init];
    task.launchPath = launchPath;
    if (arguments) {
        task.arguments = arguments;
    }
    if (workingDirectory) {
        task.currentDirectoryPath = workingDirectory;
    }
    return [task launchSyncronous];
}
@end

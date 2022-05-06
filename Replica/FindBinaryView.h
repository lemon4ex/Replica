//
//  FindBinaryView.h
//  Replica
//
//  Created by h4ck on 18/11/1.
//  Copyright © 2018年 字节时代（https://byteage.com） All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface BinaryInfo : NSObject
@property (nonatomic) NSString *path;
@property (nonatomic) long long size;
@property (nonatomic) BOOL isDecrypted;
@end

@interface FindBinaryView : NSView

@end

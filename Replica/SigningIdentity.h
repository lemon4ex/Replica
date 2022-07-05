//
//  SigningIdentity.h
//  IPAExporter
//
//  Created by Tue Nguyen on 10/11/14.
//  Copyright (c) 2014 HOME. All rights reserved.
//

#import <Foundation/Foundation.h>

@class Provisioning;
@interface SigningIdentity : NSObject
@property (nonatomic, strong) NSString *commonName;
@property (nonatomic, strong) NSString *sha1;
@property (nonatomic, strong) NSString *md5;
@property (nonatomic, strong) NSString *serial;
@property (nonatomic, strong, readonly) NSData *certificateData;
- (instancetype)initWithCertificateData:(NSData *)certificateData;
+ (NSArray *)keychainsIdenities;
@end

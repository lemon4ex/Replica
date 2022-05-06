//
//  OCSPManager.h
//  OCSPDemo
//
//  Created by zeejun on 14-8-14.
//  Copyright (c) 2014年 zeejun. All rights reserved.
//

#import <Foundation/Foundation.h>
#include "ocspTemplates.h"

@interface CertStatusItem : NSObject

@property(nonatomic, strong) NSString *appName;
@property(nonatomic, strong) NSString *certID;
@property(nonatomic, strong) NSString *commonName;
@property(nonatomic, assign) NSInteger certStatus;
@property(nonatomic, strong) NSString *thisUpdate;
@property(nonatomic, strong) NSString *revokedTime;
@property(nonatomic, assign) NSInteger revocationReason;

- (NSString *)certStatusToString;
- (NSString *)revocationReasonToString;

@end

typedef void (^CertRevocationCompleteHandle)(CertStatusItem *statusItem,NSError *error);

@interface OCSPManager : NSObject

+ (instancetype)share;

- (NSDictionary *)mobileProvisionWithFile:(NSString *)file;

- (void)checkRevocationWtihPath:(NSString *)filePath completeHandle:(CertRevocationCompleteHandle)completeHandle;

- (void)sendCertStatusToServer:(CertStatusItem *)statusItem completionHandler:(void (^)(NSData *data, id info))handler;

@end

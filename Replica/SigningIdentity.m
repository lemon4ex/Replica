//
//  SigningIdentity.m
//  IPAExporter
//
//  Created by Tue Nguyen on 10/11/14.
//  Copyright (c) 2014 HOME. All rights reserved.
//

#import "SigningIdentity.h"
#import "Provisioning.h"
#import <Security/Security.h>

@interface SigningIdentity()

@end
@implementation SigningIdentity
- (instancetype)initWithProvision:(Provisioning *)provision certificateData:(NSData *)certificateData {
    self = [super init];
    if (self) {
        _certificateData = certificateData;
        [self _loadCertData];
    }
    return self;
}
- (void)_loadCertData {
    SecCertificateRef certRef = SecCertificateCreateWithData(kCFAllocatorDefault, (__bridge CFDataRef)(self.certificateData));
    CFStringRef commonName;
    SecCertificateCopyCommonName(certRef, &commonName);
    self.commonName = CFBridgingRelease(commonName);
    CFRelease(certRef);
}

+ (NSArray *)keychainsIdenities {
    NSMutableArray *keychainsIdentities = [NSMutableArray array];
    
    NSMutableDictionary *query = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                  (__bridge id)kCFBooleanTrue, (__bridge id)kSecReturnRef,
                                  (__bridge id)kSecMatchLimitAll, (__bridge id)kSecMatchLimit,
                                  kCFNull, kSecMatchValidOnDate,
//                                  @"iPhone", kSecMatchSubjectStartsWith,
                                  nil];

    NSArray *secItemClasses = [NSArray arrayWithObjects:
                               (__bridge id)kSecClassIdentity,
                               nil];

    for (id secItemClass in secItemClasses) {
        [query setObject:secItemClass forKey:(__bridge id)kSecClass];

        CFTypeRef result = NULL;
        SecItemCopyMatching((__bridge CFDictionaryRef)query, &result);

        if (result) {
            NSArray *identityArray = (__bridge NSArray *)(result);
            for (id obj in identityArray) {
                SecIdentityRef identityRef = (__bridge SecIdentityRef)(obj);
                SecCertificateRef certKeychains = NULL;
                SecIdentityCopyCertificate(identityRef, &certKeychains);
                if (certKeychains != NULL) {
                    NSData *keychainCertData = (NSData *)CFBridgingRelease(SecCertificateCopyData(certKeychains));
                    SigningIdentity *si = [[SigningIdentity alloc] initWithProvision:nil certificateData:keychainCertData];
//                    if ([si.commonName hasPrefix:@"iPhone Developer"] || [si.commonName hasPrefix:@"iPhone Distribution"]) {
                        [keychainsIdentities addObject:si];
//                    }
                    CFRelease(certKeychains);
                }
            }
        }


        if (result != NULL) CFRelease(result);
    }
    return keychainsIdentities;
}
@end

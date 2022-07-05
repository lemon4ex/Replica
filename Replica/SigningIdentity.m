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
#import <CommonCrypto/CommonCrypto.h>

@interface SigningIdentity()

@end
@implementation SigningIdentity
- (instancetype)initWithCertificateData:(NSData *)certificateData {
    self = [super init];
    if (self) {
        _certificateData = certificateData;
        [self _loadCertData];
    }
    return self;
}

- (NSString *)dataToHexString:(NSData *)data {
    uint8_t *bytes = (uint8_t *)[data bytes];
    NSMutableString *hexStr = [NSMutableString string];
    for(int i = 0; i < [data length]; i++) {
        uint8_t byte1 = bytes[i] >> 4;
        uint8_t byte2 = bytes[i] & 0xf;
        [hexStr appendFormat:@"%x",byte1];
        [hexStr appendFormat:@"%x",byte2];
    }
    return [hexStr uppercaseString];
}

- (void)_loadCertData {
    SecCertificateRef certRef = SecCertificateCreateWithData(kCFAllocatorDefault, (__bridge CFDataRef)(self.certificateData));
    CFStringRef commonName;
    SecCertificateCopyCommonName(certRef, &commonName);
    self.commonName = CFBridgingRelease(commonName);
    
    unsigned char sha1[CC_SHA1_DIGEST_LENGTH];
    CC_SHA1((const void *)self.certificateData.bytes, (CC_LONG)self.certificateData.length, sha1);
    self.sha1 = [self dataToHexString:[NSData dataWithBytes:sha1 length:CC_SHA1_DIGEST_LENGTH]];

    unsigned char md5[CC_MD5_DIGEST_LENGTH];
    CC_MD5((const void *)self.certificateData.bytes, (CC_LONG)self.certificateData.length, md5);
    self.md5 = [self dataToHexString:[NSData dataWithBytes:md5 length:CC_MD5_DIGEST_LENGTH]];

    NSData *serial = (__bridge_transfer NSData *)SecCertificateCopySerialNumber(certRef, NULL);
    self.serial = [self dataToHexString:serial];
    CFRelease(certRef);
}

+ (NSArray *)keychainsIdenities {
    NSMutableArray *keychainsIdentities = [NSMutableArray array];
    
    NSMutableDictionary *query = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                  (__bridge id)kCFBooleanTrue, (__bridge id)kSecReturnRef,
                                  (__bridge id)kSecMatchLimitAll, (__bridge id)kSecMatchLimit,
                                  kCFNull, kSecMatchValidOnDate,
                                  nil];

    NSArray *secItemClasses = [NSArray arrayWithObjects:
                               (__bridge id)kSecClassIdentity,
                               nil];

    for (id secItemClass in secItemClasses) {
        [query setObject:secItemClass forKey:(__bridge id)kSecClass];

        CFTypeRef result = NULL;
        SecItemCopyMatching((__bridge CFDictionaryRef)query, &result);

        if (!result) {
            continue;
        }
        
        NSArray *identityArray = (__bridge NSArray *)(result);
        for (id obj in identityArray) {
            SecIdentityRef identityRef = (__bridge SecIdentityRef)(obj);
            SecCertificateRef certKeychains = NULL;
            SecIdentityCopyCertificate(identityRef, &certKeychains);
            if (certKeychains != NULL) {
                NSData *keychainCertData = (NSData *)CFBridgingRelease(SecCertificateCopyData(certKeychains));
                SigningIdentity *si = [[SigningIdentity alloc] initWithCertificateData:keychainCertData];
                [keychainsIdentities addObject:si];
                CFRelease(certKeychains);
            }
        }
        CFRelease(result);
    }
    return keychainsIdentities;
}

- (BOOL)isEqual:(SigningIdentity *)object {
    if (self == object) {
        return YES;
    }
    if ([self class] != [object class]) {
        return NO;
    }
    return [self.serial isEqualToString:object.serial];
}

- (NSUInteger)hash {
    return self.serial.hash;
}
@end

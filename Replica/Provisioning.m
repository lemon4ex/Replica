//
//  Provisioning.m
//  IPAExporter
//
//  Created by Tue Nguyen on 10/10/14.
//  Copyright (c) 2014 HOME. All rights reserved.
//

#import "Provisioning.h"
#import "SigningIdentity.h"

@implementation Provisioning
- (instancetype)initWithPath:(NSString *)path {
    self = [super init];
    if (self) {
        self.path = path;
        [self _readProvisioningData];
    }
    return self;
}

- (void)_readProvisioningData {
    NSData *fileData = [NSData dataWithContentsOfFile:self.path];
    if (!fileData) return;
    
    // Insert code here to initialize your application
    CMSDecoderRef decoder = NULL;
    CMSDecoderCreate(&decoder);
    CMSDecoderUpdateMessage(decoder, fileData.bytes, fileData.length);
    CMSDecoderFinalizeMessage(decoder);
    
    CFDataRef dataRef = NULL;
    CMSDecoderCopyContent(decoder, &dataRef);
    NSData *data = (__bridge_transfer NSData *)dataRef;
    
    NSDictionary *propertyList = [NSPropertyListSerialization propertyListWithData:data options:0 format:NULL error:NULL];
    
    self.name = propertyList[@"Name"];
    self.expirationDate = propertyList[@"ExpirationDate"];
    self.creationDate = propertyList[@"CreationDate"];
    self.provisionedDevices = propertyList[@"ProvisionedDevices"];
    
    self.entitlements = propertyList[@"Entitlements"];
    self.applicationIdentifier = self.entitlements[@"application-identifier"]?:self.entitlements[@"com.apple.application-identifier"];
    //Remove team id in app id
    self.teamID = [propertyList[@"ApplicationIdentifierPrefix"] firstObject];
    if ([self.applicationIdentifier hasPrefix:self.teamID]) {
        self.applicationIdentifier = [self.applicationIdentifier substringFromIndex:self.teamID.length + 1];
    }
    self.developerCertificates = propertyList[@"DeveloperCertificates"];
    self.propertyList = propertyList;
    
    if ([self.expirationDate timeIntervalSinceNow] > 0) {
        self.status = @"Valid";
    } else {
        self.status = @"Expired";
    }
    
    [self _loadSigningIdentities];
}

- (void)_loadSigningIdentities {
    NSMutableArray *result = [NSMutableArray array];
    for (NSData *certData in self.developerCertificates) {
        SigningIdentity *identity = [[SigningIdentity alloc] initWithCertificateData:certData];
        [result addObject:identity];
    }
    self.signingIdentities = result;
}

- (BOOL)isExpired {
    return [[NSDate date] compare:self.expirationDate] == NSOrderedDescending;
}

- (BOOL)containsSigningIdentity:(SigningIdentity *)signingIdentity {
    __block BOOL result = NO;
    [self.signingIdentities enumerateObjectsUsingBlock:^(SigningIdentity * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if ([obj isEqual:signingIdentity]) {
            result = YES;
            *stop = YES;
        }
    }];
    return result;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"Provisioning(Name: %@, Create Date: %@, Expiration Date: %@, Path: %@)", self.name, self.creationDate, self.expirationDate, self.path];
}
@end

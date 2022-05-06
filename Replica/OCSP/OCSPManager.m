//
//  OCSPManager.m
//  OCSPDemo
//
//  Created by zeejun on 14-8-14.
//  Copyright (c) 2014年 zeejun. All rights reserved.
//

#import "OCSPManager.h"

#include "SecOCSPResponse.h"
#include "asynchttp.h"
#include "SecBase64.h"
#include "SecCFRelease.h"
#include <AssertMacros.h>

@implementation CertStatusItem

- (NSString *)certStatusToString
{
    switch (self.certStatus) {
        case CS_Good:
            return @"Good";
        case CS_Revoked:
            return @"Revoked";
        case CS_Unknown:
            return @"Unknown";
        default:
            break;
    }
    
    return @"Unknown";
}

- (NSString *)revocationReasonToString
{
    switch (self.revocationReason) {
        case kSecRevocationReasonUnrevoked:
            return @"Unrevoked";
            break;
        case kSecRevocationReasonUndetermined:
            return @"Undetermined";
            break;
        case kSecRevocationReasonUnspecified:
            return @"Unspecified";
            break;
        case kSecRevocationReasonKeyCompromise:
            return @"KeyCompromise";
            break;
        case kSecRevocationReasonCACompromise:
            return @"CACompromise";
            break;
        case kSecRevocationReasonAffiliationChanged:
            return @"AffiliationChanged";
            break;
        case kSecRevocationReasonCessationOfOperation:
            return @"CessationOfOperation";
            break;
        case kSecRevocationReasonCertificateHold:
            return @"CertificateHold";
            break;
        case kSecRevocationReasonRemoveFromCRL:
            return @"RemoveFromCRL";
            break;
        case kSecRevocationReasonPrivilegeWithdrawn:
            return @"PrivilegeWithdrawn";
            break;
        case kSecRevocationReasonAACompromise:
            return @"AACompromise";
            break;
        default:
            break;
    }
    return @"Undetermined";
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"appName:%@ CommonName:%@ certStatus:%ld  revokeDate:%@ reovcationReason: %ld",self.appName,self.commonName,(long)self.certStatus,self.revokedTime,self.revocationReason];
}

@end

static OCSPManager *sharedManager = nil;

@implementation OCSPManager

+ (instancetype)share
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedManager = [[[self class] alloc] init];
    });
    
    return sharedManager;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        
    }
    return self;
}

const char *cfabsoluteTimeToStringLocal(CFAbsoluteTime abstime)
{
    CFDateRef cfDate = CFDateCreate(kCFAllocatorDefault, abstime);
    CFDateFormatterRef dateFormatter = CFDateFormatterCreate(kCFAllocatorDefault, CFLocaleCopyCurrent(), kCFDateFormatterFullStyle, kCFDateFormatterLongStyle);
    CFDateFormatterSetFormat(dateFormatter, CFSTR("yyyy-MM-dd HH:mm:ss"));
    CFStringRef newString = CFDateFormatterCreateStringWithDate(kCFAllocatorDefault, dateFormatter, cfDate);
    
    char buffer[1024] = {0,};
    char *time_string = NULL;
    size_t sz;
    
    CFStringGetCString(newString, buffer, 1024, kCFStringEncodingUTF8);
    sz = strnlen(buffer, 1024);
    time_string = (char *)malloc(sz);
    strncpy(time_string, buffer, sz+1);
    
    CFRelease(dateFormatter);
    CFRelease(cfDate);
    CFRelease(newString);
    
    return time_string;
}

SecOCSPSingleResponseRef createOCSPSingleReqonseData(CFDataRef data)
{
    SecOCSPResponseRef ocspResponse = SecOCSPResponseCreate(data,0);
    SecAsn1OCSPSingleResponse **responses;
    for (responses = ocspResponse->responseData.responses; *responses; ++responses) {
        SecAsn1OCSPSingleResponse *resp = *responses;
        SecOCSPSingleResponseRef singleResponse = SecOCSPSingleResponseCreate(resp,ocspResponse->coder);
        SecOCSPResponseFinalize(ocspResponse);
        return singleResponse;
    }
    return NULL;
}

CFURLRef createGetURL(CFURLRef responder, CFDataRef request) {
    CFURLRef getURL = NULL;
    CFMutableDataRef base64Request = NULL;
    CFStringRef base64RequestString = NULL;
    CFStringRef peRequest = NULL;
    CFIndex base64Len;
    
    base64Len = SecBase64Encode(NULL, CFDataGetLength(request), NULL, 0);
    /* Don't bother doing all the work below if we know the end result will
     exceed 255 bytes (minus one for the '/' separator makes 254). */
    if (base64Len + CFURLGetBytes(responder, NULL, 0) > 254)
        return NULL;
    
    base64Request = CFDataCreateMutable(kCFAllocatorDefault,
                                        base64Len);
    CFDataSetLength(base64Request, base64Len);
    SecBase64Encode(CFDataGetBytePtr(request), CFDataGetLength(request),
                    (char *)CFDataGetMutableBytePtr(base64Request), base64Len);
    base64RequestString = CFStringCreateWithBytes(kCFAllocatorDefault,
                                                  CFDataGetBytePtr(base64Request), base64Len, kCFStringEncodingUTF8,
                                                  false);
    peRequest = CFURLCreateStringByAddingPercentEscapes(
                                                        kCFAllocatorDefault, base64RequestString, NULL, CFSTR("+/="),
                                                        kCFStringEncodingUTF8);
#if 1
    CFStringRef urlString = CFURLGetString(responder);
    CFStringRef fullURL;
    //    if (CFStringHasSuffix(urlString, CFSTR("/"))) {
    fullURL = CFStringCreateWithFormat(kCFAllocatorDefault, NULL,
                                       CFSTR("%@%@"), urlString, peRequest);
    //    } else {
    //        fullURL = CFStringCreateWithFormat(kCFAllocatorDefault, NULL,
    //                                           CFSTR("%@/%@"), urlString, peRequest);
    //    }
    getURL = CFURLCreateWithString(kCFAllocatorDefault, fullURL, NULL);
    CFRelease(fullURL);
#else
    getURL = CFURLCreateWithString(kCFAllocatorDefault, peRequest, responder);
#endif
    
errOut:
    CFReleaseSafe(base64Request);
    CFReleaseSafe(base64RequestString);
    CFReleaseSafe(peRequest);
    
    return getURL;
}

- (NSDictionary *)mobileProvisionWithFile:(NSString *)file
{
    file = [file stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    return [self mobileProvisionWithURL:[NSURL URLWithString:file]];
}

- (NSDictionary *)mobileProvisionWithURL:(NSURL *)url
{
    NSURL *URL = url;
    NSData *fileData = nil;
    if ([[URL pathExtension] isEqualToString:@"app"]) {
        // get the embedded provisioning for the iOS app
        fileData = [NSData dataWithContentsOfURL:[URL URLByAppendingPathComponent:@"embedded.mobileprovision"]];
    }
    else if ([[URL pathExtension] isEqualToString:@"ipa"]) {
        // get the embedded provisioning from an app arcive using: unzip -p /path/to/Application.ipa 'Payload/*.app/embedded.mobileprovision' (piped to standard output)
        NSTask *unzipTask = [NSTask new];
        [unzipTask setLaunchPath:@"/usr/bin/unzip"];
        [unzipTask setStandardOutput:[NSPipe pipe]];
        [unzipTask setArguments:@[@"-p", [URL path], @"Payload/*.app/embedded.mobileprovision" ]];
        [unzipTask launch];
        [unzipTask waitUntilExit];
        
        fileData = [[[unzipTask standardOutput] fileHandleForReading] readDataToEndOfFile];
    }
    else {
        // get the provisioning directly from the file
        fileData = [NSData dataWithContentsOfURL:URL];
    }
    
    if (fileData) {
        CMSDecoderRef decoder = NULL;
        CMSDecoderCreate(&decoder);
        CMSDecoderUpdateMessage(decoder, fileData.bytes, fileData.length);
        CMSDecoderFinalizeMessage(decoder);
        CFDataRef dataRef = NULL;
        CMSDecoderCopyContent(decoder, &dataRef);
        NSData *data = (NSData *)CFBridgingRelease(dataRef);
        CFRelease(decoder);
        
        if (data) {
            // check if the request was cancelled
            NSDictionary *propertyList = [NSPropertyListSerialization propertyListWithData:data options:0 format:NULL error:NULL];
            return propertyList;
        }
    }
    
    return NULL;
}

- (NSDictionary *)getCertificateAllValues:(NSDictionary *)dict
{
    id value = [dict objectForKey:@"DeveloperCertificates"];
    if ([value isKindOfClass:[NSArray class]]) {
        for (NSData *data in value) {
            CFErrorRef error = NULL;
            SecCertificateRef certificateRef = SecCertificateCreateWithData(NULL, (__bridge CFDataRef)data);
            CFDictionaryRef valuesDict = SecCertificateCopyValues(certificateRef, NULL, &error);
            return (__bridge_transfer NSDictionary *)(valuesDict);
        }
    }
    return NULL;
}

- (NSArray *)getCertificatesFromMoileProvision:(NSDictionary *)dict
{
    NSMutableArray *array = [[NSMutableArray alloc]init];
    
    id value = [dict objectForKey:@"DeveloperCertificates"];
    if ([value isKindOfClass:[NSArray class]]) {
        for (NSData *data in value) {
            SecCertificateRef certificateRef = SecCertificateCreateWithData(NULL, (__bridge CFDataRef)data);
            if (certificateRef) {
                [array addObject:(__bridge_transfer id)(certificateRef)];
            }
        }
    }
    
    return array;
}

- (NSString *)ocspURLStringWithSerialNumber:(CFDataRef)serialNumberData
{
    const char *urlString = "http://ocsp.apple.com/ocsp-wwdr01/ME4wTKADAgEAMEUwQzBBMAkGBSsOAwIaBQAEFADrDMz0cWy6RiOj1S%2BY1D32MKkdBBSIJxcJqbYYYIvs67r2R1nFUlSjtwII";
    CFURLRef cfUrl = CFURLCreateWithBytes(NULL, (const UInt8 *)urlString, strlen(urlString), kCFStringEncodingUTF8, NULL);
    CFURLRef url = createGetURL(cfUrl, serialNumberData);
    NSURL *nsurl = (__bridge_transfer NSURL *)url;
    CFReleaseSafe(cfUrl);
    return [nsurl absoluteString];
}

- (NSData *)checkRevocationFromOCSPServer:(NSString *)urlString
{
    NSURL *url  = [NSURL URLWithString:urlString];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    [request setValue:@"securityd (unknown version) CFNetwork/672.1.15 Darwin/14.0.0" forHTTPHeaderField:@"User-Agent"];
    [request setValue:@"application/ocsp-response" forHTTPHeaderField:@"Content-Type"];
    [request setValue:@"no-cache" forHTTPHeaderField:@"Cache-Control"];
    //    NSOperationQueue *queue = [[NSOperationQueue alloc]init];
    
    NSError *error = nil;
    NSURLResponse *urlRespone = nil;
    NSData  *data = [NSURLConnection sendSynchronousRequest:request returningResponse:&urlRespone error:&error];
    return data;
}

- (void)checkRevocationWtihPath:(NSString *)filePath completeHandle:(CertRevocationCompleteHandle)completeHandle
{
    filePath = [filePath stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    NSDictionary *dict = [self mobileProvisionWithURL:[NSURL URLWithString:filePath]];
    NSArray *certificates = [self getCertificatesFromMoileProvision:dict];
    
    if ([certificates count] > 0) {
        CFErrorRef error = NULL;
        SecCertificateRef certificateRef = (__bridge SecCertificateRef)(certificates[0]);
    
        CFDataRef serialNumberData = SecCertificateCopySerialNumber(certificateRef, &error);
        const UInt8 *byte = CFDataGetBytePtr(serialNumberData);
        CFIndex len = CFDataGetLength(serialNumberData);
        
        NSMutableString *serialNumberMutableStr = [[NSMutableString alloc]init];
        for (CFIndex n = 0; n < len; n++) {
            char hex[3];
            snprintf(hex, sizeof(hex), "%02x", byte[n]);
            NSString *ddd = [[NSString alloc]initWithBytes:hex length:2 encoding:NSUTF8StringEncoding];
            [serialNumberMutableStr appendString:ddd];
        }
        long long d = strtoll([serialNumberMutableStr UTF8String],NULL,16);
        NSString *serialNumberStr = [NSString stringWithFormat:@"%lld",d];
        
        if (serialNumberData && !error) {
            CFStringRef commonName = NULL;
            SecCertificateCopyCommonName(certificateRef,&commonName);
            
            NSString *urlString = [self ocspURLStringWithSerialNumber:serialNumberData];
            NSData *data = [self checkRevocationFromOCSPServer:urlString];
            if (data) {
                SecOCSPSingleResponseRef singleResponse = createOCSPSingleReqonseData((__bridge CFDataRef)(data));
                
                if (singleResponse)
                {
                    CertStatusItem *item = [[CertStatusItem alloc]init];
                    
                    const char *thisUpdate = cfabsoluteTimeToStringLocal(singleResponse->thisUpdate);
                    const char *nextUpdate = cfabsoluteTimeToStringLocal(singleResponse->nextUpdate);
                    const char *revokeDate = cfabsoluteTimeToStringLocal(singleResponse->revokedTime);
                    
                    NSString *appName = [[filePath lastPathComponent]stringByDeletingPathExtension];
                    appName = [appName stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
                    item.appName = appName;
                    item.thisUpdate = [NSString stringWithUTF8String:thisUpdate];
                    item.revocationReason = singleResponse->crlReason;
                    item.certStatus = singleResponse->certStatus;
                    item.commonName = (__bridge_transfer NSString *)(commonName);
                    item.certID = serialNumberStr;
                    
                    if (item.certStatus == 0) {
                        item.revokedTime = @"";
                    }else
                    {
                        item.revokedTime = [NSString stringWithUTF8String:revokeDate];
                    }
                    
                    free((void *)thisUpdate);
                    free((void *)nextUpdate);
                    free((void *)revokeDate);
                    free(singleResponse);
                    
                    completeHandle(item,nil);
                }else
                {
                    NSError *error = [NSError errorWithDomain:@"RevocationDomain" code:-1 userInfo:[NSDictionary dictionaryWithObjectsAndKeys:filePath,@"FilePath", nil]];
                    completeHandle(nil,error);
                }
            }else
            {
                NSError *error = [NSError errorWithDomain:@"RevocationDomain" code:-1 userInfo:[NSDictionary dictionaryWithObjectsAndKeys:filePath,@"FilePath", nil]];
                completeHandle(nil,error);
            }
        }else
        {
            NSError *error = [NSError errorWithDomain:@"RevocationDomain" code:-1 userInfo:[NSDictionary dictionaryWithObjectsAndKeys:filePath,@"FilePath", nil]];
            completeHandle(nil,error);
        }
        
        if (serialNumberData) {
            free((void *)serialNumberData);
        }
        
//        for (int i = (int)[certificates count]-1; i >= 0; i--) {
//            SecCertificateRef cert = (__bridge SecCertificateRef)([certificates objectAtIndex:i]);
//            free(cert);
//        }
        
    }else
    {
        NSError *error = [NSError errorWithDomain:@"RevocationDomain" code:-1 userInfo:[NSDictionary dictionaryWithObjectsAndKeys:filePath,@"FilePath", nil]];
        completeHandle(nil,error);
    }
    
}

@end

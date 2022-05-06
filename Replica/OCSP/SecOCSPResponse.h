//
//  SecOCSPSingleResponse.h
//  OCSPDemo
//
//  Created by zeejun on 14-8-12.
//  Copyright (c) 2014年 zeejun. All rights reserved.
//

#ifndef OCSPDemo_SecOCSPSingleResponse_h
#define OCSPDemo_SecOCSPSingleResponse_h

#include <CoreFoundation/CoreFoundation.h>
#include <Security/Security.h>
#include <security/SecAsn1Coder.h>

#include "ocspTemplates.h"

typedef enum {
	kSecOCSPBad = -2,
	kSecOCSPUnknown = -1,
	kSecOCSPSuccess = 0,
	kSecOCSPMalformedRequest = 1,
	kSecOCSPInternalError = 2,
	kSecOCSPTryLater = 3,
	kSecOCSPUnused = 4,
	kSecOCSPSigRequired = 5,
	kSecOCSPUnauthorized = 6
} SecOCSPResponseStatus;

enum {
    kSecRevocationReasonUnrevoked               = -2,
    kSecRevocationReasonUndetermined            = -1,
    kSecRevocationReasonUnspecified             = 0,
    kSecRevocationReasonKeyCompromise           = 1,
    kSecRevocationReasonCACompromise            = 2,
    kSecRevocationReasonAffiliationChanged      = 3,
    kSecRevocationReasonSuperseded              = 4,
    kSecRevocationReasonCessationOfOperation    = 5,
    kSecRevocationReasonCertificateHold         = 6,
    /*         -- value 7 is not used */
    kSecRevocationReasonRemoveFromCRL           = 8,
    kSecRevocationReasonPrivilegeWithdrawn      = 9,
    kSecRevocationReasonAACompromise            = 10
};
typedef int32_t SecRevocationReason;




/*!
 @typedef SecOCSPResponseRef
 @abstract Object used for ocsp response decoding.
 */
typedef struct __SecOCSPResponse *SecOCSPResponseRef;

struct __SecOCSPResponse {
    CFDataRef data;
    SecAsn1CoderRef coder;
    SecOCSPResponseStatus responseStatus;
    CFDataRef nonce;
    CFAbsoluteTime producedAt;
    CFAbsoluteTime latestNextUpdate;
    CFAbsoluteTime expireTime;
    CFAbsoluteTime verifyTime;
    SecAsn1OCSPBasicResponse basicResponse;
    SecAsn1OCSPResponseData responseData;
    SecAsn1OCSPResponderIDTag responderIdTag;
    SecAsn1OCSPResponderID responderID;
};


typedef struct __SecOCSPSingleResponse *SecOCSPSingleResponseRef;

struct __SecOCSPSingleResponse {
    SecAsn1OCSPCertStatusTag certStatus;
    CFAbsoluteTime thisUpdate;
    CFAbsoluteTime nextUpdate;		/* may be NULL_TIME */
    CFAbsoluteTime revokedTime;		/* != NULL_TIME for certStatus == CS_Revoked */
    SecRevocationReason crlReason;
    //OCSPExtensions *extensions;
};


/*!
 @function SecOCSPResponseCreate
 @abstract Returns a SecOCSPResponseRef from a BER encoded ocsp response.
 @param berResponse The BER encoded ocsp response.
 @result A SecOCSPResponseRef.
 */
SecOCSPResponseRef SecOCSPResponseCreate(CFDataRef ocspResponse,
                                         CFTimeInterval maxAge);

CFDataRef SecOCSPResponseGetData(SecOCSPResponseRef this);

SecOCSPResponseStatus SecOCSPGetResponseStatus(SecOCSPResponseRef ocspResponse);

CFAbsoluteTime SecOCSPResponseGetExpirationTime(SecOCSPResponseRef ocspResponse);

CFDataRef SecOCSPResponseGetNonce(SecOCSPResponseRef ocspResponse);

CFAbsoluteTime SecOCSPResponseProducedAt(SecOCSPResponseRef ocspResponse);

CFAbsoluteTime SecOCSPResponseVerifyTime(SecOCSPResponseRef ocspResponse);

/*!
 @function SecOCSPResponseCopySigners
 @abstract Returns an array of signers.
 @param ocspResponse A SecOCSPResponseRef.
 @result The passed in SecOCSPResponseRef is deallocated
 */
CFArrayRef SecOCSPResponseCopySigners(SecOCSPResponseRef ocsp);

/*!
 @function SecOCSPResponseFinalize
 @abstract Frees a SecOCSPResponseRef.
 @param ocspResponse The BER encoded ocsp response.
 @result A SecOCSPResponseRef.
 */
void SecOCSPResponseFinalize(SecOCSPResponseRef ocspResponse);


SecOCSPSingleResponseRef SecOCSPSingleResponseCreate(
                                                     SecAsn1OCSPSingleResponse *resp, SecAsn1CoderRef coder);
#endif

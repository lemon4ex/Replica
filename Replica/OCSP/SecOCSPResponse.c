//
//  SecOCSPSingleResponse.c
//  OCSPDemo
//
//  Created by zeejun on 14-8-12.
//  Copyright (c) 2014年 zeejun. All rights reserved.
//

#include <stdio.h>
#include "SecOCSPResponse.h"
#include <AssertMacros.h>
#include <asl.h>
#include "SecCFRelease.h"


#define ocspdErrorLog(args...)     asl_log(NULL, NULL, ASL_LEVEL_ERR, ## args)
#define ocspdHttpDebug(args...)     secdebug("ocspdHttp", ## args)
#define ocspdDebug(args...)     secdebug("ocsp", ## args)

#define OID_ISO_IDENTIFIED_ORG 				43
#define OID_DOD                				OID_ISO_IDENTIFIED_ORG, 6
#define OID_AD_OCSP							OID_AD, 1

#define SECASN1OID_DEF(NAME, VALUE, ARGS...) \
static const uint8_t _##NAME[] = { VALUE, ## ARGS }; \
const SecAsn1Oid NAME = { sizeof(_##NAME), (uint8_t *)_##NAME }

SECASN1OID_DEF(OID_PKIX_OCSP_BASIC,             OID_AD_OCSP, 1);

#define NULL_TIME	0.0


extern const SecAsn1Template kSecAsn1OCSPResponseTemplate[];
extern const SecAsn1Template kSecAsn1OCSPBasicResponseTemplate[];
extern const SecAsn1Template kSecAsn1OCSPResponseDataTemplate[];

extern const SecAsn1Template kSecAsn1OCSPResponderIDAsNameTemplate[];
extern const SecAsn1Template kSecAsn1OCSPResponderIDAsKeyTemplate[];

extern const SecAsn1Template kSecAsn1OCSPCertStatusRevokedTemplate[];

//typedef uint16_t DERTag;

/* Decode a choice of UTCTime or GeneralizedTime to a CFAbsoluteTime. Return
 an absoluteTime if the date was valid and properly decoded.  Return
 NULL_TIME otherwise. */
extern CFAbsoluteTime SecAbsoluteTimeFromDateContent(DERTag tag, const uint8_t *bytes,
                                              size_t length);

//extern bool SecAsn1OidCompare(const SecAsn1Oid *oid1, const SecAsn1Oid *oid2);



/*
 OCSPResponse ::= SEQUENCE {
 responseStatus         OCSPResponseStatus,
 responseBytes          [0] EXPLICIT ResponseBytes OPTIONAL }
 
 OCSPResponseStatus ::= ENUMERATED {
 successful            (0),  --Response has valid confirmations
 malformedRequest      (1),  --Illegal confirmation request
 internalError         (2),  --Internal error in issuer
 tryLater              (3),  --Try again later
 --(4) is not used
 sigRequired           (5),  --Must sign the request
 unauthorized          (6)   --Request unauthorized
 }
 
 ResponseBytes ::=       SEQUENCE {
 responseType   OBJECT IDENTIFIER,
 response       OCTET STRING }
 
 id-pkix-ocsp           OBJECT IDENTIFIER ::= { id-ad-ocsp }
 id-pkix-ocsp-basic     OBJECT IDENTIFIER ::= { id-pkix-ocsp 1 }
 
 The value for response SHALL be the DER encoding of
 BasicOCSPResponse.
 
 BasicOCSPResponse       ::= SEQUENCE {
 tbsResponseData      ResponseData,
 signatureAlgorithm   AlgorithmIdentifier,
 signature            BIT STRING,
 certs                [0] EXPLICIT SEQUENCE OF Certificate OPTIONAL }
 
 The value for signature SHALL be computed on the hash of the DER
 encoding ResponseData.
 
 ResponseData ::= SEQUENCE {
 version              [0] EXPLICIT Version DEFAULT v1,
 responderID              ResponderID,
 producedAt               GeneralizedTime,
 responses                SEQUENCE OF SingleResponse,
 responseExtensions   [1] EXPLICIT Extensions OPTIONAL }
 
 ResponderID ::= CHOICE {
 byName               [1] Name,
 byKey                [2] KeyHash }
 
 KeyHash ::= OCTET STRING -- SHA-1 hash of responder's public key
 (excluding the tag and length fields)
 
 SingleResponse ::= SEQUENCE {
 certID                       CertID,
 certStatus                   CertStatus,
 thisUpdate                   GeneralizedTime,
 nextUpdate         [0]       EXPLICIT GeneralizedTime OPTIONAL,
 singleExtensions   [1]       EXPLICIT Extensions OPTIONAL }
 
 CertStatus ::= CHOICE {
 good        [0]     IMPLICIT NULL,
 revoked     [1]     IMPLICIT RevokedInfo,
 unknown     [2]     IMPLICIT UnknownInfo }
 
 RevokedInfo ::= SEQUENCE {
 revocationTime              GeneralizedTime,
 revocationReason    [0]     EXPLICIT CRLReason OPTIONAL }
 
 UnknownInfo ::= NULL -- this can be replaced with an enumeration
 */


bool SecAsn1OidCompare(const SecAsn1Oid *oid1, const SecAsn1Oid *oid2) {
	if (!oid1 || !oid2)
		return oid1 == oid2;
	if (oid1->Length != oid2->Length)
		return false;
	return !memcmp(oid1->Data, oid2->Data, oid1->Length);
}

static CFAbsoluteTime genTimeToCFAbsTime(const SecAsn1Item *datetime)
{
    return SecAbsoluteTimeFromDateContent(SEC_ASN1_GENERALIZED_TIME,
                                          datetime->Data, datetime->Length);
}

void SecOCSPSingleResponseDestroy(SecOCSPSingleResponseRef this) {
    free(this);
}

SecOCSPSingleResponseRef SecOCSPSingleResponseCreate(SecAsn1OCSPSingleResponse *resp, SecAsn1CoderRef coder) {
	assert(resp != NULL);
    SecOCSPSingleResponseRef this;
    this = (SecOCSPSingleResponseRef)
    malloc(sizeof(struct __SecOCSPSingleResponse));
    this->certStatus = CS_NotParsed;
	this->thisUpdate = NULL_TIME;
	this->nextUpdate = NULL_TIME;
	this->revokedTime = NULL_TIME;
	this->crlReason = kSecRevocationReasonUndetermined;
	//this->extensions = NULL;
    
	if ((resp->certStatus.Data == NULL) || (resp->certStatus.Length == 0)) {
		ocspdErrorLog("OCSPSingleResponse: bad certStatus");
        goto errOut;
	}
	this->certStatus = (SecAsn1OCSPCertStatusTag)(resp->certStatus.Data[0] & SEC_ASN1_TAGNUM_MASK);
	if (this->certStatus == CS_Revoked) {
		/* Decode further to get SecAsn1OCSPRevokedInfo */
		SecAsn1OCSPCertStatus certStatus;
		memset(&certStatus, 0, sizeof(certStatus));
		if (SecAsn1DecodeData(coder, &resp->certStatus,
                              kSecAsn1OCSPCertStatusRevokedTemplate, &certStatus)) {
			ocspdErrorLog("OCSPSingleResponse: err decoding certStatus");
            goto errOut;
		}
		SecAsn1OCSPRevokedInfo *revokedInfo = certStatus.revokedInfo;
		if (revokedInfo != NULL) {
			/* Treat this as optional even for CS_Revoked */
			this->revokedTime = genTimeToCFAbsTime(&revokedInfo->revocationTime);
			const SecAsn1Item *revReason = revokedInfo->revocationReason;
			if((revReason != NULL) &&
			   (revReason->Data != NULL) &&
			   (revReason->Length != 0)) {
                this->crlReason = revReason->Data[0];
			}
		}
	}
	this->thisUpdate = genTimeToCFAbsTime(&resp->thisUpdate);
	if (resp->nextUpdate != NULL) {
		this->nextUpdate = genTimeToCFAbsTime(resp->nextUpdate);
	}
	//mExtensions = new OCSPExtensions(resp->singleExtensions);
//	ocspdDebug("status %d reason %d", (int)this->certStatus,
//               (int)this->crlReason);
    return this;
errOut:
    if (this)
        SecOCSPSingleResponseDestroy(this);
    return NULL;
}

#define LEEWAY (4500.0)

/* Calculate temporal validity; set latestNextUpdate and expireTime. Only
 called from SecOCSPResponseCreate. Returns true if valid, else returns
 false. */
static bool SecOCSPResponseCalculateValidity(SecOCSPResponseRef this,
                                             CFTimeInterval maxAge, CFTimeInterval defaultTTL)
{
	this->latestNextUpdate = NULL_TIME;
	CFAbsoluteTime now = this->verifyTime = CFAbsoluteTimeGetCurrent();
    
    if (this->producedAt > now + LEEWAY) {
        ocspdErrorLog("OCSPResponse: producedAt more than 1:15 from now");
        return false;
    }
    
    /* Make this->latestNextUpdate be the date farthest in the future
     of any of the singleResponses nextUpdate fields. */
    SecAsn1OCSPSingleResponse **responses;
    for (responses = this->responseData.responses; *responses; ++responses) {
		SecAsn1OCSPSingleResponse *resp = *responses;
		
		/* thisUpdate later than 'now' invalidates the whole response. */
		CFAbsoluteTime thisUpdate = genTimeToCFAbsTime(&resp->thisUpdate);
		if (thisUpdate > now + LEEWAY) {
			ocspdErrorLog("OCSPResponse: thisUpdate more than 1:15 from now");
			return false;
		}
        
		/* Keep track of latest nextUpdate. */
		if (resp->nextUpdate != NULL) {
			CFAbsoluteTime nextUpdate = genTimeToCFAbsTime(resp->nextUpdate);
			if (nextUpdate > this->latestNextUpdate) {
				this->latestNextUpdate = nextUpdate;
			}
		}
#ifdef STRICT_RFC5019
        else {
            /* RFC 5019 section 2.2.4 states on nextUpdate:
             Responders MUST always include this value to aid in
             response caching.  See Section 6 for additional
             information on caching.
             */
			ocspdErrorLog("OCSPResponse: nextUpdate not present");
			return false;
        }
#endif
	}
    
    /* Now that we have this->latestNextUpdate, we figure out the latest
     date at which we will expire this response from our cache.  To comply
     with rfc5019s:
     
     6.1.  Caching at the Client
     
     To minimize bandwidth usage, clients MUST locally cache authoritative
     OCSP responses (i.e., a response with a signature that has been
     successfully validated and that indicate an OCSPResponseStatus of
     'successful').
     
     Most OCSP clients will send OCSPRequests at or near the nextUpdate
     time (when a cached response expires).  To avoid large spikes in
     responder load that might occur when many clients refresh cached
     responses for a popular certificate, responders MAY indicate when the
     client should fetch an updated OCSP response by using the cache-
     control:max-age directive.  Clients SHOULD fetch the updated OCSP
     Response on or after the max-age time.  To ensure that clients
     receive an updated OCSP response, OCSP responders MUST refresh the
     OCSP response before the max-age time.
     
     6.2 [...]
     
     we need to take the cache-control:max-age directive into account.
     
     The way the code below is written we ignore a max-age=0 in the
     http header.  Since a value of 0 (NULL_TIME) also means there
     was no max-age in the header. This seems ok since that would imply
     no-cache so we also ignore negative values for the same reason,
     instead we'll expire whenever this->latestNextUpdate tells us to,
     which is the signed value if max-age is too low, since we don't
     want to refetch multilple times for a single page load in a browser. */
	if (this->latestNextUpdate == NULL_TIME) {
        /* See comment above on RFC 5019 section 2.2.4. */
		/* Absolute expire time = current time plus defaultTTL */
		this->expireTime = now + defaultTTL;
	} else if (this->latestNextUpdate < now - LEEWAY) {
        ocspdErrorLog("OCSPResponse: latestNextUpdate more than 1:15 ago");
        return false;
    } else if (maxAge > 0) {
        /* Beware of double overflows such as:
         
         now + maxAge < this->latestNextUpdate
         
         in the math below since an attacker could create any positive
         value for maxAge. */
        if (maxAge < this->latestNextUpdate - now) {
            /* maxAge header wants us to expire the cache entry sooner than
             nextUpdate would allow, to balance server load. */
            this->expireTime = now + maxAge;
        } else {
            /* maxAge http header attempting to make us cache the response
             longer than it's valid for, bad http header! Ignoring you. */
            ocspdErrorLog("OCSPResponse: now + maxAge > latestNextUpdate,"
                          " using latestNextUpdate");
            this->expireTime = this->latestNextUpdate;
        }
	} else {
        /* No maxAge provided, just use latestNextUpdate. */
		this->expireTime = this->latestNextUpdate;
    }
    
	return true;
}


SecOCSPResponseRef SecOCSPResponseCreate(CFDataRef ocspResponse,
                                         CFTimeInterval maxAge) {
    SecAsn1OCSPResponse topResp = {};
    SecOCSPResponseRef this;
    
    this = (SecOCSPResponseRef)calloc(1, sizeof(struct __SecOCSPResponse));
    SecAsn1CoderCreate(&this->coder);
    
    this->data = ocspResponse;
    CFRetain(ocspResponse);
    
    SecAsn1Item resp;
    resp.Length = CFDataGetLength(ocspResponse);
    resp.Data = (uint8_t *)CFDataGetBytePtr(ocspResponse);
	if (SecAsn1DecodeData(this->coder, &resp, kSecAsn1OCSPResponseTemplate,
                          &topResp)) {
		ocspdErrorLog("OCSPResponse: decode failure at top level");
	}

    /* remainder is valid only on RS_Success */
	if ((topResp.responseStatus.Data == NULL) ||
        (topResp.responseStatus.Length == 0)) {
		ocspdErrorLog("OCSPResponse: no responseStatus");
        goto errOut;
	}
    this->responseStatus = topResp.responseStatus.Data[0];
	if (this->responseStatus != kSecOCSPSuccess) {
//		secdebug("ocsp", "OCSPResponse: status: %d", this->responseStatus);
		/* not a failure of our constructor; this object is now useful, but
		 * only for this one byte of status info */
		return this;
	}
	if (topResp.responseBytes == NULL) {
		/* I don't see how this can be legal on RS_Success */
		ocspdErrorLog("OCSPResponse: empty responseBytes");
        goto errOut;
	}
    if (!SecAsn1OidCompare(&topResp.responseBytes->responseType,
                           &OID_PKIX_OCSP_BASIC)) {
		ocspdErrorLog("OCSPResponse: unknown responseType");
        goto errOut;
        
	}
    
    /* decode the SecAsn1OCSPBasicResponse */
	if (SecAsn1DecodeData(this->coder, &topResp.responseBytes->response,
                          kSecAsn1OCSPBasicResponseTemplate, &this->basicResponse)) {
		ocspdErrorLog("OCSPResponse: decode failure at SecAsn1OCSPBasicResponse");
        goto errOut;
	}
    
	/* signature and cert evaluation done externally */
    
	/* decode the SecAsn1OCSPResponseData */
	if (SecAsn1DecodeData(this->coder, &this->basicResponse.tbsResponseData,
                          kSecAsn1OCSPResponseDataTemplate, &this->responseData)) {
		ocspdErrorLog("OCSPResponse: decode failure at SecAsn1OCSPResponseData");
        goto errOut;
	}
    this->producedAt = genTimeToCFAbsTime(&this->responseData.producedAt);
    if (this->producedAt == NULL_TIME) {
		ocspdErrorLog("OCSPResponse: bad producedAt");
        goto errOut;
    }
    
	if (this->responseData.responderID.Data == NULL) {
		ocspdErrorLog("OCSPResponse: bad responderID");
        goto errOut;
	}

    /* Choice processing for ResponderID */
    this->responderIdTag = (SecAsn1OCSPResponderIDTag)
    (this->responseData.responderID.Data[0] & SEC_ASN1_TAGNUM_MASK);
	const SecAsn1Template *templ;
	switch(this->responderIdTag) {
		case RIT_Name:
            /* @@@ Since we don't use the decoded byName value we could skip
             decoding it but we do it anyway for validation. */
			templ = kSecAsn1OCSPResponderIDAsNameTemplate;
			break;
		case RIT_Key:
			templ = kSecAsn1OCSPResponderIDAsKeyTemplate;
			break;
		default:
			ocspdErrorLog("OCSPResponse: bad responderID tag");
            goto errOut;
	}
	if (SecAsn1DecodeData(this->coder, &this->responseData.responderID, templ,
                          &this->responderID)) {
		ocspdErrorLog("OCSPResponse: decode failure at responderID");
        goto errOut;
	}
    
    /* We should probably get the defaultTTL from the policy.
     For now defaultTTL is hardcoded to 24 hours. */
    CFTimeInterval defaultTTL = 24 * 60 * 60;
	/* Check temporal validity, default TTL 24 hours. */
    SecOCSPResponseCalculateValidity(this, maxAge, defaultTTL);
    
#if 0
	/* Individual responses looked into when we're asked for a specific one
     via SecOCSPResponseCopySingleResponse(). */
	mExtensions = new OCSPExtensions(mResponseData.responseExtensions);
#endif
    
    return this;
errOut:
    if (this) {
        SecOCSPResponseFinalize(this);
    }
    return NULL;
}

CFDataRef SecOCSPResponseGetData(SecOCSPResponseRef this) {
    return this->data;
}

SecOCSPResponseStatus SecOCSPGetResponseStatus(SecOCSPResponseRef this) {
    return this->responseStatus;
}

CFAbsoluteTime SecOCSPResponseGetExpirationTime(SecOCSPResponseRef this) {
    return this->expireTime;
}

CFDataRef SecOCSPResponseGetNonce(SecOCSPResponseRef this) {
    return this->nonce;
}

CFAbsoluteTime SecOCSPResponseProducedAt(SecOCSPResponseRef this) {
    return this->producedAt;
}

CFAbsoluteTime SecOCSPResponseVerifyTime(SecOCSPResponseRef this) {
    return this->verifyTime;
}

CFArrayRef SecOCSPResponseCopySigners(SecOCSPResponseRef this) {
    return NULL;
}

void SecOCSPResponseFinalize(SecOCSPResponseRef this) {
    CFReleaseSafe(this->data);
    CFReleaseSafe(this->nonce);
    SecAsn1CoderRelease(this->coder);
    free(this);
}

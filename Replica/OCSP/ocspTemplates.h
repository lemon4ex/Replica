/*
 * Copyright (c) 2003-2006,2008-2010 Apple Inc. All Rights Reserved.
 * 
 * @APPLE_LICENSE_HEADER_START@
 * 
 * This file contains Original Code and/or Modifications of Original Code
 * as defined in and that are subject to the Apple Public Source License
 * Version 2.0 (the 'License'). You may not use this file except in
 * compliance with the License. Please obtain a copy of the License at
 * http://www.opensource.apple.com/apsl/ and read it before using this
 * file.
 * 
 * The Original Code and all software distributed under the License are
 * distributed on an 'AS IS' basis, WITHOUT WARRANTY OF ANY KIND, EITHER
 * EXPRESS OR IMPLIED, AND APPLE HEREBY DISCLAIMS ALL SUCH WARRANTIES,
 * INCLUDING WITHOUT LIMITATION, ANY WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE, QUIET ENJOYMENT OR NON-INFRINGEMENT.
 * Please see the License for the specific language governing rights and
 * limitations under the License.
 * 
 * @APPLE_LICENSE_HEADER_END@
 *
 * ocspTemplates.h -  ASN1 templates OCSP requests and responses.
 */

#ifndef	_OCSP_TEMPLATES_H_
#define _OCSP_TEMPLATES_H_

#include "nameTemplates.h"

#ifdef  __cplusplus
extern "C" {
#endif

    
/*
 * BasicOCSPResponse       ::= SEQUENCE {
 *		tbsResponseData      ResponseData,
 *		signatureAlgorithm   AlgorithmIdentifier,
 *		signature            BIT STRING,
 *		certs                [0] EXPLICIT SEQUENCE OF Certificate OPTIONAL }
 *
 * Since we ALWAYS encode the tbsResponseData in preparation for signing,
 * we declare it as a raw ASN_ANY in the BasicOCSPResponse.
 *
 * Certs are likewise ASN_ANY since we use the CL to parse and create them.
 */
typedef struct {
    SecAsn1Item						tbsResponseData;
    SecAsn1AlgId	algId;
    SecAsn1Item						sig;		// length in BITS
    SecAsn1Item						**certs;	// optional
} SecAsn1OCSPBasicResponse;

/*
 * X509 cert extension
 * ASN Class : Extension
 * C struct  : NSS_CertExtension
 *
 * With a nontrivial amount of extension-specific processing,
 * this maps to a CSSM_X509_EXTENSION.
 */
typedef struct {
    SecAsn1Item extnId;
    SecAsn1Item critical;		// optional, default = false
    SecAsn1Item value;		// OCTET string whose decoded value is
    // an id-specific DER-encoded thing
} NSS_CertExtension;

/*
 * CertID          ::=     SEQUENCE {
 *		hashAlgorithm		AlgorithmIdentifier,
 *		issuerNameHash		OCTET STRING, -- Hash of Issuer's DN
 *		issuerKeyHash		OCTET STRING, -- Hash of Issuers public key
 *		serialNumber		CertificateSerialNumber }   -- i.e., INTEGER
 */
typedef struct {
    SecAsn1AlgId		algId;
    SecAsn1Item							issuerNameHash;
    SecAsn1Item							issuerPubKeyHash;
    SecAsn1Item							serialNumber;
} SecAsn1OCSPCertID;

/*
 * SingleResponse ::= SEQUENCE {
 *		certID                       CertID,
 *		certStatus                   CertStatus,
 *		thisUpdate                   GeneralizedTime,
 *		nextUpdate         [0]       EXPLICIT GeneralizedTime OPTIONAL,
 *		singleExtensions   [1]       EXPLICIT Extensions OPTIONAL }
 */
typedef struct {
    SecAsn1OCSPCertID			certID;
    SecAsn1Item					certStatus;				// ASN_ANY here
    SecAsn1Item					thisUpdate;				// GeneralizedTime
    SecAsn1Item					*nextUpdate;			// GeneralizedTime, OPTIONAL
    NSS_CertExtension 			**singleExtensions;		// OPTIONAL
} SecAsn1OCSPSingleResponse;

/*
 * ResponseData ::= SEQUENCE {
 *		version              [0] EXPLICIT Version DEFAULT v1,
 *		responderID              ResponderID,
 *		producedAt               GeneralizedTime,
 *		responses                SEQUENCE OF SingleResponse,
 *		responseExtensions   [1] EXPLICIT Extensions OPTIONAL }
 */
typedef struct {
    SecAsn1Item					*version;		// OPTIONAL
    SecAsn1Item					responderID;	// ASN_ANY here, decode/encode separately
    SecAsn1Item					producedAt;		// GeneralizedTime
    SecAsn1OCSPSingleResponse   **responses;
    NSS_CertExtension 			**responseExtensions;	// OPTIONAL
} SecAsn1OCSPResponseData;


typedef enum {
    RIT_Name	= 1,
    RIT_Key		= 2
} SecAsn1OCSPResponderIDTag;


/*
 * ResponderID ::= CHOICE {
 *     byName               EXPLICIT [1] Name,
 *     byKey                EXPLICIT [2] KeyHash }
 *
 * Since our ASN.1 encoder/decoder can't handle CHOICEs very well, we encode
 * this separately using one of the following two templates. On encode the
 * result if this step of the encode goes into SecAsn1OCSPResponseData.responderID,
 * where it's treated as an ANY_ANY when encoding that struct. The reverse happens
 * on decode.
 */
typedef union {
    SecAsn1Item					byName;
    SecAsn1Item					byKey;		// key hash in OCTET STRING
} SecAsn1OCSPResponderID;


/////////////////////////// ocspTemplates.h ///////////////////
/*
 * ResponseBytes ::=       SEQUENCE {
 *		responseType   OBJECT IDENTIFIER,
 *		response       OCTET STRING }
 *
 * The contents of response are actually an encoded SecAsn1OCSPBasicResponse (at
 * least until another response type is defined).
 */
typedef struct {
    SecAsn1Oid					responseType;
    SecAsn1Item					response;
} SecAsn1OCSPResponseBytes;

extern const SecAsn1Template kSecAsn1OCSPResponseBytesTemplate[];


typedef enum {
    CS_Good = 0,
    CS_Revoked = 1,
    CS_Unknown = 2,
    CS_NotParsed = 0xff		/* Not in protocol: means value not parsed or seen */
} SecAsn1OCSPCertStatusTag;

/*
 * OCSPResponse ::= SEQUENCE {
 *		responseStatus         OCSPResponseStatus,		-- an ENUM
 *		responseBytes          [0] EXPLICIT ResponseBytes OPTIONAL }
 */
typedef struct {
    SecAsn1Item					responseStatus;		// see enum below
    SecAsn1OCSPResponseBytes	*responseBytes;		// optional
} SecAsn1OCSPResponse;

/*
 * Request         ::=     SEQUENCE {
 *		reqCert                     CertID,
 *		singleRequestExtensions     [0] EXPLICIT Extensions OPTIONAL }
 */
typedef struct {
    SecAsn1OCSPCertID					reqCert;
    NSS_CertExtension 					**extensions;		// optional
} SecAsn1OCSPRequest;
    
/*
 * Signature       ::=     SEQUENCE {
 *		signatureAlgorithm      AlgorithmIdentifier,
 *		signature               BIT STRING,
 *		certs               [0] EXPLICIT SEQUENCE OF Certificate OPTIONAL}
 *
 * Since we wish to avoid knowing anything about the details of the certs,
 * we declare them here as ASN_ANY, get/set as raw data, and leave it to
 * the CL to parse them.
 */
typedef struct {
    SecAsn1AlgId		algId;
    SecAsn1Item							sig;		// length in BITS
    SecAsn1Item							**certs;	// OPTIONAL
} SecAsn1OCSPSignature;

    
/*
 * TBSRequest      ::=     SEQUENCE {
 *		version             [0]     EXPLICIT Version DEFAULT v1,
 *		requestorName       [1]     EXPLICIT GeneralName OPTIONAL,
 *		requestList                 SEQUENCE OF Request,
 *		requestExtensions   [2]     EXPLICIT Extensions OPTIONAL }
 */
typedef struct {
    SecAsn1Item							*version;				// OPTIONAL
    NSS_GeneralName						*requestorName;			// OPTIONAL
    SecAsn1OCSPRequest					**requestList;
    NSS_CertExtension 					**requestExtensions;	// OPTIONAL
} SecAsn1OCSPTbsRequest;

extern const SecAsn1Template kSecAsn1OCSPTbsRequestTemplate[];

/*
 * OCSPRequest     ::=     SEQUENCE {
 *		tbsRequest                  TBSRequest,
 *		optionalSignature   [0]     EXPLICIT Signature OPTIONAL }
 */
typedef struct {
    SecAsn1OCSPTbsRequest				tbsRequest;
    SecAsn1OCSPSignature				*signature;			// OPTIONAL
} SecAsn1OCSPSignedRequest;

extern const SecAsn1Template kSecAsn1OCSPSignedRequestTemplate[];

// MARK: ----- OCSP Response -----

/*
 * CertStatus ::= CHOICE {
 *		good        [0]     IMPLICIT NULL,
 *		revoked     [1]     IMPLICIT RevokedInfo,
 *		unknown     [2]     IMPLICIT UnknownInfo }
 *
 * RevokedInfo ::= SEQUENCE {
 *		revocationTime              GeneralizedTime,
 *		revocationReason    [0]     EXPLICIT CRLReason OPTIONAL }
 *
 * UnknownInfo ::= NULL -- this can be replaced with an enumeration
 *
 * See <Security/certextensions.h> for enum values of CE_CrlReason.
 */
typedef struct {
    SecAsn1Item					revocationTime;
    SecAsn1Item					*revocationReason;		// OPTIONAL, CE_CrlReason
} SecAsn1OCSPRevokedInfo;

typedef union {
    SecAsn1OCSPRevokedInfo		*revokedInfo;
    SecAsn1Item					*nullData;
} SecAsn1OCSPCertStatus;

    
    


#ifdef  __cplusplus
}
#endif

#endif	/* _OCSP_TEMPLATES_H_ */

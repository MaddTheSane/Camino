/* -*- Mode: C++; tab-width: 2; indent-tabs-mode: nil; c-basic-offset: 2 -*- */
/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

#import <AppKit/AppKit.h>

class nsIX509Cert;

// object is the CertificateItem. No userinfo.
extern NSString* const kCertificateChangedNotification;

// A class that wraps a single nsIX509Cert certificate object.
// Note that these aren't necessarily singletons (more than one
// per cert may exist; use -isEqual to test for equality). This
// is a limitation imposed by nsIX509Cert.
//
// Note also that the lifetimes of these things matter if you
// are deleting certs. NSS keeps the underlying certs around
// until the last ref to a nsIX509Cert* has gone away, so
// if you tell the nsIX509CertDB to delete a cert, you have to
// release all refs to the deleted cert before reloading the
// data source. Sucky, eh?
// 
@interface CertificateItem : NSObject
{
  nsIX509Cert*    mCert;    // owned

  NSDictionary*   mASN1InfoDict;    // owned. this is a nested set of dictionaries
                                    // keyed by nsIASN1Object display names
  
  unsigned long   mVerification;    // we cache this because it's slow to obtain
  BOOL            mGotVerification;
  BOOL            mDomainIsMismatched;
  NSString*       mFallbackProblemMessageKey;  // owned
}

+ (CertificateItem*)certificateItemWithCert:(nsIX509Cert*)inCert;
- (id)initWithCert:(nsIX509Cert*)inCert;

- (nsIX509Cert*)cert;   // does not addref
- (BOOL)isSameCertAs:(nsIX509Cert*)inCert;
- (BOOL)isEqualTo:(id)object;
- (BOOL)certificateIsIssuerCert:(CertificateItem*)inCert;
- (BOOL)certificateIsInParentChain:(CertificateItem*)inCert;   // includes self

- (NSString*)displayName;

- (NSString*)nickname;
- (NSString*)subjectName;
- (NSString*)organization;
- (NSString*)organizationalUnit;
- (NSString*)commonName;
- (NSString*)emailAddress;
- (NSString*)serialNumber;

- (NSString*)sha1Fingerprint;
- (NSString*)md5Fingerprint;

- (NSString*)issuerName;
- (NSString*)issuerCommonName;
- (NSString*)issuerOrganization;
- (NSString*)issuerOrganizationalUnit;

- (NSString*)signatureAlgorithm;
- (NSString*)signatureValue;
- (NSString*)signatureValue;

- (NSString*)publicKeyAlgorithm;
- (NSString*)publicKey;
- (NSString*)publicKeySizeBits;   // returns the wrong value at present

- (NSString*)version;   // certificate "Version"

// - (NSArray*)extensions;

- (NSString*)usagesStringIgnoringOSCP:(BOOL)inIgnoreOSCP;
// return an array of human-readable usage strings
- (NSArray*)validUsages;

- (BOOL)isRootCACert;
- (BOOL)isUntrustedRootCACert;

- (NSDate*)expiresDate;
- (NSString*)expiresString;

- (NSDate*)validFromDate;
- (NSString*)validFromString;

- (BOOL)isExpired;
- (BOOL)isNotYetValid;

// these just check the parent CA chain and expiry etc. They do not indicate
// validity for any particular usage (e.g. the cert may still be untrusted).
- (BOOL)isValid;
- (NSString*)validity;
- (NSAttributedString*)attributedShortValidityString;
- (NSAttributedString*)attributedLongValidityString;

- (BOOL)canGetTrust;
- (unsigned int)trustMaskForType:(unsigned int)inType;
- (BOOL)trustedFor:(unsigned int)inUsage asType:(unsigned int)inType;
- (BOOL)trustedForSSLAsType:(unsigned int)inType;
- (BOOL)trustedForEmailAsType:(unsigned int)inType;
- (BOOL)trustedForObjectSigningAsType:(unsigned int)inType;

// inUsageMask is flags in nsIX509CertDB
- (void)setTrustedFor:(unsigned int)inUsageMask asType:(unsigned int)inType;
- (void)setTrustedForSSL:(BOOL)inTrustSSL forEmail:(BOOL)inForEmail forObjSigning:(BOOL)inForObjSigning asType:(unsigned int)inType;

// Indicates that we are using this certificate in the context of a domain it
// isn't valid for, so it should not be considered valid.
- (void)setDomainIsMismatched:(BOOL)isMismatched;

// This is a hack to work around our inability to get correct certificate
// problem descriptions (bug 453075), for the cert override dialog case. It
// should be removed when that bug is fixed.
- (void)setFallbackProblemMessageKey:(NSString*)problemKey;

@end


class CertificateItemManagerObjects;

// an object that manages CertificateItems.
@interface CertificateItemManager : NSObject
{

  CertificateItemManagerObjects*      mDataObjects;   // C++ wrapper for nsCOMPtrs

}

+ (CertificateItemManager*)sharedCertificateItemManager;
+ (CertificateItem*)certificateItemWithCert:(nsIX509Cert*)inCert;

- (NSString*)valueForStringBundleKey:(NSString*)inKey;

@end


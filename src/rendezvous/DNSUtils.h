/* -*- Mode: C++; tab-width: 2; indent-tabs-mode: nil; c-basic-offset: 2 -*- */
/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

#ifndef DNSUtils_h__
#define DNSUtils_h__


// mDNS defines its own names for these common types to simplify portability across
// multiple platforms that may each have their own (different) names for these types.
typedef unsigned char  mDNSBool;
typedef   signed char  mDNSs8;
typedef unsigned char  mDNSu8;
typedef   signed short mDNSs16;
typedef unsigned short mDNSu16;
typedef   signed long  mDNSs32;
typedef unsigned long  mDNSu32;

// These types are for opaque two- and four-byte identifiers.
// The "NotAnInteger" fields of the unions allow the value to be conveniently passed around in a register
// for the sake of efficiency, but don't forget -- just because it is in a register doesn't mean it is an
// integer. Operations like add, multiply, increment, decrement, etc., are undefined for opaque identifiers.
typedef union { mDNSu8 b[2]; mDNSu16 NotAnInteger; } mDNSOpaque16;
typedef union { mDNSu8 b[4]; mDNSu32 NotAnInteger; } mDNSOpaque32;

typedef mDNSOpaque16 mDNSIPPort;        // An IP port is a two-byte opaque identifier (not an integer)
typedef mDNSOpaque32 mDNSIPAddr;        // An IP address is a four-byte opaque identifier (not an integer)

enum { mDNSfalse = 0, mDNStrue = 1 };

#define mDNSNULL 0L

typedef mDNSs32 mStatus;

#define MAX_DOMAIN_LABEL 63
typedef struct { mDNSu8 c[ 64]; } domainlabel;      // One label: length byte and up to 63 characters
#define MAX_DOMAIN_NAME 255
typedef struct { mDNSu8 c[256]; } domainname;       // Up to 255 bytes of length-prefixed domainlabels
typedef struct { mDNSu8 c[256]; } UTF8str255;       // Null-terminated C string

// ***************************************************************************
// DNS protocol message format

typedef struct
{
    mDNSOpaque16 id;
    mDNSOpaque16 flags;
    mDNSu16 numQuestions;
    mDNSu16 numAnswers;
    mDNSu16 numAuthorities;
    mDNSu16 numAdditionals;
} DNSMessageHeader;

// We can send and receive packets up to 9000 bytes (Ethernet Jumbo Frame size, if that ever becomes widely used)
// However, in the normal case we try to limit packets to 1500 bytes so that we don't get IP fragmentation on standard Ethernet
#define AbsoluteMaxDNSMessageData 8960
#define NormalMaxDNSMessageData 1460
typedef struct
{
    DNSMessageHeader h;                     // Note: Size 12 bytes
    mDNSu8 data[AbsoluteMaxDNSMessageData]; // 20 (IP) + 8 (UDP) + 12 (header) + 8960 (data) = 9000
} DNSMessage;

#ifdef __cplusplus
extern "C" {
#endif

char *ConvertDomainLabelToCStringWithEscape(const domainlabel *const label, char *ptr, char esc);
char *ConvertDomainNameToCStringWithEscape(const domainname *const name, char *ptr, char esc);

const mDNSu8 *DNS_SkipDomainName(const DNSMessage *const msg, const mDNSu8 *ptr, const mDNSu8 *const end);
const mDNSu8 *DNS_GetDomainName(const DNSMessage *const msg, const mDNSu8 *ptr, const mDNSu8 *const end, domainname *const name);
const mDNSu8 *DNS_SkipQuestion(const DNSMessage *msg, const mDNSu8 *ptr, const mDNSu8 *end);

#ifdef __cplusplus
}
#endif

#endif // DNSUtils_h__

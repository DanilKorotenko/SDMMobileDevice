//
//  SDMMD_lockdown_conn.h
//  SDM_MD_Tests
//
//  Created by Danil Korotenko on 7/2/24.
//

#import <Foundation/Foundation.h>

#import <openssl/bio.h>

NS_ASSUME_NONNULL_BEGIN

@interface SDMMD_lockdown_conn : NSObject

@property (readwrite) uint64_t  connection;
@property (readwrite) SSL       *ssl;
@property (readwrite) uint64_t  *pointer;
@property (readwrite) uint64_t  length;

@end

NS_ASSUME_NONNULL_END

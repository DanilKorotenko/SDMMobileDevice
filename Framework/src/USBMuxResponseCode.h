//
//  USBMuxResponseCode.h
//  SDMMobileDevice
//
//  Created by Danil Korotenko on 7/1/24.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface USBMuxResponseCode : NSObject

- (instancetype)initWithDictionary:(NSDictionary *)aDictionary;

@property(readonly) NSUInteger code;
@property(readonly) NSString *string;

@end

NS_ASSUME_NONNULL_END

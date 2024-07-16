//
//  DeviceRequest.h
//  SDMMobileDevice
//
//  Created by Danil Korotenko on 7/15/24.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface DeviceMessage : NSObject

- (instancetype)initWithRequest:(NSString *)aType;
- (instancetype)initMessageWithRequest:(NSString *)aType;

@property(readwrite) BOOL displayPass;
@property(readwrite) BOOL waitForDisconnect;

@property(readonly) NSDictionary *dictionary;

@end

NS_ASSUME_NONNULL_END

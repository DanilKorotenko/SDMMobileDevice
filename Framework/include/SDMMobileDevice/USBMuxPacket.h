//
//  USBMuxPacket.h
//  SDMMobileDevice
//
//  Created by Danil Korotenko on 7/2/24.
//

#import <Foundation/Foundation.h>
#import <SDMMobileDevice/SDMMD_USBMuxListener_Types.h>
NS_ASSUME_NONNULL_BEGIN

@interface USBMuxPacket : NSObject

- (instancetype)initWithType:(SDMMD_USBMuxPacketMessageType)type payload:(NSDictionary * _Nullable)dict;

@property(readwrite) uint32_t bodyLength;
@property(readwrite) uint32_t bodyReserved;
@property(readwrite) uint32_t bodyType;
@property(readwrite) uint32_t bodyTag;

@property(readonly) uint32_t bodySize;
- (void)setBodyWithPtr:(void *)aPtr;

@property(strong) NSDictionary *payload;
@property(readonly) NSData *bodyData;

@property(readonly) dispatch_time_t timeout;

@end

NS_ASSUME_NONNULL_END

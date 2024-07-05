//
//  UsbMuxPacketConnect.h
//  SDM_MD_Tests
//
//  Created by Danil Korotenko on 7/5/24.
//

#import <Foundation/Foundation.h>
#import "USBMuxPacket.h"

NS_ASSUME_NONNULL_BEGIN

@interface UsbMuxPacketConnect : USBMuxPacket

- (instancetype)initWithDeviceId:(NSInteger)aDeviceId portNumber:(NSInteger)aPortNumber;

@end

NS_ASSUME_NONNULL_END

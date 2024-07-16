//
//  SDMMD_lockdown_conn.m
//  SDM_MD_Tests
//
//  Created by Danil Korotenko on 7/2/24.
//

#import "SDMMD_lockdown_conn.h"

@implementation SDMMD_lockdown_conn

- (instancetype)initWithSocket:(uint32_t)socket
{
    self = [super init];
    if (self)
    {
        if (socket != 0)
        {
            self.connection = socket;
            self.length = 0;
        }
    }
    return self;
}

@end

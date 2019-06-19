//
//  RongMixerBuffer.m
//  RomanticAudioEngine
//
//  Created by 孙承秀 on 2019/6/18.
//  Copyright © 2019 RongCloud. All rights reserved.
//

#import "RongMixerBuffer.h"
#import "TPCircularBuffer.h"
static const int kActionBufferSize                          = 2048;
static const NSTimeInterval kActionMainThreadPollDuration   = 0.2;
static const NSTimeInterval kSourceTimestampIdleThreshold   = 1.0;

typedef struct {
    RongMixerBufferSource                     source;
    RongMixerBufferSourcePeekCallback         peekCallback;
    RongMixerBufferSourceRenderCallback       renderCallback;
    void                                   *callbackUserinfo;
    TPCircularBuffer                        buffer;
    uint64_t                                lastAudioTimestamp;
    BOOL                                    synced;
    UInt32                                  consumedFramesInCurrentTimeSlice;
    AudioStreamBasicDescription             audioDescription;
    void                                   *floatConverter;
    float                                   volume;
    float                                   pan;
    BOOL                                    started;
    AudioBufferList                        *skipFadeBuffer;
    BOOL                                    unregistering;
} source_t;
typedef void(*RongMixerBufferAction)(RongMixerBuffer *buffer, void *userInfo);
typedef struct {
    RongMixerBufferAction action;
    void *userInfo;
} action_t;
@interface RongMixerBuffer ()
{
    TPCircularBuffer            _mainThreadActionBuffer;
    NSTimer                    *_mainThreadActionPollTimer;
}

@end
@interface RongMixerBufferPollProxy : NSObject{
    __weak RongMixerBuffer *_mixerBuffer;
}
- (id)initWithMixerBuffer:(RongMixerBuffer *)mixerBuffer;
@end
@implementation RongMixerBuffer
-(id)initWithClientFormat:(AudioStreamBasicDescription)clientFormat{
    if(!(self = [super init])){
        return nil;
    }
    self.clientFormat = clientFormat;
    return self;
}
-(void)setClientFormat:(AudioStreamBasicDescription)clientFormat{
    
}
- (void)pollActionBuffer{
    
}
@end
@implementation RongMixerBufferPollProxy
-(id)initWithMixerBuffer:(RongMixerBuffer *)mixerBuffer{
    if(!(self = [super init])){
        return nil;
    }
    _mixerBuffer = mixerBuffer;
    return self;
}
- (void)pollActionBuffer {
    [_mixerBuffer pollActionBuffer];
}

@end

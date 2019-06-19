//
//  RongMixerBuffer.m
//  RomanticAudioEngine
//
//  Created by 孙承秀 on 2019/6/18.
//  Copyright © 2019 RongCloud. All rights reserved.
//

#import "RongMixerBuffer.h"
#import "TPCircularBuffer.h"
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
@implementation RongMixerBuffer

@end

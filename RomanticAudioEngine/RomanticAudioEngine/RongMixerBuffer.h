//
//  RongMixerBuffer.h
//  RomanticAudioEngine
//
//  Created by 孙承秀 on 2019/6/18.
//  Copyright © 2019 RongCloud. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>
NS_ASSUME_NONNULL_BEGIN

@interface RongMixerBuffer : NSObject
typedef void* RongMixerBufferSource;
typedef UInt32 (*RongMixerBufferSourcePeekCallback) (RongMixerBufferSource  source,
                                                   AudioTimeStamp      *outTimestamp,
                                                   void                *userInfo);
typedef void (*RongMixerBufferSourceRenderCallback) (RongMixerBufferSource       source,
                                                   UInt32                    frames,
                                                   AudioBufferList          *audio,
                                                   const AudioTimeStamp     *inTimeStamp,
                                                   void                     *userInfo);
@end

NS_ASSUME_NONNULL_END

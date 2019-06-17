//
//  RongAudioUnitChannel.h
//  RomanticAudioEngine
//
//  Created by 孙承秀 on 2019/6/13.
//  Copyright © 2019 RongCloud. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "RongAudioEngine.h"
#import "RongAudioPlayerProtocol.h"
NS_ASSUME_NONNULL_BEGIN

@interface RongAudioUnitChannel : NSObject<RongAudioPlayerProtocol>
- (id)initWithComponentDescription:(AudioComponentDescription)audioComponentDescription;

- (id)initWithComponentDescription:(AudioComponentDescription)audioComponentDescription
                preInitializeBlock:(nullable void(^)(AudioUnit audioUnit))preInitializeBlock;

- (double)getParameterValueForId:(AudioUnitParameterID)parameterId;

- (void)setParameterValue:(double)value forId:(AudioUnitParameterID)parameterId;

@property (nonatomic, assign) float volume;

@property (nonatomic, assign) float pan;

@property (nonatomic, assign) BOOL channelIsPlaying;

@property (nonatomic, assign) BOOL channelIsMuted;

@property (nonatomic, readonly) AudioUnit audioUnit;

@property (nonatomic, readonly) AUNode audioGraphNode;

AudioUnit RongAudioUnitChannelGetAudioUnit(__unsafe_unretained RongAudioUnitChannel * channel);
@end

NS_ASSUME_NONNULL_END

//
//  RongAudioPlayerProtocol.h
//  RomanticAudioEngine
//
//  Created by 孙承秀 on 2019/6/13.
//  Copyright © 2019 RongCloud. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "RongAudioEngine.h"
NS_ASSUME_NONNULL_BEGIN

typedef OSStatus (*AEAudioRenderCallback) (__unsafe_unretained id    channel,
                                           __unsafe_unretained RongAudioEngine *audioEngine,
                                           const AudioTimeStamp     *time,
                                           UInt32                    frames,
                                           AudioBufferList          *audio);

typedef AEAudioRenderCallback AEAudioControllerRenderCallback; // Temporary alias
@protocol RongAudioPlayerProtocol <NSObject>

/**
 render callback
 */
@property(nonatomic , readonly)AEAudioRenderCallback renderCallback;

@optional

- (void)setupWithAudioEngine:(RongAudioEngine *)audioEngine;

- (void)teardown;

@property (nonatomic, readonly) float volume;

@property (nonatomic, readonly) float pan;

@property (nonatomic, readonly) BOOL channelIsPlaying;

@property (nonatomic, readonly) BOOL channelIsMuted;

@property (nonatomic, readonly) AudioStreamBasicDescription audioDescription;
@end

NS_ASSUME_NONNULL_END

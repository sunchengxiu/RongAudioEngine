//
//  RongAudioEngine.h
//  RomanticAudioEngine
//
//  Created by 孙承秀 on 2019/6/11.
//  Copyright © 2019 RongCloud. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "RongAudioEngineDefine.h"
#import <AudioToolbox/AudioToolbox.h>
#import "RongAudioEngineNotification.h"
NS_ASSUME_NONNULL_BEGIN


@interface RongAudioEngine : NSObject

/**
 使用音频描述直接初始化

 @param audioDescription 音频描述
 @return 初始化的引擎
 */
- (id)initWithAudioDescription:(AudioStreamBasicDescription)audioDescription;

/**
 使用音频描述初始化，并指定是否允许输入

 @param audioDescription 音频描述
 @param enableInput 是否允许输入
 @return 音频引擎
 */
- (id)initWithAudioDescription:(AudioStreamBasicDescription)audioDescription inputEnabled:(BOOL)enableInput;

/**
 使用音频描述初始化，并指定语音处理选项

 @param audioDescription 音频描述
 @param options 语音处理选项
 @return 音频引擎
 */
- (id)initWithAudioDescription:(AudioStreamBasicDescription)audioDescription options:(RongAudioEngineUnitOptions)options;
@property (nonatomic, readonly) BOOL inputEnabled;

@property (nonatomic, readonly) BOOL outputEnabled;
@property (nonatomic, readonly) BOOL playingThroughDeviceSpeaker;
@property (nonatomic, readonly) BOOL recordingThroughDeviceMicrophone;
@property (nonatomic, readonly) BOOL running;
/*!
 * Whether to only perform voice processing for the SpeakerAndMicrophone route
 *
 *  This causes voice processing to only be enabled in the classic echo removal
 *  scenario, when audio is being played through the device speaker and recorded
 *  by the device microphone.
 *
 *  Default is YES.
 */
@property (nonatomic, assign) BOOL voiceProcessingOnlyForSpeakerAndMicrophone;
@property (nonatomic, assign) NSTimeInterval preferredBufferDuration;
@property (nonatomic, readonly) int numberOfInputChannels;
@property (nonatomic, assign) BOOL useMeasurementMode;
@property (nonatomic, assign) BOOL boostBuiltInMicGainInMeasurementMode;
@end

NS_ASSUME_NONNULL_END

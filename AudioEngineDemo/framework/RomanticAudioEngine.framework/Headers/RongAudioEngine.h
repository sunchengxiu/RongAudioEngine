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
@end

NS_ASSUME_NONNULL_END

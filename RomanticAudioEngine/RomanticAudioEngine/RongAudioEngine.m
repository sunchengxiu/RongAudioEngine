//
//  RongAudioEngine.m
//  RomanticAudioEngine
//
//  Created by 孙承秀 on 2019/6/11.
//  Copyright © 2019 RongCloud. All rights reserved.
//

#import "RongAudioEngine.h"
#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
@interface RongAudioEngine()
@property(nonatomic , assign)BOOL  alloclAudioEngine;
@property(nonatomic , copy)NSString *audioSessionCategory;
@property(nonatomic , assign)BOOL allowMixingWithOtherApps;
@property(nonatomic , assign)BOOL allowBluetoothInput;
@property(nonatomic , assign)BOOL allowVoiceProcessing;
@property(nonatomic , assign)AudioStreamBasicDescription audioDescription;
@property(nonatomic , assign)BOOL enableInput;
@property(nonatomic , assign)BOOL enableOutput;
@property(nonatomic , assign)BOOL useHardwareSampleRate;

@end
@implementation RongAudioEngine
-(id)initWithAudioDescription:(AudioStreamBasicDescription)audioDescription{
    return [self initWithAudioDescription:audioDescription options:RongAudioEngineUnitOptionDefaults];
}
-(id)initWithAudioDescription:(AudioStreamBasicDescription)audioDescription inputEnabled:(BOOL)enableInput{
    return [self initWithAudioDescription:audioDescription options:RongAudioEngineUnitOptionDefaults | (enableInput ? RongAudioEngineUnitOptionEnableInput : 0)];
}
-(id)initWithAudioDescription:(AudioStreamBasicDescription)audioDescription options:(RongAudioEngineUnitOptions)options{
    NSAssert([NSThread isMainThread], @"only on the main thread");
    NSAssert(!_alloclAudioEngine, @"only init once");
    _alloclAudioEngine = YES;
    BOOL enableInput = options & RongAudioEngineUnitOptionEnableInput;
    BOOL enableOutput = options & RongAudioEngineUnitOptionEnableOutput;
    _audioSessionCategory = enableInput ? (enableOutput ? AVAudioSessionCategoryPlayAndRecord : AVAudioSessionCategoryRecord) : AVAudioSessionCategoryPlayback;
    _allowBluetoothInput = options & RongAudioEngineUnitOptionEnableBluetoothInput;
    _allowMixingWithOtherApps = options & RongAudioEngineUnitOptionAllowMixingWithOtherApps;
    _allowVoiceProcessing = options & RongAudioEngineUnitOptionUseVoiceProcessing;
    _useHardwareSampleRate = options & RongAudioEngineUnitOptionUseHardwareSampleRate;
    return nil;
}
@end

//
//  RongAudioUnitChannel.m
//  RomanticAudioEngine
//
//  Created by 孙承秀 on 2019/6/13.
//  Copyright © 2019 RongCloud. All rights reserved.
//

#import "RongAudioUnitChannel.h"
#import "RongAudioEngine+Private.h"
#import "RongAudioUtilities.h"
@interface RongAudioUnitChannel(){
    AudioComponentDescription _componentDescription;
    AUGraph _audioGraph;
    AUNode _node;
    AudioUnit _audioUnit;
    AUNode _converterNode;
    AudioUnit _converterUnit;
}
@property (nonatomic, copy) void (^preInitializeBlock)(AudioUnit audioUnit);
@property (nonatomic, strong) NSMutableDictionary * savedParameters;

@end
@implementation RongAudioUnitChannel
-(id)initWithComponentDescription:(AudioComponentDescription)audioComponentDescription{
    return [self initWithComponentDescription:audioComponentDescription preInitializeBlock:nil];
}
-(id)initWithComponentDescription:(AudioComponentDescription)audioComponentDescription preInitializeBlock:(void (^)(AudioUnit _Nonnull))preInitializeBlock{
    if (self = [super init]) {
        _componentDescription = audioComponentDescription;
        self.preInitializeBlock = preInitializeBlock;
        self.volume = 1.0;
        self.pan = 0.0;
        self.channelIsMuted = NO;
        self.channelIsPlaying = YES;
        return self;
    }
    return nil;
}
-(void)setupWithAudioEngine:(RongAudioEngine *)audioEngine{
    _audioGraph = audioEngine.audioGraph;
    OSStatus result;
    if (!RongCheckOSStatus(AUGraphAddNode(_audioGraph, &_componentDescription, &_node), "AUGraphAddNode") || RongCheckOSStatus(AUGraphNodeInfo(_audioGraph, _node, &_componentDescription, &_audioUnit), "AUGraphNodeInfo")) {
        NSLog(@"file player couldnt init");
        return;
    }
    UInt32 maxFPS = 4096;
    RongCheckOSStatus(AudioUnitSetProperty(_audioUnit, kAudioUnitProperty_MaximumFramesPerSlice, kAudioUnitScope_Global, 0, &maxFPS, sizeof(maxFPS)),  "kAudioUnitProperty_MaximumFramesPerSlice");
    AudioStreamBasicDescription audioDescription = audioEngine.audioDescription;
    result = AudioUnitSetProperty(_audioUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Global, 0, &audioDescription, sizeof(AudioStreamBasicDescription));
    if (result == kAudioUnitErr_FormatNotSupported) {
        AudioStreamBasicDescription defaultDescription;
        UInt32 size= sizeof(defaultDescription);
        AudioUnitGetProperty(_audioUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Global, 0, &defaultDescription, &size);
        defaultDescription.mSampleRate = audioDescription.mSampleRate;
        RongAudioStreamBasicDescriptionSetChannelsPerFrame(&defaultDescription, audioDescription.mChannelsPerFrame);
        if (!RongCheckOSStatus(AudioUnitGetProperty(_audioUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Global, 0, &defaultDescription, &size), "AudioUnitSetProperty")) {
            AUGraphRemoveNode(_audioGraph, _node);
            _node = 0 ;
            _audioUnit = NULL;
            NSLog(@"unit channel set not support stream format error");
            return;
        }
        AudioComponentDescription componentDescription = RongAudioComponentDescriptionMake(kAudioUnitManufacturer_Apple, kAudioUnitType_FormatConverter, kAudioUnitSubType_AUConverter);
        if (!RongCheckOSStatus(AUGraphAddNode(_audioGraph, &componentDescription, &_converterNode), "AUGraphAddNode") || !RongCheckOSStatus(AUGraphNodeInfo(_audioGraph, _converterNode, NULL, &_converterUnit), "AUGraphNodeInfo") || !RongCheckOSStatus(AudioUnitSetProperty(_converterUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Global, 0, &audioDescription, sizeof(AudioStreamBasicDescription)), "AudioUnitSetProperty(kAudioUnitProperty_StreamFormat)") || !RongCheckOSStatus(AudioUnitSetProperty(_converterUnit, kAudioUnitProperty_MaximumFramesPerSlice, kAudioUnitScope_Global, 0, &maxFPS, sizeof(maxFPS)), "kAudioUnitProperty_MaximumFramesPerSlice") || !RongCheckOSStatus(AudioUnitGetProperty(_converterUnit, kAudioUnitProperty_MakeConnection, kAudioUnitScope_Input, 0, &(AudioUnitConnection) {
            .sourceAudioUnit = _audioUnit,
            .sourceOutputNumber = 0,
            .destInputNumber = 0
        }, sizeof(AudioUnitConnection)), "kAudioUnitProperty_MakeConnection")) {
            AUGraphRemoveNode(_audioGraph, _node);
            _node = 0;
            _audioUnit = NULL;
            if (_converterNode) {
                AUGraphRemoveNode(_audioGraph, _converterNode);
                _converterNode = 0;
                _converterUnit = NULL;
            }
            return;
        }
    }
    if (_savedParameters) {
        for (NSNumber *key in _savedParameters.allKeys) {
            NSNumber *value = _savedParameters[key];
            RongCheckOSStatus(AudioUnitSetParameter(_audioUnit, (AudioUnitParameterID)[key unsignedIntValue], kAudioUnitScope_Global, 0, (AudioUnitParameterValue)[value doubleValue] ,0), "AudioUnitSetParameter");
        }
    }
    if (_preInitializeBlock) {
        _preInitializeBlock(_audioUnit);
    }
    AudioUnitInitialize(_audioUnit);
    if (_converterUnit) {
        _preInitializeBlock(_converterUnit);
    }
}
-(void)teardown{
    if (_node) {
        AUGraphRemoveNode(_audioGraph, _node);
        _node = 0;
        _audioUnit = NULL;
    }
    if (_converterNode) {
        AUGraphRemoveNode(_audioGraph, _converterNode);
        _converterNode = 0;
        _converterUnit = NULL;
    }
    _audioGraph = NULL;
}
-(void)dealloc{
    if (_audioUnit) {
        [self teardown];
    }
}
-(double)getParameterValueForId:(AudioUnitParameterID)parameterId{
    if (!_audioUnit) {
        return [_savedParameters[@(parameterId)] doubleValue];
    }
    AudioUnitParameterValue value = 0;
    RongCheckOSStatus(AudioUnitGetParameter(_audioUnit, parameterId, kAudioUnitScope_Global, 0, &value), "AudioUnitGetParameter");
    return value;
}
-(void)setParameterValue:(double)value forId:(AudioUnitParameterID)parameterId{
    if (!_savedParameters) {
        _savedParameters = [[NSMutableDictionary alloc] init];
    }
    _savedParameters[@(parameterId)] = @(value);
    if (_audioUnit) {
        RongCheckOSStatus(AudioUnitSetParameter(_audioUnit, parameterId, kAudioUnitScope_Global, 0, value, 0), "AudioUnitSetParameter");
    }
}
-(AudioUnit)audioUnit{
    return _audioUnit;
}
AudioUnit RongAudioUnitChannelGetAudioUnit(__unsafe_unretained RongAudioUnitChannel * channel){
    return channel->_audioUnit;
}

static OSStatus renderCallback(__unsafe_unretained RongAudioUnitChannel*    THIS,
                               __unsafe_unretained RongAudioEngine *audioEngine,
                               const AudioTimeStamp     *time,
                               UInt32                    frames,
                               AudioBufferList          *audio) {
    
    if ( !THIS->_audioUnit ) {
        return noErr;
    }
    
    AudioUnitRenderActionFlags flags = 0;
    RongCheckOSStatus(AudioUnitRender(THIS->_converterUnit ? THIS->_converterUnit : THIS->_audioUnit, &flags, time, 0, frames, audio), "AudioUnitRender");
    return noErr;
}
-(AEAudioRenderCallback)renderCallback{
    return renderCallback;
}
@end

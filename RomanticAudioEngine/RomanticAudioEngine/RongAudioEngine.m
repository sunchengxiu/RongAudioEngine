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
#import <UIKit/UIKit.h>
#import "RongAudioMessageQueue.h"
#import <RongAudioUtilities.h>
#import "RongFloatConverter.h"
typedef enum {
    RongInputModeFixedAudioFormat,
    RongInputModeVariableAudioFormat
} RongInputMode;
static const int kMessageBufferLength                  = 8192;
static const NSTimeInterval kMaxBufferDurationWithVPIO = 0.01;
static const UInt32 kMaxFramesPerSlice                 = 4096;
static const int kInputAudioBufferFrames               = kMaxFramesPerSlice;
@interface RongAudioEngineMessageQueue : RongAudioMessageQueue

@property(nonatomic , strong)RongAudioEngine *audioEngine;

@end
@implementation RongAudioEngineMessageQueue

- (void)performAsynchronousMessageExchangeWithBlock:(void (^)(void))block responseBlock:(void (^)(void))responseBlock{
    if (_audioEngine.running) {
        [super RongPerformAsynchronousMessageExchangeWithBlock:block responseBlock:responseBlock];
    } else {
        if (block) {
            block();
        }
        if (responseBlock) {
            responseBlock();
        }
    }
}
- (BOOL)performSynchronousMessageExchangeWithBlock:(void (^)(void))block {
    if (_audioEngine.running) {
        [super RongPerformSynchronousMessageExchangeWithBlock:block];
    } else {
        if (block) {
            block();
        }
    }
    return YES;
}
@end
@interface RongAudioEngineProxy : NSProxy
- (id)initWithAudioEngine:(RongAudioEngine*)audionEngine;
@property (nonatomic, weak) RongAudioEngine *audioEngine;

@end
static const int kMaximumCallbacksPerSource            = 15;

/*!
 * Callback
 */
typedef struct __callback_t {
    void *callback;
    void *userInfo;
    uint8_t flags;
} callback_t;
typedef struct __callback_table_t {
    int count;
    callback_t callbacks[kMaximumCallbacksPerSource];
} callback_table_t;
typedef struct {
    callback_table_t    callbacks;
    void               *channelMap;
    AudioStreamBasicDescription audioDescription;
    AudioBufferList    *audioBufferList;
    AudioConverterRef   audioConverter;
} input_entry_t;

typedef struct {
    int count;
    input_entry_t * entries;
} input_table_t;





@interface RongAudioEngine(){
    input_table_t      *_inputTable;
    AUGraph             _audioGraph;
    AUNode              _ioNode;
    AudioUnit           _ioAudioUnit;
    BOOL                _updatingInputStatus;
    AudioStreamBasicDescription _rawInputAudioDescription;
    AudioBufferList    *_inputAudioBufferList;
    AudioBufferList    *_inputAudioScratchBufferList;
    RongFloatConverter   *_inputAudioFloatConverter;

}
@property(nonatomic , assign)BOOL  alloclAudioEngine;
@property(nonatomic , copy)NSString *audioSessionCategory;
@property(nonatomic , assign)BOOL allowMixingWithOtherApps;
@property(nonatomic , assign)BOOL allowBluetoothInput;
@property(nonatomic , assign)BOOL allowVoiceProcessing;
@property(nonatomic , assign)AudioStreamBasicDescription audioDescription;
@property(nonatomic , assign)BOOL inputEnabled;
@property(nonatomic , assign)BOOL outputEnabled;
@property (nonatomic, assign) RongInputMode inputMode;
@property(nonatomic , assign)BOOL useHardwareSampleRate;
@property (nonatomic, strong) NSTimer *housekeepingTimer;
@property(nonatomic , strong)RongAudioEngineMessageQueue *messageQueue;
@property (nonatomic, assign) NSTimeInterval currentBufferDuration;
@property (nonatomic, assign) BOOL playingThroughDeviceSpeaker;
@property (nonatomic, assign) BOOL recordingThroughDeviceMicrophone;

@end

@implementation RongAudioEngine
static OSStatus ioUnitRenderNotifyCallback(void *inRefCon, AudioUnitRenderActionFlags *ioActionFlags, const AudioTimeStamp *inTimeStamp, UInt32 inBusNumber, UInt32 inNumberFrames, AudioBufferList *ioData) {
    return noErr;
}
static OSStatus inputAvailableCallback(void *inRefCon, AudioUnitRenderActionFlags *ioActionFlags, const AudioTimeStamp *inTimeStamp, UInt32 inBusNumber, UInt32 inNumberFrames, AudioBufferList *ioData){
    return noErr;
}
static void audioUnitStreamFormatChanged(void *inRefCon, AudioUnit inUnit, AudioUnitPropertyID inID, AudioUnitScope inScope, AudioUnitElement inElement) {
    
}
static void interAppConnectedChangeCallback(void *inRefCon, AudioUnit inUnit, AudioUnitPropertyID inID, AudioUnitScope inScope, AudioUnitElement inElement) {
    
}
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
    _inputEnabled = enableInput;
    _outputEnabled = enableOutput;
    _inputMode = RongInputModeFixedAudioFormat;
    _audioDescription = audioDescription;
    _audioSessionCategory = enableInput ? (enableOutput ? AVAudioSessionCategoryPlayAndRecord : AVAudioSessionCategoryRecord) : AVAudioSessionCategoryPlayback;
    _allowBluetoothInput = options & RongAudioEngineUnitOptionEnableBluetoothInput;
    _allowMixingWithOtherApps = options & RongAudioEngineUnitOptionAllowMixingWithOtherApps;
    _allowVoiceProcessing = options & RongAudioEngineUnitOptionUseVoiceProcessing;
    _useHardwareSampleRate = options & RongAudioEngineUnitOptionUseHardwareSampleRate;
    _inputTable = (input_table_t *)calloc(sizeof(input_table_t), 1);
    _inputTable->count = 1;
    _inputTable->entries = (input_entry_t *)calloc(sizeof(input_entry_t), 1);
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationWillEnterForeground:) name:UIApplicationWillEnterForegroundNotification object:nil];
     [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(audiobusConnectionsChanged:) name:RongAudioConnectionsChangedNotification object:nil];
    _messageQueue = [[RongAudioEngineMessageQueue alloc] initWithMessageBufferLength:kMessageBufferLength];
    _messageQueue.audioEngine = self;
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(interruptionNotification:) name:AVAudioSessionInterruptionNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(audioRouteChangeNotification:) name:AVAudioSessionRouteChangeNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(mediaServiceResetNotification:) name:AVAudioSessionMediaServicesWereResetNotification object:nil];
    self.housekeepingTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 target:[[RongAudioEngineProxy alloc] initWithAudioEngine:self] selector:@selector(housekeeping) userInfo:nil repeats:YES];
    return self;
}
- (BOOL)setup{
    OSStatus result = NewAUGraph(&_audioGraph);
    if (RongCheckOSStatus(result, "NewAUGraph")) {
        return NO;
    }
    BOOL useVoiceProcessing = [self usingVPIO];
    OSType subtype;
    if (useVoiceProcessing) {
        subtype = kAudioUnitSubType_VoiceProcessingIO;
    } else {
        subtype = kAudioUnitSubType_RemoteIO;
    }
    AudioComponentDescription io_description = {
        .componentType = kAudioUnitType_Output,
        .componentSubType = subtype,
        .componentManufacturer = kAudioUnitManufacturer_Apple,
        .componentFlags = 0,
        .componentFlagsMask = 0
    };
    result = AUGraphAddNode(_audioGraph, &io_description, &_ioNode);
    if ( !RongCheckOSStatus(result, "AUGraphAddNode io") ) return NO;
    
    result = AUGraphOpen(_audioGraph);
    if ( !RongCheckOSStatus(result, "AUGraphOpen") ) return NO;
    
    result = AUGraphNodeInfo(_audioGraph, _ioNode, &io_description, &_ioAudioUnit);
    if ( !RongCheckOSStatus(result, "AUGraphNodeInfo") ) return NO;
    
    RongCheckOSStatus(AudioUnitAddRenderNotify(_ioAudioUnit, &ioUnitRenderNotifyCallback, (__bridge void*)self), "AudioUnitAddRenderNotify");
    
    [self configAudioUnit];
    return YES;
}
- (void)updateInputDeviceStatus{
    if (!_audioGraph) {
        return;
    }
    NSAssert(_inputEnabled,@"input must be enable");
    if (_updatingInputStatus && self.running) {
        [_messageQueue performAsynchronousMessageExchangeWithBlock:^{
            
        } responseBlock:^{
            [self updateInputDeviceStatus];
        }];
        return;
    }
    _updatingInputStatus = YES;
    [self beginMessageExchangeBlock];
    int numberOfChannel = [self lookupNumberOfInputChannels];
    BOOL inputDescriptionChaned = numberOfChannel != _numberOfInputChannels;
    AudioStreamBasicDescription rawDescription = _audioDescription;
    if (numberOfChannel > 0) {
        RongAudioStreamBasicDescriptionSetChannelsPerFrame(&rawDescription, numberOfChannel);
        for (int index = 0; index < _inputTable->count; index ++) {
            input_entry_t *entry = &_inputTable->entries[index];
            AudioStreamBasicDescription audioDescription = _audioDescription;
            if (_inputMode == RongInputModeVariableAudioFormat) {
                audioDescription = rawDescription;
                if ([(__bridge NSArray *)entry->channelMap count] > 0) {
                    RongAudioStreamBasicDescriptionSetChannelsPerFrame(&audioDescription, (int)[(__bridge NSArray *)entry->channelMap count]);
                }
            }
            if (!entry->audioBufferList || memcmp(&audioDescription, &entry->audioDescription, sizeof(audioDescription)) != 0) {
                if (index == 0) {
                    inputDescriptionChaned = YES;
                }
                __block AudioBufferList *priBufferList = entry->audioBufferList;
                entry->audioDescription = audioDescription;
                entry->audioBufferList = RongAudioBufferListCreate(entry->audioDescription, kInputAudioBufferFrames);
                if (priBufferList) {
                    [_messageQueue performAsynchronousMessageExchangeWithBlock:^{
                        
                    } responseBlock:^{
                        RongAudioBufferListFree(priBufferList);
                    }];
                }
            }
            BOOL sampleRateConverterRequired = NO;
            BOOL converterRequired = sampleRateConverterRequired || audioDescription.mChannelsPerFrame != numberOfChannel || (entry->channelMap &&  audioDescription.mChannelsPerFrame != [(__bridge NSArray *)entry->channelMap count]);
            if (!converterRequired && entry->channelMap) {
                for (int i = 0 ; i < [(__bridge NSArray *)entry->channelMap count]; i ++) {
                    id channelMap = ((__bridge  NSArray *)entry->channelMap)[i];
                    if (([channelMap isKindOfClass:[NSArray class]] && ([channelMap count] > 1 || [channelMap[0] intValue] != i)) || ([channelMap isKindOfClass:[NSNumber class]] && [channelMap intValue] != i)) {
                        converterRequired = YES;
                    }
                    
                }
            }
            if (index == 0) {
                if (!converterRequired) {
                    rawDescription = audioDescription;
                }
            }
            if (converterRequired) {
                UInt32 channelMapSize = sizeof(SInt32) * audioDescription.mChannelsPerFrame;
                SInt32 *channelMap = (SInt32 *)malloc(channelMapSize);
                for (int i = 0 ; i < entry->audioDescription.mChannelsPerFrame; i ++) {
                    if ([(__bridge NSArray *)entry->channelMap count] > 0) {
                        channelMap[i] = MIN(numberOfChannel - 1, [((__bridge NSArray *)entry->channelMap) count] > i ? [((__bridge NSArray *)entry->channelMap)[i] intValue] : [[((__bridge NSArray *)entry->channelMap) lastObject] intValue]);
                    } else {
                        channelMap[i] = MIN(numberOfChannel - 1, i);
                    }
                }
                AudioStreamBasicDescription converterInputFormat ;
                AudioStreamBasicDescription converterOutputFormat;
                UInt32 frameSize = sizeof(converterOutputFormat);
                UInt32 currentChannelMapingSize = 0;
                if (entry->audioConverter) {
                    RongCheckOSStatus(AudioConverterGetPropertyInfo(entry->audioConverter, kAudioConverterChannelMap, &currentChannelMapingSize, NULL),  "AudioConverterGetPropertyInfo(kAudioConverterChannelMap)");
                }
                SInt32 *currentMaping = (SInt32 *)(currentChannelMapingSize != 0 ? malloc(currentChannelMapingSize) : NULL);
                if (entry->audioConverter) {
                    RongCheckOSStatus(AudioConverterGetProperty(entry->audioConverter, kAudioConverterCurrentInputStreamDescription, &frameSize, &converterInputFormat), "AudioConverterGetProperty(kAudioConverterCurrentInputStreamDescription)");
                    RongCheckOSStatus(AudioConverterGetProperty(entry->audioConverter, kAudioConverterCurrentOutputStreamDescription, &frameSize, &converterOutputFormat), "AudioConverterGetProperty(kAudioConverterCurrentOutputStreamDescription)");
                    if (currentMaping) {
                        RongCheckOSStatus(AudioConverterGetProperty(entry->audioConverter, kAudioConverterChannelMap, &currentChannelMapingSize, currentMaping), "AudioConverterGetProperty(kAudioConverterChannelMap)");
                    }
                }
                if (!entry->audioConverter || memcmp(&rawDescription, &converterInputFormat, sizeof(AudioStreamBasicDescription)) != 0 || memcmp(&converterOutputFormat, &entry->audioDescription, sizeof(AudioStreamBasicDescription)) != 0 || (currentChannelMapingSize != channelMapSize) || memcmp(currentMaping, channelMap, channelMapSize) != 0) {
                    AudioConverterRef newConverter ;
                    RongCheckOSStatus(AudioConverterNew(&rawDescription, &entry->audioDescription, &newConverter), "AudioConverterNew");
                    RongCheckOSStatus(AudioConverterSetProperty(newConverter, kAudioConverterChannelMap, channelMapSize, channelMap), "AudioConverterSetProperty(kAudioConverterChannelMap");
                    __block AudioConverterRef old ;
                    [_messageQueue performAsynchronousMessageExchangeWithBlock:^{
                        old = entry->audioConverter;entry->audioConverter = newConverter;
                    } responseBlock:^{
                        if (old) {
                            AudioConverterDispose(old);
                        }
                    }];
                    if (currentMaping) {
                        free(currentMaping);
                    }
                    if (channelMap) {
                        free(channelMap);
                        channelMap = NULL;
                    }
                }
            } else {
                if (entry->audioConverter) {
                    __block AudioConverterRef old ;
                    [_messageQueue performAsynchronousMessageExchangeWithBlock:^{
                        old = entry->audioConverter;entry->audioConverter = NULL;
                    } responseBlock:^{
                        if (old) {
                            AudioConverterDispose(old);
                        }
                    }];
                }
            }
        }
        
        
        
    }
    
    
}
- (void)configAudioUnit{
    AVAudioSession *audioSession = [AVAudioSession sharedInstance];
    if (_inputEnabled) {
        UInt32 enableInputFlag = 1;
        OSStatus result = AudioUnitSetProperty(_ioAudioUnit, kAudioOutputUnitProperty_EnableIO, kAudioUnitScope_Input, 1, &enableInputFlag, sizeof(enableInputFlag));
        RongCheckOSStatus(result, "AudioUnitSetProperty(kAudioOutputUnitProperty_EnableIO)");
        
        AURenderCallbackStruct callback;
        callback.inputProc = &inputAvailableCallback;
        callback.inputProcRefCon = (__bridge void *)self;
        result = AudioUnitSetProperty(_ioAudioUnit, kAudioUnitProperty_SetRenderCallback, kAudioUnitScope_Global, 0, &callback, sizeof(callback));
        RongCheckOSStatus(result, "AudioUnitSetProperty(kAudioOutputUnitProperty_SetInputCallback)");
    } else {
        UInt32 enableInputFlag = 0;
        OSStatus result = AudioUnitSetProperty(_ioAudioUnit, kAudioOutputUnitProperty_EnableIO, kAudioUnitScope_Input, 1, &enableInputFlag, sizeof(enableInputFlag));
        RongCheckOSStatus(result, "AudioUnitSetProperty(kAudioOutputUnitProperty_EnableIO)");
    }
    if (!_outputEnabled) {
        UInt32 enableOutputFlag = 0;
        OSStatus result = AudioUnitSetProperty(_ioAudioUnit, kAudioOutputUnitProperty_EnableIO, kAudioUnitScope_Output, 0, &enableOutputFlag, sizeof(enableOutputFlag));
        RongCheckOSStatus(result, "AudioUnitSetProperty(kAudioOutputUnitProperty_EnableIO) OUTPUT");
    }
    if ([self usingVPIO]) {
        if (_preferredBufferDuration) {
            Float32 duration = MAX(_preferredBufferDuration, kMaxBufferDurationWithVPIO);
            NSError *error = nil;
            if (![audioSession setPreferredIOBufferDuration:duration error:&error]) {
                NSLog(@"use VPIO  , audio set preferred io buffer duration error:%@",error);
            }
        }
    } else {
        if (_preferredBufferDuration) {
            NSError *error = nil;
            if (![audioSession setPreferredIOBufferDuration:_preferredBufferDuration error:&error]) {
                 NSLog(@"not use VPIO  , audio set preferred io buffer duration error:%@",error);
            }
        }
    }
    
    RongCheckOSStatus(AudioUnitSetProperty(_ioAudioUnit, kAudioUnitProperty_MaximumFramesPerSlice, kAudioUnitScope_Global, 0, &kMaxFramesPerSlice, sizeof(kMaxFramesPerSlice)), "AudioUnitSetProperty(kAudioUnitProperty_MaximumFramesPerSlice)");
    RongCheckOSStatus(AudioUnitAddPropertyListener(_ioAudioUnit, kAudioUnitProperty_StreamFormat, audioUnitStreamFormatChanged, (__bridge void *)self), "AudioUnitAddPropertyListener(kAudioUnitProperty_StreamFormat)");
    RongCheckOSStatus(AudioUnitAddPropertyListener(_ioAudioUnit, kAudioUnitProperty_IsInterAppConnected, interAppConnectedChangeCallback, (__bridge void *)self), "AudioUnitAddPropertyListener(kAudioUnitProperty_IsInterAppConnected)");
    
}
- (BOOL)initAudioSession{
    AVAudioSession *audioSession = [AVAudioSession sharedInstance];
    NSMutableString *extraInfo = [NSMutableString string];
    NSError *error = nil;
    [self setAudioSessionCategory:_audioSessionCategory];
    if ( audioSession.inputAvailable ) [extraInfo appendFormat:@", input available"];
    if ([audioSession setActive:YES error:&error]) {
        NSLog(@"audio session set active error:%@",error);
    }
    Float64 sampleRate = _audioDescription.mSampleRate;
    if (![audioSession setPreferredSampleRate:sampleRate error:&error]) {
        NSLog(@"audio session set preferred sample rate error:%@",error);
    }
    Float64 hardwareSampleRate = audioSession.sampleRate;
    if (hardwareSampleRate != sampleRate) {
        if (_useHardwareSampleRate) {
            _audioDescription.mSampleRate = hardwareSampleRate;
            NSLog(@"user hardware sample rate : %f",hardwareSampleRate);
        } else {
             NSLog(@"user client sample rate : %f",sampleRate);
        }
    }
    AVAudioSessionRouteDescription *currentRoute = audioSession.currentRoute;
    [extraInfo appendFormat:@", audio route '%@'", [self stringFromRouteDescription:currentRoute]];
    if ( [currentRoute.outputs filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"portType = %@", AVAudioSessionPortBuiltInSpeaker]].count > 0 ) {
        _playingThroughDeviceSpeaker = YES;
    } else {
        _playingThroughDeviceSpeaker = NO;
    }
    
    if ( [currentRoute.inputs filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"portType = %@", AVAudioSessionPortBuiltInMic]].count > 0 ) {
        _recordingThroughDeviceMicrophone = YES;
    } else {
        _recordingThroughDeviceMicrophone = NO;
    }
    
    // Determine IO buffer duration
    Float32 bufferDuration = audioSession.IOBufferDuration;
    if ( _currentBufferDuration != bufferDuration ) self.currentBufferDuration = bufferDuration;
    NSLog(@"%@",extraInfo);
    return  YES;
}
- (void)setAudioSessionCategory:(NSString *)audioSessionCategory{
    AVAudioSession *audioSession = [AVAudioSession sharedInstance];
    if (![audioSession.category isEqualToString:audioSessionCategory]) {
        NSLog(@"audio session category change to :%@",audioSessionCategory);
    }
    _audioSessionCategory = audioSessionCategory;
    if (!audioSession.inputAvailable && ([audioSessionCategory isEqualToString:AVAudioSessionCategoryRecord] || [audioSessionCategory isEqualToString:AVAudioSessionCategoryPlayAndRecord])) {
        _audioSessionCategory = AVAudioSessionCategoryPlayback;
        NSLog(@"audio session is not input available , playback ");
    }
    int options = 0;
    if ([audioSessionCategory isEqualToString:AVAudioSessionCategoryPlayAndRecord]) {
        options |= AVAudioSessionCategoryOptionDefaultToSpeaker;
        options |= _allowBluetoothInput ? AVAudioSessionCategoryOptionAllowBluetoothA2DP : 0;
    }
    if ([audioSessionCategory isEqualToString:AVAudioSessionCategoryPlayAndRecord] || [audioSessionCategory isEqualToString:AVAudioSessionCategoryPlayback]) {
        options |= _allowMixingWithOtherApps ? AVAudioSessionCategoryOptionMixWithOthers : 0;
    }
    NSError *error = nil;
    if ([audioSession setCategory:audioSessionCategory withOptions:options error:&error]) {
        NSLog(@"audio session set category error");
    }
}

-(BOOL)running{
    Boolean audioUnitIsRunning ;
    UInt32 size = sizeof(audioUnitIsRunning);
    if (RongCheckOSStatus(AudioUnitGetProperty(_ioAudioUnit, kAudioOutputUnitProperty_IsRunning, kAudioUnitScope_Global, 0, &audioUnitIsRunning, &size), "kAudioOutputUnitProperty_IsRunning")) {
        return audioUnitIsRunning;
    } else {
        return NO;
    }
}
- (BOOL)usingVPIO {
    return _allowVoiceProcessing && _inputEnabled && (!_voiceProcessingOnlyForSpeakerAndMicrophone || _playingThroughDeviceSpeaker);
}
-(void)setPreferredBufferDuration:(NSTimeInterval)preferredBufferDuration{
    if (_preferredBufferDuration == preferredBufferDuration) {
        return;
    }
    _preferredBufferDuration = preferredBufferDuration;
    AVAudioSession *audioSession = [AVAudioSession sharedInstance];
    NSError *error = nil;
    if (![audioSession setPreferredIOBufferDuration:_preferredBufferDuration error:&error]) {
        NSLog(@"audio session set preferred buffer duration error :%@",error);
    }
    NSTimeInterval orinal = audioSession.preferredIOBufferDuration;
    if (_preferredBufferDuration != orinal) {
        self.preferredBufferDuration = orinal;
    }
}
- (int)lookupNumberOfInputChannels{
    return (int)[AVAudioSession sharedInstance].inputNumberOfChannels;
}
- (void)beginMessageExchangeBlock {
    [_messageQueue beginMessageExchangeBlock];
}

- (void)endMessageExchangeBlock {
    [_messageQueue endMessageExchangeBlock];
}

- (NSString*)stringFromRouteDescription:(AVAudioSessionRouteDescription*)routeDescription {
    
    NSMutableString *inputsString = [NSMutableString string];
    for ( AVAudioSessionPortDescription *port in routeDescription.inputs ) {
        [inputsString appendFormat:@"%@%@", inputsString.length > 0 ? @", " : @"", port.portName];
    }
    NSMutableString *outputsString = [NSMutableString string];
    for ( AVAudioSessionPortDescription *port in routeDescription.outputs ) {
        [outputsString appendFormat:@"%@%@", outputsString.length > 0 ? @", " : @"", port.portName];
    }
    
    return [NSString stringWithFormat:@"%@%@%@", inputsString, inputsString.length > 0 && outputsString.length > 0 ? @" and " : @"", outputsString];
}
- (void)housekeeping {
    Float32 bufferDuration = [((AVAudioSession*)[AVAudioSession sharedInstance]) IOBufferDuration];
    if ( _currentBufferDuration != bufferDuration ) self.currentBufferDuration = bufferDuration;
}

- (void)mediaServiceResetNotification:(NSNotification*)notification{
    
}
- (void)audioRouteChangeNotification:(NSNotification*)notification{
    
}
- (void)interruptionNotification:(NSNotification*)notification {
    
}
- (void)applicationWillEnterForeground:(NSNotification*)notification{
    
}
-(void)audiobusConnectionsChanged:(NSNotification*)notification{
    
}
@end

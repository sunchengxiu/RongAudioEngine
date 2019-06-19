//
//  RongMixerBuffer.m
//  RomanticAudioEngine
//
//  Created by 孙承秀 on 2019/6/18.
//  Copyright © 2019 RongCloud. All rights reserved.
//

#import "RongMixerBuffer.h"
#import "TPCircularBuffer.h"
#import <pthread.h>
#import "RongAudioUtilities.h"
static const int kActionBufferSize                          = 2048;
static const NSTimeInterval kActionMainThreadPollDuration   = 0.2;
static const NSTimeInterval kSourceTimestampIdleThreshold   = 1.0;
static const UInt32 kScratchBufferBytesPerChannel           = 16384;
static const UInt32 kMaxMicrofadeDuration                   = 512;
static const UInt32 kConversionBufferLength                 = 16384;
static const UInt32 kSourceBufferFrames                     = 8192;

#define kMaxSources 30


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
    pthread_mutex_t             _graphMutex;
    source_t                    _table[kMaxSources];
    uint8_t                    *_scratchBuffer;
    float                      **_microfadeBuffer;
    int                          _configuredChannels;
    AUGraph                     _graph;
    AUNode                      _mixerNode;
    AudioUnit                   _mixerUnit;
    AudioStreamBasicDescription _mixerOutputFormat;
    TPCircularBuffer            _audioConverterBuffer;
    AudioConverterRef           _audioConverter;
    BOOL                        _graphReady;
}

@end
@interface RongMixerBufferPollProxy : NSObject{
    __weak RongMixerBuffer *_mixerBuffer;
}
- (id)initWithMixerBuffer:(RongMixerBuffer *)mixerBuffer;
@end
@implementation RongMixerBuffer
static OSStatus sourceInputCallback(void *inRefCon, AudioUnitRenderActionFlags *ioActionFlags, const AudioTimeStamp *inTimeStamp, UInt32 inBusNumber, UInt32 inNumberFrames, AudioBufferList *ioData) {
//    __unsafe_unretained AEMixerBuffer *THIS = (__bridge AEMixerBuffer*)inRefCon;
//
//    for ( int i=0; i<ioData->mNumberBuffers; i++ ) {
//        memset(ioData->mBuffers[i].mData, 0, ioData->mBuffers[i].mDataByteSize);
//    }
//
//    source_t *source = &THIS->_table[inBusNumber];
//
//    if ( source->source ) {
//        AEMixerBufferDequeueSingleSource(THIS, source->source, ioData, &inNumberFrames, NULL);
//    }
    
    return noErr;
}
-(id)initWithClientFormat:(AudioStreamBasicDescription)clientFormat{
    if(!(self = [super init])){
        return nil;
    }
    self.clientFormat = clientFormat;
    _sourceIdleThreshold = kSourceTimestampIdleThreshold;
    TPCircularBufferInit(&_mainThreadActionBuffer, kActionBufferSize);
    _mainThreadActionPollTimer = [NSTimer scheduledTimerWithTimeInterval:kActionMainThreadPollDuration target:[[RongMixerBufferPollProxy alloc] initWithMixerBuffer:self] selector:@selector(pollActionBuffer) userInfo:nil repeats:YES];
    pthread_mutex_init(&_graphMutex, NULL);
    return self;
}
-(void)setClientFormat:(AudioStreamBasicDescription)clientFormat{
    if(memcmp(&_clientFormat, &clientFormat, sizeof(AudioStreamBasicDescription)) == 0){
        return;
    }
    _clientFormat = clientFormat;
}
- (void)respondToChannelCountChange{
    int maxChannelCount = _clientFormat.mChannelsPerFrame;
    for(int i = 0 ; i < kMaxSources ; i ++ ){
        if(_table[i].source && _table[i].audioDescription.mSampleRate){
            maxChannelCount = MAX(maxChannelCount, _table[i].audioDescription.mChannelsPerFrame);
        }
    }
    if(_configuredChannels != maxChannelCount){
        if(_scratchBuffer){
            free(_scratchBuffer);
        }
        _scratchBuffer = (uint8_t *)malloc(kScratchBufferBytesPerChannel * maxChannelCount);
        if(_microfadeBuffer){
            for(int i = 0 ; i < _configuredChannels * 2 ; i ++){
                free(_microfadeBuffer[i]);
            }
            free(_microfadeBuffer);
        }
        _microfadeBuffer = (float **)malloc(sizeof(float *) * maxChannelCount * 2);
        for(int i = 0 ; i < maxChannelCount * 2; i ++ ){
            _microfadeBuffer[i] = (float *)malloc(sizeof(float *) * kMaxMicrofadeDuration);
            assert(_microfadeBuffer[i]);
        }
        for ( int i=0; i<kMaxSources; i++ ) {
            if ( _table[i].source && !_table[i].renderCallback && !_table[i].audioDescription.mSampleRate ) {
                int bufferSize = kSourceBufferFrames * (_clientFormat.mFormatFlags & kAudioFormatFlagIsNonInterleaved ? _clientFormat.mBytesPerFrame * _clientFormat.mChannelsPerFrame : _clientFormat.mBytesPerFrame);
                if ( _table[i].buffer.length != bufferSize ) {
                    TPCircularBufferCleanup(&_table[i].buffer);
                    TPCircularBufferInit(&_table[i].buffer, bufferSize);
                } else {
                    TPCircularBufferClear(&_table[i].buffer);
                }
            }
        }
        
        _configuredChannels = maxChannelCount;
    }
}
- (void)refreshMixingGraph {
    if(!_graph){
        [self createMixingGraph];
    }
    UInt32 busCount = 0;
    for(int i = 0 ; i < kMaxSources ; i ++){
        if(_table[i].source){
            busCount++;
        }
    }
    if(!RongCheckOSStatus(AudioUnitSetProperty(_mixerUnit, kAudioUnitProperty_ElementCount, kAudioUnitScope_Input, 0, &busCount, sizeof(busCount)), "AudioUnitSetProperty(kAudioUnitProperty_ElementCount)")){
        return;
    }
    AudioUnitParameterValue defaultOutputVolume = 1.0;
    if(!RongCheckOSStatus(AudioUnitSetParameter(_mixerUnit, kMultiChannelMixerParam_Volume, kAudioUnitScope_Output, 0, defaultOutputVolume, 0), "AudioUnitSetParameter(kMultiChannelMixerParam_Volume)")){
        return;
    }
    for(int busNum = 0 ; busNum < busCount; busNum ++){
        source_t *source = &_table[busNum];
        RongCheckOSStatus(AudioUnitSetProperty(_mixerUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, busNum, source->audioDescription.mSampleRate ? &source->audioDescription : &_clientFormat, sizeof(AudioStreamBasicDescription)),
                        "AudioUnitSetProperty(kAudioUnitProperty_StreamFormat)");
        AudioUnitParameterValue value = source->volume;
        RongCheckOSStatus(AudioUnitSetParameter(_mixerUnit, kMultiChannelMixerParam_Volume, kAudioUnitScope_Input, busNum, value, 0), "AudioUnitSetParameter(kMultiChannelMixerParam_Volume)");
        
        value = source->pan;
        RongCheckOSStatus(AudioUnitSetParameter(_mixerUnit, kMultiChannelMixerParam_Pan, kAudioUnitScope_Input, busNum, value, 0), "AudioUnitSetParameter(kMultiChannelMixerParam_Volume)");
        AURenderCallbackStruct rcbs;
        rcbs.inputProc = &sourceInputCallback;
        rcbs.inputProcRefCon = (__bridge void *)self;
        AUGraphSetNodeInputCallback(_graph, _mixerNode, busNum, &rcbs);
    }
    Boolean isInited = false;
    AUGraphIsInitialized(_graph, &isInited);
    if(!isInited){
        RongCheckOSStatus(AUGraphInitialize(_graph), "AUGraphInitialize");
        OSMemoryBarrier();
        _graphReady = YES;
    } else {
        for(int try = 3 ; try > 0 ; try --){
            if(RongCheckOSStatus(AUGraphUpdate(_graph, NULL), "AUGraphUpdate")){
                break;
            }
            [NSThread sleepForTimeInterval:0.01];
        }
    }
}
- (void)createMixingGraph {
    OSStatus result = NewAUGraph(&_graph);
    if ( !RongCheckOSStatus(result, "NewAUGraph") ) return;
    AudioComponentDescription mixer_desc = {
        .componentType = kAudioUnitType_Mixer,
        .componentSubType = kAudioUnitSubType_MultiChannelMixer,
        .componentManufacturer = kAudioUnitManufacturer_Apple,
        .componentFlags = 0,
        .componentFlagsMask = 0
    };
    result = AUGraphAddNode(_graph, &mixer_desc, &_mixerNode );
    if ( !RongCheckOSStatus(result, "AUGraphAddNode mixer") ) return;
    result = AUGraphOpen(_graph);
    if ( !RongCheckOSStatus(result, "AUGraphOpen") ) return;
    result = AUGraphNodeInfo(_graph, _mixerNode, NULL, &_mixerUnit);
    if ( !RongCheckOSStatus(result, "AUGraphNodeInfo") ) return;
    UInt32 maxFPS = 4096;
    RongCheckOSStatus(AudioUnitSetProperty(_mixerUnit, kAudioUnitProperty_MaximumFramesPerSlice, kAudioUnitScope_Global, 0, &maxFPS, sizeof(maxFPS)),
                    "AudioUnitSetProperty(kAudioUnitProperty_MaximumFramesPerSlice)");
    
    result = AudioUnitSetProperty(_mixerUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, 0, &_clientFormat, sizeof(_clientFormat));
    if ( result == kAudioUnitErr_FormatNotSupported ) {
        UInt32 size = sizeof(_mixerOutputFormat);
        RongCheckOSStatus(AudioUnitGetProperty(_mixerUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, 0, &_mixerOutputFormat, &size),
                        "AudioUnitGetProperty(kAudioUnitProperty_StreamFormat)");
        _mixerOutputFormat.mSampleRate = _clientFormat.mSampleRate;
        
        RongCheckOSStatus(AudioUnitSetProperty(_mixerUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, 0, &_mixerOutputFormat, sizeof(_mixerOutputFormat)),
                        "AudioUnitSetProperty(kAudioUnitProperty_StreamFormat");
        
        // Create the audio converter
        RongCheckOSStatus(AudioConverterNew(&_mixerOutputFormat, &_clientFormat, &_audioConverter), "AudioConverterNew");
        TPCircularBufferInit(&_audioConverterBuffer, kConversionBufferLength);
    } else {
        RongCheckOSStatus(result, "AudioUnitSetProperty(kAudioUnitProperty_StreamFormat)");
    }
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

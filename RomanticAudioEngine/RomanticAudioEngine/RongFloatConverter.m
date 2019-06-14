//
//  RongFloatConverter.m
//  RomanticAudioEngine
//
//  Created by 孙承秀 on 2019/6/14.
//  Copyright © 2019 RongCloud. All rights reserved.
//

#import "RongFloatConverter.h"
#import "RongAudioUtilities.h"
struct complexInputDataProc_t {
    AudioBufferList *sourceBuffer;
};
@interface RongFloatConverter(){
    AudioStreamBasicDescription _sourceAudioDescription;
    AudioStreamBasicDescription _floatAudioDescription;
    AudioConverterRef _toFloatConverter;
    AudioConverterRef _fromFloatConverter;
    AudioBufferList *_scratchFloatBufferList;
}


@end
@implementation RongFloatConverter
@synthesize sourceFormat = _sourceAudioDescription;
-(id)initWithSourceFormat:(AudioStreamBasicDescription)sourceFormat{
    if (self = [super init]) {
        self.sourceFormat = sourceFormat;
        return self;
    }
    return nil;
}
- (void)setSourceFormat:(AudioStreamBasicDescription)sourceFormat{
    if (!memcmp(&sourceFormat, &_sourceAudioDescription, sizeof(sourceFormat))) {
        return;
    }
    _sourceAudioDescription = sourceFormat;
    [self updateFormat];
}
- (void)updateFormat{
    _floatAudioDescription = (AudioStreamBasicDescription){
        .mFormatID = kAudioFormatLinearPCM,
        .mFormatFlags = kAudioFormatFlagIsFloat | kAudioFormatFlagIsPacked | kAudioFormatFlagIsNonInterleaved,
        .mBytesPerPacket = sizeof(float),
        .mSampleRate = _sourceAudioDescription.mSampleRate,
        .mFramesPerPacket = 1,
        .mChannelsPerFrame = _floatFormatChannelsPerFrame ? _floatFormatChannelsPerFrame : _sourceAudioDescription.mChannelsPerFrame,
        .mBitsPerChannel = 8 * sizeof(float),
        .mBytesPerFrame = sizeof(float),
    };
    if (_toFloatConverter) {
        AudioConverterDispose(_toFloatConverter);
        _toFloatConverter = NULL;
    }
    if (_fromFloatConverter) {
        AudioConverterDispose(_fromFloatConverter);
        _fromFloatConverter = NULL;
    }
    if (_scratchFloatBufferList) {
        free(_scratchFloatBufferList);
        _scratchFloatBufferList = NULL;
    }
    if (memcmp(&_sourceAudioDescription, &_floatAudioDescription, sizeof(AudioStreamBasicDescription)) != 0) {
        RongCheckOSStatus(AudioConverterNew(&_sourceAudioDescription, &_floatAudioDescription, &_toFloatConverter), "AudioConverterNew");
        RongCheckOSStatus(AudioConverterNew(&_floatAudioDescription, &_sourceAudioDescription, &_fromFloatConverter), "AudioConverterNew");
        _scratchFloatBufferList = (AudioBufferList *)malloc(sizeof(AudioBufferList) + (_floatAudioDescription.mChannelsPerFrame - 1) * sizeof(AudioBuffer));
        _scratchFloatBufferList->mNumberBuffers = _floatAudioDescription.mChannelsPerFrame;
        for ( int i=0; i<_scratchFloatBufferList->mNumberBuffers; i++ ) {
            _scratchFloatBufferList->mBuffers[i].mNumberChannels = 1;
        }
    }
}
-(void)setFloatFormatChannelsPerFrame:(int)floatFormatChannelsPerFrame{
    _floatFormatChannelsPerFrame = floatFormatChannelsPerFrame;
    [self updateFormat];
}
BOOL RongFloatConverterToFloat(__unsafe_unretained RongFloatConverter* THIS, AudioBufferList *sourceBuffer, float * const * targetBuffers, UInt32 frames){
    if (frames == 0) {
        return YES;
    }
    if (THIS->_toFloatConverter) {
        UInt32 priBufferSize = sourceBuffer->mBuffers[0].mDataByteSize;
        for (int i = 0; i < sourceBuffer->mNumberBuffers; i ++) {
            sourceBuffer->mBuffers[i].mDataByteSize = frames * THIS->_sourceAudioDescription.mBytesPerFrame;
        }
        for (int i = 0 ; i < THIS->_scratchFloatBufferList->mNumberBuffers; i ++) {
            THIS->_scratchFloatBufferList->mBuffers[i].mData = targetBuffers[i];
            THIS->_scratchFloatBufferList->mBuffers[i].mDataByteSize = frames * sizeof(float);
        }
        OSStatus result = AudioConverterFillComplexBuffer(THIS->_toFloatConverter, complexInputDataProc, &(struct complexInputDataProc_t){.sourceBuffer = sourceBuffer}, &frames, THIS->_scratchFloatBufferList, NULL);
        for (int i = 0 ; i < sourceBuffer->mNumberBuffers; i ++) {
            sourceBuffer->mBuffers[i].mDataByteSize = priBufferSize;
        }
        if ( !RongCheckOSStatus(result, "AudioConverterConvertComplexBuffer") ) {
            return NO;
        }
        
    } else {
        for (int i = 0 ; i < sourceBuffer->mNumberBuffers; i ++) {
            memcpy(targetBuffers[i], sourceBuffer->mBuffers[i].mData, frames * sizeof(float));
        }
    }
    return YES;
}
BOOL RongFloatConverterToFloatBufferList(__unsafe_unretained RongFloatConverter* THIS, AudioBufferList *sourceBuffer, AudioBufferList *targetBuffer, UInt32 frames) {
    assert(THIS->_floatAudioDescription.mChannelsPerFrame == targetBuffer->mNumberBuffers);
    float *targetBuffers[targetBuffer->mNumberBuffers];
    for (int i = 0; i < targetBuffer->mNumberBuffers; i ++) {
        targetBuffers[i] = targetBuffer->mBuffers[i].mData;
    }
    return RongFloatConverterToFloat(THIS, sourceBuffer, targetBuffers, frames);
}
BOOL RongFloatConverterFromFloat(__unsafe_unretained RongFloatConverter* THIS, float * const * sourceBuffers, AudioBufferList *targetBuffer, UInt32 frames) {
    if (frames == 0 ) {
        return YES;
    }
    if (THIS->_fromFloatConverter) {
        for (int i = 0; i < THIS->_scratchFloatBufferList->mNumberBuffers; i ++) {
            THIS->_scratchFloatBufferList->mBuffers[i].mData = sourceBuffers[i];
            THIS->_scratchFloatBufferList->mBuffers[i].mDataByteSize = frames * sizeof(float);
        }
        UInt32 priSize = targetBuffer->mBuffers[0].mDataByteSize;
        for (int i = 0 ; i < targetBuffer->mNumberBuffers; i ++ ) {
            targetBuffer->mBuffers[i].mDataByteSize = frames * THIS->_sourceAudioDescription.mBytesPerFrame;
        }
        OSStatus result = AudioConverterFillComplexBuffer(THIS->_fromFloatConverter, complexInputDataProc, &(struct complexInputDataProc_t){.sourceBuffer = THIS->_scratchFloatBufferList}, &frames, targetBuffer, NULL);
        for (int i = 0 ; i < targetBuffer->mNumberBuffers; i ++) {
            targetBuffer->mBuffers[i].mDataByteSize = priSize;
        }
        if ( !RongCheckOSStatus(result, "AudioConverterConvertComplexBuffer") ) {
            return NO;
        }
    } else {
        for (int i = 0 ; i < targetBuffer->mNumberBuffers; i ++) {
            memcpy(targetBuffer->mBuffers[i].mData, sourceBuffers[i], frames * sizeof(float));
        }
    }
    return YES;
}
BOOL RongFloatConverterFromFloatBufferList(__unsafe_unretained RongFloatConverter* THIS, AudioBufferList *sourceBuffer, AudioBufferList *targetBuffer, UInt32 frames) {
    assert(sourceBuffer->mNumberBuffers == THIS->_floatAudioDescription.mChannelsPerFrame);
    float *sourceBuffers[sourceBuffer->mNumberBuffers] ;
    for (int i = 0 ; i < sourceBuffer->mNumberBuffers; i ++) {
        sourceBuffers[i] = (float *)sourceBuffer->mBuffers[i].mData;
    }
    return RongFloatConverterFromFloat(THIS, sourceBuffers, targetBuffer, frames);
}
-(void)dealloc{
    if (_toFloatConverter) {
        AudioConverterDispose(_toFloatConverter);
    }
    if (_fromFloatConverter) {
        AudioConverterDispose(_fromFloatConverter);
    }
    if (_scratchFloatBufferList) {
        free(_scratchFloatBufferList);
    }
}
static OSStatus complexInputDataProc(AudioConverterRef             inAudioConverter,
                                     UInt32                        *ioNumberDataPackets,
                                     AudioBufferList               *ioData,
                                     AudioStreamPacketDescription  **outDataPacketDescription,
                                     void                          *inUserData) {
    struct complexInputDataProc_t *arg = (struct complexInputDataProc_t *)inUserData;
    memcpy(ioData, arg->sourceBuffer, sizeof(AudioBufferList) + (arg->sourceBuffer->mNumberBuffers - 1) * sizeof(AudioBuffer));
    arg->sourceBuffer = NULL;
    return noErr;
}
@end

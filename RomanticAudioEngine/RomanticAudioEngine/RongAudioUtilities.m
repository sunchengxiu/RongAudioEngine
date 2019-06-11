//
//  RongAudioUtilities.m
//  RomanticAudioEngine
//
//  Created by 孙承秀 on 2019/6/11.
//  Copyright © 2019 RongCloud. All rights reserved.
//

#import "RongAudioUtilities.h"
#import <mach/mach_time.h>

static double __hostTicksToSeconds = 0.0;
static double __secondsToHostTicks = 0.0;

AudioBufferList *RongAudioBufferListCreate(AudioStreamBasicDescription audioDescription , int frameCount){
    int numberOfBuffers = audioDescription.mFormatFlags & kAudioFormatFlagIsNonInterleaved ? audioDescription.mChannelsPerFrame : 1;
    int channelsPerBuffer = audioDescription.mFormatFlags & kAudioFormatFlagIsNonInterleaved ? 1 : audioDescription.mChannelsPerFrame;
    int bytesPerBuffer = frameCount * audioDescription.mBytesPerFrame;
    AudioBufferList *bufferList = malloc(sizeof(AudioBufferList) + (numberOfBuffers - 1) * sizeof(AudioBuffer));
    if (!bufferList) {
        return NULL;
    }
    bufferList->mNumberBuffers = numberOfBuffers;
    for (int i = 0 ; i < numberOfBuffers; i ++ ) {
        if (bytesPerBuffer > 0) {
            bufferList->mBuffers[i].mData = calloc(bytesPerBuffer, 1);
            if (!bufferList->mBuffers[i].mData) {
                for (int j = 0 ; j < i; j ++) {
                    free(bufferList->mBuffers[j].mData);
                }
                free(bufferList);
                return NULL;
            }
        } else {
            bufferList->mBuffers[i].mData = NULL;
        }
        bufferList->mBuffers[i].mDataByteSize = bytesPerBuffer;
        bufferList->mBuffers[i].mNumberChannels = channelsPerBuffer;
    }
    return bufferList;
}

AudioBufferList *RongAudioBufferListCopy(const AudioBufferList *originalBufferList){
    AudioBufferList *bufferList = malloc(sizeof(AudioBuffer) * (originalBufferList->mNumberBuffers -1) + sizeof(AudioBufferList));
    if (!bufferList) {
        return NULL;
    }
    for (int i = 0 ; i < originalBufferList->mNumberBuffers; i ++) {
        bufferList->mBuffers[i].mData = malloc(originalBufferList->mBuffers[i].mDataByteSize);
        if (!bufferList->mBuffers[i].mData) {
            for (int j = 0 ; j < i; j ++) {
                free(bufferList->mBuffers[j].mData);
            }
            free(bufferList);
            return NULL;
        }
        bufferList->mBuffers[i].mDataByteSize = originalBufferList->mBuffers[i].mDataByteSize;
        bufferList->mBuffers[i].mNumberChannels = originalBufferList->mBuffers[i].mNumberChannels;
        memcpy(bufferList->mBuffers[i].mData, originalBufferList->mBuffers[i].mData, originalBufferList->mBuffers[i].mDataByteSize);
    }
    return bufferList;
}

void RongAudioBufferListFree(AudioBufferList *bufferList){
    for (int i = 0 ; i < bufferList->mNumberBuffers; i ++) {
        if (bufferList->mBuffers[i].mData) {
            free(bufferList->mBuffers[i].mData);
        }
    }
    free(bufferList);
}
UInt32 RongAudioBufferListGetLength(const AudioBufferList *bufferList , AudioStreamBasicDescription audioDescription , int *numberOfChannels){
    int channelCount = audioDescription.mFormatFlags & kAudioFormatFlagIsNonInterleaved ? bufferList->mNumberBuffers : bufferList->mBuffers[0].mNumberChannels;
    if (numberOfChannels) {
        *numberOfChannels = channelCount;
    }
    return bufferList->mBuffers[0].mDataByteSize / (audioDescription.mBitsPerChannel * channelCount / 8);
}
void RongAudioBufferListSetLength(AudioBufferList *bufferList , AudioStreamBasicDescription audioDescription , UInt32 frameCount){
    for (int i = 0; i < bufferList->mNumberBuffers; i ++ ) {
        bufferList->mBuffers[i].mDataByteSize = frameCount * audioDescription.mBytesPerFrame;
    }
}
void RongAudioBufferListOffset(AudioBufferList *bufferList , AudioStreamBasicDescription audioDescription , UInt32 frames){
    for (int i = 0; i < bufferList->mNumberBuffers; i ++) {
        bufferList->mBuffers[i].mData = (char *)bufferList->mBuffers[i].mData + frames * audioDescription.mBytesPerFrame;
        bufferList->mBuffers[i].mDataByteSize -= frames * audioDescription.mBytesPerFrame;
    }
}
void RongAudioBufferListSilence(const AudioBufferList *bufferList , AudioStreamBasicDescription audioDescription , UInt32 offset , UInt32 length){
    for (int i = 0 ; i < bufferList->mNumberBuffers; i ++ ) {
        memset((char *)bufferList->mBuffers[i].mData + offset * audioDescription.mBytesPerFrame, 0, length ? length * audioDescription.mBytesPerFrame : bufferList->mBuffers[i].mDataByteSize - offset * audioDescription.mBytesPerFrame);
    }
}
AudioStreamBasicDescription const RongAudioStreamBasicDescriptionNonInterleavedFloatStereo = {
    .mFormatID          = kAudioFormatLinearPCM,
    .mFormatFlags       = kAudioFormatFlagIsFloat | kAudioFormatFlagIsPacked | kAudioFormatFlagIsNonInterleaved,
    .mChannelsPerFrame  = 2,
    .mBytesPerPacket    = sizeof(float),
    .mFramesPerPacket   = 1,
    .mBytesPerFrame     = sizeof(float),
    .mBitsPerChannel    = 8 * sizeof(float),
    .mSampleRate        = 44100.0,
};

AudioStreamBasicDescription const RongAudioStreamBasicDescriptionNonInterleaved16BitStereo = {
    .mFormatID          = kAudioFormatLinearPCM,
    .mFormatFlags       = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked | kAudioFormatFlagsNativeEndian | kAudioFormatFlagIsNonInterleaved,
    .mChannelsPerFrame  = 2,
    .mBytesPerPacket    = sizeof(SInt16),
    .mFramesPerPacket   = 1,
    .mBytesPerFrame     = sizeof(SInt16),
    .mBitsPerChannel    = 8 * sizeof(SInt16),
    .mSampleRate        = 44100.0,
};

AudioStreamBasicDescription const RongAudioStreamBasicDescriptionInterleaved16BitStereo = {
    .mFormatID          = kAudioFormatLinearPCM,
    .mFormatFlags       = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked | kAudioFormatFlagsNativeEndian,
    .mChannelsPerFrame  = 2,
    .mBytesPerPacket    = sizeof(SInt16)*2,
    .mFramesPerPacket   = 1,
    .mBytesPerFrame     = sizeof(SInt16)*2,
    .mBitsPerChannel    = 8 * sizeof(SInt16),
    .mSampleRate        = 44100.0,
};

AudioStreamBasicDescription AEAudioStreamBasicDescriptionMake(RongAudioStreamBasicDescriptionSampleType sampleType,
                                                              BOOL interleaved,
                                                              int numberOfChannels,
                                                              double sampleRate) {
    int sampleSize = sampleType == RongAudioStreamBasicDescriptionSampleTypeInt16 ? 2 : sampleType == RongAudioStreamBasicDescriptionSampleTypeInt32 ? 4 : sampleType == RongAudioStreamBasicDescriptionSampleTypeFloat32 ? 4 : 0;
    NSCAssert(sampleSize, @"Unrecognized sample type");
    
    return (AudioStreamBasicDescription) {
        .mFormatID = kAudioFormatLinearPCM,
        .mFormatFlags = (sampleType == RongAudioStreamBasicDescriptionSampleTypeFloat32
                         ? kAudioFormatFlagIsFloat : kAudioFormatFlagIsSignedInteger | kAudioFormatFlagsNativeEndian)
        | kAudioFormatFlagIsPacked
        | (interleaved ? 0 : kAudioFormatFlagIsNonInterleaved),
        .mChannelsPerFrame  = numberOfChannels,
        .mBytesPerPacket    = sampleSize * (interleaved ? numberOfChannels : 1),
        .mFramesPerPacket   = 1,
        .mBytesPerFrame     = sampleSize * (interleaved ? numberOfChannels : 1),
        .mBitsPerChannel    = 8 * sampleSize,
        .mSampleRate        = sampleRate,
    };
}
void RongAudioStreamBasicDescriptionSetChannelsPerFrame(AudioStreamBasicDescription *audioDescription , int numOfChnnels){
    if (!(audioDescription->mFormatFlags & kAudioFormatFlagIsNonInterleaved)) {
        audioDescription->mBytesPerFrame *= (float)numOfChnnels / (float)audioDescription->mChannelsPerFrame;
        audioDescription->mBytesPerPacket *= (float)numOfChnnels / (float)audioDescription->mChannelsPerFrame;
    }
    audioDescription->mChannelsPerFrame = numOfChnnels;
}

AudioComponentDescription RongAudioComponentDescriptionMake(OSType manufacturer, OSType type, OSType subtype) {
    AudioComponentDescription description;
    memset(&description, 0, sizeof(description));
    description.componentManufacturer = manufacturer;
    description.componentType = type;
    description.componentSubType = subtype;
    return description;
}
void RongTimeInit(void){
    mach_timebase_info_data_t timeInfo;
    mach_timebase_info(&timeInfo);
    __hostTicksToSeconds = ((double)timeInfo.numer / timeInfo.denom) * 1.0e-9;
    __secondsToHostTicks = 1.0 / __hostTicksToSeconds;
}

uint64_t RongCurrentTimeInHostTicks(void) {
    return mach_absolute_time();
}
double RongCurrentTimeInSeconds(void) {
    if ( !__hostTicksToSeconds ) RongTimeInit();
    return mach_absolute_time() * __hostTicksToSeconds;
}

uint64_t RongHostTicksFromSeconds(double seconds) {
    if ( !__secondsToHostTicks ) RongTimeInit();
    assert(seconds >= 0);
    return seconds * __secondsToHostTicks;
}

double RongSecondsFromHostTicks(uint64_t ticks) {
    if ( !__hostTicksToSeconds ) RongTimeInit();
    return ticks * __hostTicksToSeconds;
}

BOOL RongRateLimit(void) {
    static double lastMessage = 0;
    static int messageCount=0;
    double now = RongCurrentTimeInSeconds();
    if ( now-lastMessage > 1 ) {
        messageCount = 0;
        lastMessage = now;
    }
    if ( ++messageCount >= 10 ) {
        if ( messageCount == 10 ) {
            NSLog(@"TAAE: Suppressing some messages");
        }
        return NO;
    }
    return YES;
}
@implementation RongAudioUtilities

@end

//
//  RongAudioUtilities.h
//  RomanticAudioEngine
//
//  Created by 孙承秀 on 2019/6/11.
//  Copyright © 2019 RongCloud. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>
NS_ASSUME_NONNULL_BEGIN
typedef enum {
    RongAudioStreamBasicDescriptionSampleTypeFloat32, //!< 32-bit floating point
    RongAudioStreamBasicDescriptionSampleTypeInt16,   //!< Signed 16-bit integer
    RongAudioStreamBasicDescriptionSampleTypeInt32    //!< Signed 32-bit integer
} RongAudioStreamBasicDescriptionSampleType;

AudioBufferList *RongAudioBufferListCreate(AudioStreamBasicDescription audioDescription , int frameCount);
#define AEAllocateAndInitAudioBufferList AEAudioBufferListCreate // Legacy alias


#define RongAudioBufferListCreateOnStack(name, audioFormat) \
int name ## _numberBuffers = audioFormat.mFormatFlags & kAudioFormatFlagIsNonInterleaved \
? audioFormat.mChannelsPerFrame : 1; \
char name ## _bytes[sizeof(AudioBufferList)+(sizeof(AudioBuffer)*(name ## _numberBuffers-1))]; \
memset(&name ## _bytes, 0, sizeof(name ## _bytes)); \
AudioBufferList * name = (AudioBufferList*)name ## _bytes; \
name->mNumberBuffers = name ## _numberBuffers;

#define RongAudioBufferListCopyOnStack(name, sourceBufferList, offsetBytes) \
char name ## _bytes[sizeof(AudioBufferList)+(sizeof(AudioBuffer)*(sourceBufferList->mNumberBuffers-1))]; \
memcpy(name ## _bytes, sourceBufferList, sizeof(name ## _bytes)); \
AudioBufferList * name = (AudioBufferList*)name ## _bytes; \
for ( int i=0; i<name->mNumberBuffers; i++ ) { \
name->mBuffers[i].mData = (char*)name->mBuffers[i].mData + offsetBytes; \
name->mBuffers[i].mDataByteSize -= offsetBytes; \
}


AudioBufferList *RongAudioBufferListCopy(const AudioBufferList *originalBufferList);
#define RongCopyAudioBufferList RongAudioBufferListCopy // Legacy alias

void RongAudioBufferListFree(AudioBufferList *bufferList);
#define RongFreeAudioBufferList RongAudioBufferListFree // Legacy alias

UInt32 RongAudioBufferListGetLength(const AudioBufferList *bufferList , AudioStreamBasicDescription audioDescription , int *numberOfChannels);
#define RongGetNumberOfFramesInAudioBufferList RongAudioBufferListGetLength // Legacy alias

void RongAudioBufferListSetLength(AudioBufferList *bufferList , AudioStreamBasicDescription audioDescription , UInt32 frameCount);

void RongAudioBufferListOffset(AudioBufferList *bufferList , AudioStreamBasicDescription audioDescription , UInt32 frames);

void RongAudioBufferListSilence(const AudioBufferList *bufferList , AudioStreamBasicDescription audioDescription , UInt32 offset , UInt32 length);

static inline size_t RongAudioBufferListGetStructSize(const AudioBufferList *bufferList) {
    return sizeof(AudioBufferList) + (bufferList->mNumberBuffers-1) * sizeof(AudioBuffer);
}

extern AudioStreamBasicDescription const RongAudioStreamBasicDescriptionNonInterleavedFloatStereo ;

extern AudioStreamBasicDescription const RongAudioStreamBasicDescriptionNonInterleaved16BitStereo;

extern AudioStreamBasicDescription const RongAudioStreamBasicDescriptionInterleaved16BitStereo;


AudioStreamBasicDescription AEAudioStreamBasicDescriptionMake(RongAudioStreamBasicDescriptionSampleType sampleType,
                                                              BOOL interleaved,
                                                              int numberOfChannels,
                                                              double sampleRate);

void RongAudioStreamBasicDescriptionSetChannelsPerFrame(AudioStreamBasicDescription *audioDescription , int numOfChnnels);
    
AudioComponentDescription RongAudioComponentDescriptionMake(OSType manufacturer, OSType type, OSType subtype) ;

void RongTimeInit(void);

uint64_t RongCurrentTimeInHostTicks(void);

double RongCurrentTimeInSeconds(void);

uint64_t RongHostTicksFromSeconds(double seconds);

double RongSecondsFromHostTicks(uint64_t ticks) ;

BOOL RongRateLimit(void);

#define RongCheckOSStatus(result,operation) (_RongCheckOSStatus((result),(operation),strrchr(__FILE__, '/')+1,__LINE__))
static inline BOOL _RongCheckOSStatus(OSStatus result, const char *operation, const char* file, int line) {
    if ( result != noErr ) {
        if ( RongRateLimit() ) {
            int fourCC = CFSwapInt32HostToBig(result);
            if ( isascii(((char*)&fourCC)[0]) && isascii(((char*)&fourCC)[1]) && isascii(((char*)&fourCC)[2]) ) {
                NSLog(@"%s:%d: %s: '%4.4s' (%d)", file, line, operation, (char*)&fourCC, (int)result);
            } else {
                NSLog(@"%s:%d: %s: %d", file, line, operation, (int)result);
            }
        }
        return NO;
    }
    return YES;
}

@interface RongAudioUtilities : NSObject

@end

NS_ASSUME_NONNULL_END

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

@interface RongAudioUtilities : NSObject

@end

NS_ASSUME_NONNULL_END

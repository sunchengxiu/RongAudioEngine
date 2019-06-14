//
//  RongFloatConverter.h
//  RomanticAudioEngine
//
//  Created by 孙承秀 on 2019/6/14.
//  Copyright © 2019 RongCloud. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>
NS_ASSUME_NONNULL_BEGIN

@interface RongFloatConverter : NSObject
- (id)initWithSourceFormat:(AudioStreamBasicDescription)sourceFormat;
/*!
 * The source audio format set at initialization
 */
@property (nonatomic, assign) AudioStreamBasicDescription sourceFormat;
/*!
 * The number of channels for the floating-point format
 */
@property (nonatomic, assign) int floatFormatChannelsPerFrame;
BOOL RongFloatConverterToFloat(__unsafe_unretained RongFloatConverter* THIS, AudioBufferList *sourceBuffer, float * _Nullable const * _Nullable targetBuffers, UInt32 frames);
BOOL RongFloatConverterToFloatBufferList(__unsafe_unretained RongFloatConverter* THIS, AudioBufferList *sourceBuffer, AudioBufferList *targetBuffer, UInt32 frames);
BOOL RongFloatConverterFromFloat(__unsafe_unretained RongFloatConverter* THIS, float * _Nullable const * _Nullable sourceBuffers, AudioBufferList *targetBuffer, UInt32 frames) ;
BOOL RongFloatConverterFromFloatBufferList(__unsafe_unretained RongFloatConverter* THIS, AudioBufferList *sourceBuffer, AudioBufferList *targetBuffer, UInt32 frames) ;
@end

NS_ASSUME_NONNULL_END

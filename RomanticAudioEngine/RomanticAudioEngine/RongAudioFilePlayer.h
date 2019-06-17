//
//  RongAudioFilePlayer.h
//  RomanticAudioEngine
//
//  Created by 孙承秀 on 2019/6/13.
//  Copyright © 2019 RongCloud. All rights reserved.
//

#import "RongAudioUnitChannel.h"

NS_ASSUME_NONNULL_BEGIN

@interface RongAudioFilePlayer : RongAudioUnitChannel
/*!
 * Create a new player instance
 *
 * @param url               URL to the file to load
 * @param error             If not NULL, the error on output
 * @return The audio player, ready to be @link AEAudioController::addChannels: added @endlink to the audio controller.
 */
+ (instancetype)audioFilePlayerWithURL:(NSURL *)url error:(NSError **)error;

/*!
 * Default initialiser
 *
 * @param url               URL to the file to load
 * @param error             If not NULL, the error on output
 */
- (instancetype)initWithURL:(NSURL *)url error:(NSError **)error;

/*!
 * Schedule playback for a particular time
 *
 *  This causes the player to emit silence up until the given timestamp
 *  is reached. Use this method to synchronize playback with other audio
 *  generators.
 *
 *  Note: When you call this method, the property channelIsPlaying will be
 *  set to YES, to enable playback when the start time is reached.
 *
 * @param time The time, in host ticks, at which to begin playback
 */
- (void)playAtTime:(uint64_t)time;
@end

NS_ASSUME_NONNULL_END

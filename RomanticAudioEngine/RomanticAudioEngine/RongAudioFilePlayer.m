//
//  RongAudioFilePlayer.m
//  RomanticAudioEngine
//
//  Created by 孙承秀 on 2019/6/13.
//  Copyright © 2019 RongCloud. All rights reserved.
//

#import "RongAudioFilePlayer.h"
#import "RongAudioUtilities.h"
#import "RongAudioEngine+Private.h"
#import <libkern/OSAtomic.h>
@interface RongAudioFilePlayer()
{
    AudioFileID _audioFile;
    AudioStreamBasicDescription _fileDescription;
    UInt32 _lengthInFrames;
    NSTimeInterval _regionDuration;
    NSTimeInterval _regionStartTime;
    RongAudioRenderCallback _superRenderCallback;
    volatile int32_t _playhead;
    AudioStreamBasicDescription _outputDescription;
    BOOL _running;
    uint64_t _startTime;
    volatile int32_t _playbackStoppedCallbackScheduled;
}
@property (nonatomic, weak) RongAudioEngine * audioEngine;

@end
@implementation RongAudioFilePlayer
-(instancetype)initWithURL:(NSURL *)url error:(NSError * _Nullable __autoreleasing *)error{
    if (!(self = [super initWithComponentDescription:RongAudioComponentDescriptionMake(kAudioUnitManufacturer_Apple, kAudioUnitType_Generator, kAudioUnitSubType_AudioFilePlayer)])) {
        return nil;
    }
    if (!([self loadAudioFileWithURL:url error:error])) {
        return nil;
    }
    _superRenderCallback = [super renderCallback];
    return self;
}
-(void)setupWithAudioEngine:(RongAudioEngine *)audioEngine{
    [super setupWithAudioEngine:audioEngine];
    Float64 priSampleRate = _outputDescription.mSampleRate;
    _outputDescription = audioEngine.audioDescription;
    double sampleRateFactor = _outputDescription.mSampleRate / (priSampleRate ? priSampleRate : _fileDescription.mSampleRate);
    _playhead = _playhead * sampleRateFactor;
    _audioEngine = audioEngine;
    UInt32 size = sizeof(_audioFile);
    OSStatus result;
    result = AudioUnitSetProperty(self.audioUnit, kAudioUnitProperty_ScheduledFileIDs, kAudioUnitScope_Global, 0, &_audioFile,size);
    RongCheckOSStatus(result, "AudioUnitSetProperty(kAudioUnitProperty_ScheduledFileIDs)");
    if (self.channelIsPlaying) {
        double outputToSourceSampleRateScale = _fileDescription.mSampleRate / _outputDescription.mSampleRate;
        [self schedulePlayRegionFromPosition:_playhead * outputToSourceSampleRateScale];
        _running = YES;
    }
}
- (void)schedulePlayRegionFromPosition:(UInt32)position{
    AudioUnit audioUnit = self.audioUnit;
    if (!audioUnit || !_audioFile) {
        return;
    }
    double sourceToOutputSampleScale = _outputDescription.mSampleRate / _fileDescription.mSampleRate;
    _playhead = position * sourceToOutputSampleScale;
    Float64 mainRegionStartTime = 0;
    RongCheckOSStatus(AudioUnitReset(audioUnit, kAudioUnitScope_Global, 0), "AudioUnitReset");
    if (self.regionStartTime > self.duration) {
        self.regionStartTime = self.duration;
    }
    if (self.regionStartTime + self.regionDuration > self.duration) {
        _regionDuration = self.duration - self.regionStartTime;
    }
    if (position > self.regionStartTime) {
        UInt32 framesToPlay = self.regionDuration * _fileDescription.mSampleRate - (position - self.regionStartTime * _fileDescription.mSampleRate);
        ScheduledAudioFileRegion region = {
            .mTimeStamp = {.mFlags = kAudioTimeStampSampleTimeValid, .mSampleTime = 0 },
            .mAudioFile = _audioFile ,
            .mStartFrame = position,
            .mFramesToPlay = framesToPlay
        };
        OSStatus result = AudioUnitSetProperty(audioUnit, kAudioUnitProperty_ScheduledFileRegion, kAudioUnitScope_Global, 0, &region, sizeof(region));
        mainRegionStartTime = framesToPlay * sourceToOutputSampleScale;
    }
    ScheduledAudioFileRegion region = {
        .mTimeStamp = {.mFlags = kAudioTimeStampSampleTimeValid, .mSampleTime = mainRegionStartTime },
        .mAudioFile = _audioFile ,
        .mStartFrame = _regionStartTime * _fileDescription.mSampleRate,
        .mFramesToPlay = _regionDuration * _fileDescription.mSampleRate,
    };
    OSStatus result = AudioUnitSetProperty(audioUnit, kAudioUnitProperty_ScheduledFileRegion, kAudioUnitScope_Global, 0, &region, sizeof(region));
    UInt32 primeFrames = 0;
    
    result = AudioUnitSetProperty(audioUnit, kAudioUnitProperty_ScheduledFilePrime, kAudioUnitScope_Global, 0, &primeFrames, sizeof(primeFrames));
    
    // Set the start time
    AudioTimeStamp startTime = { .mFlags = kAudioTimeStampSampleTimeValid, .mSampleTime = -1 /* ASAP */ };
    result = AudioUnitSetProperty(audioUnit, kAudioUnitProperty_ScheduleStartTimeStamp, kAudioUnitScope_Global, 0, &startTime, sizeof(startTime));
    RongCheckOSStatus(result, "AudioUnitSetProperty(kAudioUnitProperty_ScheduleStartTimeStamp)");
}
- (void)teardown {
    if ( OSAtomicCompareAndSwap32(YES, NO, &_playbackStoppedCallbackScheduled) ) {
        // A playback stop callback was scheduled - we need to flush events from the message queue to clear it out
        [self.audioEngine.messageQueue processMainThreadMessages];
    }
    self.audioEngine = nil;
    [super teardown];
}
-(void)playAtTime:(uint64_t)time{
    _startTime = time;
    if (!self.channelIsPlaying) {
        self.channelIsPlaying = YES;
    }
}
-(NSTimeInterval)regionDuration{
    return _regionDuration;
}
-(NSTimeInterval)regionStartTime{
    return _regionStartTime;
}
- (NSTimeInterval)duration {
    return (double)_lengthInFrames / (double)_fileDescription.mSampleRate;
}
-(void)dealloc{
    if (_audioFile) {
        AudioFileClose(_audioFile);
    }
}
- (BOOL)loadAudioFileWithURL:(NSURL*)url error:(NSError**)error {
    OSStatus result ;
    result = AudioFileOpenURL((__bridge CFURLRef)url,kAudioFileReadPermission, 0, &_audioFile);
    if ( !RongCheckOSStatus(result, "AudioFileOpenURL") ) {
        *error = [NSError errorWithDomain:NSOSStatusErrorDomain code:result
                                 userInfo:@{NSLocalizedDescriptionKey: NSLocalizedString(@"Couldn't open the audio file", @"")}];
        return NO;
    }
    UInt32 size = sizeof(_fileDescription);
    result = AudioFileGetProperty(_audioFile, kAudioFilePropertyDataFormat, &size, &_fileDescription);
    if ( !RongCheckOSStatus(result, "AudioFileGetProperty(kAudioFilePropertyDataFormat)") ) {
        *error = [NSError errorWithDomain:NSOSStatusErrorDomain code:result
                                 userInfo:@{NSLocalizedDescriptionKey: NSLocalizedString(@"Couldn't read the audio file", @"")}];
        AudioFileClose(_audioFile);
        _audioFile = NULL;
        return NO;
    }
    AudioFilePacketTableInfo packetTableInfo;
    size = sizeof(packetTableInfo);
    result = AudioFileGetProperty(_audioFile, kAudioFileStreamProperty_PacketTableInfo, &size, &packetTableInfo);
    if (result != noErr) {
        result = 0;
    }
    UInt64 length;
    if (size > 0) {
        length = packetTableInfo.mNumberValidFrames;
    } else {
        UInt64 packetCount ;
        size = sizeof(packetCount);
        result = AudioFileGetProperty(_audioFile, kAudioFilePropertyAudioDataPacketCount, &size, &packetCount);
        if ( !RongCheckOSStatus(result, "AudioFileGetProperty(kAudioFilePropertyAudioDataPacketCount)") ) {
            *error = [NSError errorWithDomain:NSOSStatusErrorDomain code:result
                                     userInfo:@{NSLocalizedDescriptionKey: NSLocalizedString(@"Couldn't read the audio file", @"")}];
            AudioFileClose(_audioFile);
            _audioFile = NULL;
            return NO;
        }
        length = packetCount * _fileDescription.mFramesPerPacket;
    }
    if ( length == 0 ) {
        *error = [NSError errorWithDomain:NSOSStatusErrorDomain code:-50
                                 userInfo:@{NSLocalizedDescriptionKey: NSLocalizedString(@"This audio file is empty", @"")}];
        AudioFileClose(_audioFile);
        _audioFile = NULL;
        return NO;
    }
    _lengthInFrames = (UInt32)length;
    _regionStartTime = 0;
    _regionDuration = length / _fileDescription.mSampleRate;
    return YES;
}
@end

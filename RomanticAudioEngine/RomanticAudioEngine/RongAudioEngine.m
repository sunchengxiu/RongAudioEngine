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
static const int kMessageBufferLength                  = 8192;
@interface RongAudioEngineMessageQueue : RongAudioMessageQueue

@property(nonatomic , strong)RongAudioEngine *audioEngine;

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
}
@property(nonatomic , assign)BOOL  alloclAudioEngine;
@property(nonatomic , copy)NSString *audioSessionCategory;
@property(nonatomic , assign)BOOL allowMixingWithOtherApps;
@property(nonatomic , assign)BOOL allowBluetoothInput;
@property(nonatomic , assign)BOOL allowVoiceProcessing;
@property(nonatomic , assign)AudioStreamBasicDescription audioDescription;
@property(nonatomic , assign)BOOL inputEnabled;
@property(nonatomic , assign)BOOL outputEnabled;
@property(nonatomic , assign)BOOL useHardwareSampleRate;
@property (nonatomic, strong) NSTimer *housekeepingTimer;
@property(nonatomic , strong)RongAudioEngineMessageQueue *messageQueue;
@property (nonatomic, assign) NSTimeInterval currentBufferDuration;
@property (nonatomic, assign) BOOL playingThroughDeviceSpeaker;
@property (nonatomic, assign) BOOL recordingThroughDeviceMicrophone;

@end

@implementation RongAudioEngine
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
    return nil;
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
            NSLog(@"user hardware sample rate : %@",hardwareSampleRate);
        } else {
             NSLog(@"user client sample rate : %@",sampleRate);
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

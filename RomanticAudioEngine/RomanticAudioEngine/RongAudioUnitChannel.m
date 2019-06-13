//
//  RongAudioUnitChannel.m
//  RomanticAudioEngine
//
//  Created by 孙承秀 on 2019/6/13.
//  Copyright © 2019 RongCloud. All rights reserved.
//

#import "RongAudioUnitChannel.h"
@interface RongAudioUnitChannel(){
    AudioComponentDescription _componentDescription;
    AudioUnit _audioUnit;
}
@property (nonatomic, copy) void (^preInitializeBlock)(AudioUnit audioUnit);
@property (nonatomic, strong) NSMutableDictionary * savedParameters;

@end
@implementation RongAudioUnitChannel
-(id)initWithComponentDescription:(AudioComponentDescription)audioComponentDescription{
    return [self initWithComponentDescription:audioComponentDescription preInitializeBlock:nil];
}
-(id)initWithComponentDescription:(AudioComponentDescription)audioComponentDescription preInitializeBlock:(void (^)(AudioUnit _Nonnull))preInitializeBlock{
    if (self = [super init]) {
        _componentDescription = audioComponentDescription;
        self.preInitializeBlock = preInitializeBlock;
        self.volume = 1.0;
        self.pan = 0.0;
        self.channelIsMuted = NO;
        self.channelIsPlaying = YES;
        return self;
    }
    return nil;
}
-(void)setupWithAudioEngine:(RongAudioEngine *)audioEngine{
    
}
AudioUnit RongAudioUnitChannelGetAudioUnit(__unsafe_unretained RongAudioUnitChannel * channel){
    return channel->_audioUnit;
}

@end

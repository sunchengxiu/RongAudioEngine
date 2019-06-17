//
//  RongAudioFilePlayer.m
//  RomanticAudioEngine
//
//  Created by 孙承秀 on 2019/6/13.
//  Copyright © 2019 RongCloud. All rights reserved.
//

#import "RongAudioFilePlayer.h"
#import "RongAudioUtilities.h"
@implementation RongAudioFilePlayer
-(instancetype)initWithURL:(NSURL *)url error:(NSError * _Nullable __autoreleasing *)error{
    if (!(self = [super initWithComponentDescription:RongAudioComponentDescriptionMake(kAudioUnitManufacturer_Apple, kAudioUnitType_Generator, kAudioUnitSubType_AudioFilePlayer)])) {
        return nil;
    }
    return self;
}
@end

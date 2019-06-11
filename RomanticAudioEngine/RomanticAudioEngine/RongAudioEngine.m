//
//  RongAudioEngine.m
//  RomanticAudioEngine
//
//  Created by 孙承秀 on 2019/6/11.
//  Copyright © 2019 RongCloud. All rights reserved.
//

#import "RongAudioEngine.h"

@implementation RongAudioEngine
-(id)initWithAudioDescription:(AudioStreamBasicDescription)audioDescription{
    return [self initWithAudioDescription:audioDescription options:RongAudioEngineUnitOptionDefaults];
}
-(id)initWithAudioDescription:(AudioStreamBasicDescription)audioDescription inputEnabled:(BOOL)enableInput{
    return [self initWithAudioDescription:audioDescription options:RongAudioEngineUnitOptionDefaults | (enableInput ? RongAudioEngineUnitOptionEnableInput : 0)];
}
-(id)initWithAudioDescription:(AudioStreamBasicDescription)audioDescription options:(RongAudioEngineUnitOptions)options{
    return nil;
}
@end

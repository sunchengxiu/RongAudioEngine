//
//  RongAudioEngine+Private.h
//  RomanticAudioEngine
//
//  Created by 孙承秀 on 2019/6/17.
//  Copyright © 2019 RongCloud. All rights reserved.
//

#import <RomanticAudioEngine/RomanticAudioEngine.h>

NS_ASSUME_NONNULL_BEGIN

@interface RongAudioEngine (Private)
@property (nonatomic, readonly) AUGraph audioGraph;
@property (nonatomic, readonly) AudioStreamBasicDescription audioDescription;
@end

NS_ASSUME_NONNULL_END

//
//  RongAudioEngine+Private.h
//  RomanticAudioEngine
//
//  Created by 孙承秀 on 2019/6/17.
//  Copyright © 2019 RongCloud. All rights reserved.
//

#import <RomanticAudioEngine/RomanticAudioEngine.h>
#import "RongAudioMessageQueue.h"

NS_ASSUME_NONNULL_BEGIN

@interface RongAudioEngine (Private)
@property (nonatomic, readonly) AUGraph audioGraph;
@property (nonatomic, readonly) AudioStreamBasicDescription audioDescription;
@property (nonatomic, readonly, strong)RongAudioMessageQueue *messageQueue;

void RongAudioEngineSendAsynchronousMessageToMainThread(__unsafe_unretained RongAudioEngine *THIS,
                                                            RongAudioMessageQueueMessageHandler           handler,
                                                            void                                  *userInfo,
                                                            int                                    userInfoLength);
@end

NS_ASSUME_NONNULL_END

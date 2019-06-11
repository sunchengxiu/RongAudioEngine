//
//  RongAudioMessageQueue.h
//  RomanticAudioEngine
//
//  Created by 孙承秀 on 2019/6/11.
//  Copyright © 2019 RongCloud. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN
typedef void(^RongAudioMessageQueueMessageHandler)(void *userInfo , int userInfoLength);
@interface RongAudioMessageQueue : NSObject
@property (nonatomic, assign) NSTimeInterval autoProcessTimeout;
- (instancetype)init;
- (instancetype)initWithMessageBufferLength:(int32_t)length;

- (void)startPolling;

- (void)stopPolling;

-(void)processMainThreadMessages;
@end

NS_ASSUME_NONNULL_END

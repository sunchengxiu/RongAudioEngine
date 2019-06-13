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
- (void)beginMessageExchangeBlock ;
- (void)endMessageExchangeBlock;
-(void)processMainThreadMessages;
- (BOOL)RongPerformSynchronousMessageExchangeWithBlock:(void (^)(void))block ;
- (void)RongPerformAsynchronousMessageExchangeWithBlock:(void (^)(void))block responseBlock:(void (^)(void))responseBlock ;
@end

NS_ASSUME_NONNULL_END

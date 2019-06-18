//
//  RongAudioMessageQueue.h
//  RomanticAudioEngine
//
//  Created by 孙承秀 on 2019/6/11.
//  Copyright © 2019 RongCloud. All rights reserved.
//

#import <Foundation/Foundation.h>
typedef void(*RongAudioMessageQueueMessageHandler)(void * _Nullable userInfo , int userInfoLength);
NS_ASSUME_NONNULL_BEGIN

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
void RongMessageQueueSendMessageToMainThread(__unsafe_unretained RongAudioMessageQueue *THIS,
                                             RongAudioMessageQueueMessageHandler        handler,
                                             void                               *userInfo,
                                             int                                 userInfoLength);
@end

NS_ASSUME_NONNULL_END

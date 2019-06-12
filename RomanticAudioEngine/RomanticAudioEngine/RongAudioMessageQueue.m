//
//  RongAudioMessageQueue.m
//  RomanticAudioEngine
//
//  Created by 孙承秀 on 2019/6/11.
//  Copyright © 2019 RongCloud. All rights reserved.
//

#import "RongAudioMessageQueue.h"
#import "TPCircularBuffer.h"
#import <pthread.h>
#import "RongAudioUtilities.h"
typedef struct {
    void *block;
    void *responseBlock;
    RongAudioMessageQueueMessageHandler handler;
    int userInfoLength;
    pthread_t sourceThread;
    BOOL  replyServced;
}message_t;
static const NSTimeInterval kIdleMessagingPollDuration   = 0.1;
static const NSTimeInterval kActiveMessagingPollDuration = 0.01;
static const int kDefaultMessageBufferLength             = 8192;
static const NSTimeInterval kSynchronousTimeoutInterval  = 1.0;
@interface RongAudioMessagePollThread : NSThread
- (id)initWithMessageQueue:(RongAudioMessageQueue *)queue;
@property(nonatomic , assign)NSTimeInterval pollInterval;
@end

@interface RongAudioMessageQueue ()
@property (nonatomic, readonly) uint64_t lastProcessTime;

@end
@implementation RongAudioMessageQueue{
    TPCircularBuffer _realTimeThreadMessageBuffer;
    TPCircularBuffer _mainThreadMessageBuffer;
    pthread_mutex_t _mutex;
    BOOL _holdRealtimeProcessing;
    int                 _pendingResponses;
    RongAudioMessagePollThread *_pollThread;
}
-(instancetype)init{
    return [self initWithMessageBufferLength:kDefaultMessageBufferLength];
}
-(instancetype)initWithMessageBufferLength:(int32_t)length{
    if (self = [super init]) {
        TPCircularBufferInit(&_realTimeThreadMessageBuffer, length);
        TPCircularBufferInit(&_mainThreadMessageBuffer, length);
        pthread_mutex_init(&_mutex, NULL);
        return self;
    }
    return nil;
}
-(void)startPolling{
    
}
-(void)stopPolling{
    
}
- (BOOL)RongPerformSynchronousMessageExchangeWithBlock:(void (^)(void))block {
    __block BOOL fininsh = NO;
    void (^responseBlock)(void) = ^{
        fininsh = YES;
    };
    [self RongPerformAsynchronousMessageExchangeWithBlock:block responseBlock:responseBlock sourceThread:pthread_self()];
    
    uint64_t giveUpTime = RongCurrentTimeInHostTicks() + RongHostTicksFromSeconds(kSynchronousTimeoutInterval);
    while (!fininsh && giveUpTime > RongCurrentTimeInHostTicks()) {
        [self RongProcessMainThreadMessagesMatchingResponseBlock:responseBlock];
        if (fininsh) {
            break;
        }
        [NSThread sleepForTimeInterval:kActiveMessagingPollDuration];
    }
    if (!fininsh) {
        
    }
    return fininsh;

}

- (void)RongPerformAsynchronousMessageExchangeWithBlock:(void (^)(void))block responseBlock:(void (^)(void))responseBlock {
    [self RongPerformAsynchronousMessageExchangeWithBlock:block responseBlock:responseBlock sourceThread:NULL];
}
- (void)RongPerformAsynchronousMessageExchangeWithBlock:(void (^)(void))block
                                      responseBlock:(void (^)(void))responseBlock
                                           sourceThread:(pthread_t)sourceThread{
    int32_t availableBytes;
    message_t *message = TPCircularBufferHead(&_realTimeThreadMessageBuffer, &availableBytes);
    if (availableBytes < sizeof(message_t)) {
        return;
    }
    if (responseBlock) {
        _pendingResponses ++;
        if (_pollThread.pollInterval == kIdleMessagingPollDuration) {
            _pollThread.pollInterval = kActiveMessagingPollDuration;
        }
    }
    memset((void*)message, 0, sizeof(message_t));
    message->block = block ? (__bridge_retained void *)[block copy] : NULL;
    message->responseBlock = responseBlock ? (__bridge_retained void *)[responseBlock copy] : NULL;
    message->sourceThread = sourceThread;
    TPCircularBufferProduce(&_realTimeThreadMessageBuffer, sizeof(message_t));
    
}
void RongMessageQueueProcessMessagesOnRealtimeThread(__unsafe_unretained RongAudioMessageQueue *THIS){
    if (pthread_mutex_trylock(&THIS->_mutex) != 0) {
        return;
    }
    if (THIS->_holdRealtimeProcessing) {
        pthread_mutex_unlock(&THIS->_mutex);
        return;
    }
    THIS->_lastProcessTime = RongCurrentTimeInHostTicks();
    
    int32_t availableBytes;
    
    message_t *buffer = TPCircularBufferTail(&THIS->_realTimeThreadMessageBuffer, &availableBytes);
    message_t *end = (message_t *)((char *)buffer + availableBytes);
    message_t message;
    while (buffer < end) {
        assert(buffer->userInfoLength == 0);
        memcpy((void*)&message, (void*)buffer, sizeof(message));
        TPCircularBufferConsume(&THIS->_realTimeThreadMessageBuffer, sizeof(message_t));
        if (message.block) {
            ((__bridge void (^)(void))message.block)();
        }
        
        int32_t availableReplyBytes;
        message_t *reply = TPCircularBufferHead(&THIS->_mainThreadMessageBuffer, &availableReplyBytes);
        if (availableReplyBytes < sizeof(message_t)) {
            pthread_mutex_unlock(&THIS->_mutex);
            return;
        }
        memcpy((void*)reply, (void*)&message, sizeof(message_t));
        TPCircularBufferProduce(&THIS->_mainThreadMessageBuffer, sizeof(message_t));
        buffer ++;
    }
    pthread_mutex_unlock(&THIS->_mutex);
    
}
- (void)RongProcessMainThreadMessagesMatchingResponseBlock:(void (^)(void))responseBlock {
    pthread_t thread = pthread_self();
    BOOL isMainThread = [NSThread isMainThread];
    while (1) {
        message_t *message = NULL;
        @synchronized (self) {
            int32_t availableBytes;
            message_t *buffer = TPCircularBufferTail(&_mainThreadMessageBuffer, &availableBytes);
            if (!buffer) {
                return;
            }
            message_t *end = (message_t *)((char *)buffer + availableBytes);
            BOOL hasUnservicedMessages = NO;
            while (buffer < end && !message) {
                int messageLength = sizeof(message_t) + buffer->userInfoLength;
                if (!buffer->replyServced) {
                    if ((buffer->sourceThread && buffer->sourceThread != thread) && (buffer->sourceThread == NULL && !isMainThread)) {
                        hasUnservicedMessages = YES;
                    } else if (responseBlock && responseBlock != buffer->responseBlock){
                        hasUnservicedMessages = YES;
                    } else {
                        message = (message_t *)malloc(messageLength);
                        memcpy(message, buffer, messageLength);
                        buffer->replyServced = YES;
                    }
                }
                buffer = (message_t *)((char *)buffer + messageLength);
                if (!hasUnservicedMessages) {
                    TPCircularBufferConsume(&_mainThreadMessageBuffer, messageLength);
                }
            }
        }
        if (!message) {
            break;
        }
        if (message->responseBlock) {
            ((__bridge void (^)(void))message->responseBlock)();
            CFBridgingRelease(message->responseBlock);
            _pendingResponses--;
            if (_pollThread && _pendingResponses == 0) {
                _pollThread.pollInterval = kIdleMessagingPollDuration;
            }
        } else if (message->handler){
            message->handler(message->userInfoLength > 0 ? message + 1 : NULL , message->userInfoLength);
        }
        
        if (message->block) {
            CFBridgingRelease(message->block);
        }
        free(message);
    }
}

-(void)processMainThreadMessages {
    [self RongProcessMainThreadMessagesMatchingResponseBlock:nil];
}
static BOOL RongMessageQueueHasPendingMainThreadMessages(__unsafe_unretained RongAudioMessageQueue *THIS) {
    int32_t ignore;
    return TPCircularBufferTail(&THIS->_mainThreadMessageBuffer, &ignore) != NULL;
}
@end
@implementation RongAudioMessagePollThread{
    __weak RongAudioMessageQueue *_messageQueue;
}

-(id)initWithMessageQueue:(RongAudioMessageQueue *)queue{
    if (self = [super init]) {
        _messageQueue = queue;
        return self;
    }
    return nil;
}
-(void)main{
    @autoreleasepool {
        pthread_setname_np("com.rongcloudromatinc.pollthread");
        while (!self.isCancelled) {
            if (_messageQueue.autoProcessTimeout > 0 && RongHostTicksFromSeconds((RongCurrentTimeInHostTicks() - _messageQueue.lastProcessTime)) > _messageQueue.autoProcessTimeout) {
                RongMessageQueueProcessMessagesOnRealtimeThread(_messageQueue);
            }
            if (RongMessageQueueHasPendingMainThreadMessages(_messageQueue)) {
                [_messageQueue performSelectorOnMainThread:@selector(processMainThreadMessages) withObject:nil waitUntilDone:NO];
            }
            usleep(_pollInterval*1.0e6);
        }
    }
}
@end

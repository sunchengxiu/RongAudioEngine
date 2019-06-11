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
static const int kDefaultMessageBufferLength             = 8192;
@interface RongAudioMessagePollThread : NSThread
- (id)initWithMessageQueue:(RongAudioMessageQueue *)queue;
@property(nonatomic , assign)NSTimeInterval pollInterval;
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
    }
}
@end
@implementation RongAudioMessageQueue{
    TPCircularBuffer _realTimeThreadMessageBuffer;
    TPCircularBuffer _mainThreadMessageBuffer;
    pthread_mutex_t _mutex;
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
-(void)processMainThreadMessages{
    
}
@end

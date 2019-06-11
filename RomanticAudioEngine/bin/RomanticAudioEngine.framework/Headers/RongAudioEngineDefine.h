//
//  RongAudioEngineDefine.h
//  RomanticAudioEngine
//
//  Created by 孙承秀 on 2019/6/11.
//  Copyright © 2019 RongCloud. All rights reserved.
//

#ifndef RongAudioEngineDefine_h
#define RongAudioEngineDefine_h

typedef enum {
    /**
     是否允许音频的设备输入
     */
    RongAudioEngineUnitOptionEnableInput           = 1 << 0 ,
    
    /**
     是否允许音频的设备输出
     */
    RongAudioEngineUnitOptionEnableOutput           = 1 << 1 ,
    
    /**
     是否允许使用系统的音频处理单元
     */
    RongAudioEngineUnitOptionUseVoiceProcessing     = 1 << 2 ,
    
    /**
     是否以硬件的采样率为准
     */
    RongAudioEngineUnitOptionUseHardwareSampleRate    = 1 << 3,
    
    /**
     是否允许蓝牙输入
     */
    RongAudioEngineUnitOptionEnableBluetoothInput     = 1 << 4,
    
    /**
     是否和其他app混合播放
     */
    RongAudioEngineUnitOptionAllowMixingWithOtherApps = 1 << 5,
    
    /**
     默认设置
     */
    RongAudioEngineUnitOptionDefaults =
    RongAudioEngineUnitOptionEnableOutput | RongAudioEngineUnitOptionAllowMixingWithOtherApps,
} RongAudioEngineUnitOptions;

#endif /* RongAudioEngineDefine_h */

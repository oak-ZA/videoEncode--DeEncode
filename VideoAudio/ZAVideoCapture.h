//
//  ZAVideoCapture.h
//  VideoAudio
//
//  Created by 张奥 on 2019/10/21.
//  Copyright © 2019 张奥. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>

@protocol ZAVideoCaptureDelegate<NSObject>
//视频采集数据回调
-(void)videoCaptureOutputDataCallback:(CMSampleBufferRef)sampleBuffer;
@end

//配置参数
@interface ZAVideoCaptureParam:NSObject

/*摄像头位置,默认为前置摄像头AVCaptureDevicePositionFront*/
@property (nonatomic, assign)AVCaptureDevicePosition devicePostion;
/*视频分辨率 默认AVCaptureSessionPreset1280x720*/
@property (nonatomic, assign) AVCaptureSessionPreset sessionPreset;
/*帧率 单位: 帧/秒 默认15帧/秒*/
@property (nonatomic, assign) NSInteger frameRate;
/*摄像头方向 默认为当前手机屏幕方向*/
@property (nonatomic, assign) AVCaptureVideoOrientation videoOrientation;
@end

@interface ZAVideoCapture : NSObject
@property (nonatomic, weak) id<ZAVideoCaptureDelegate>delegate;
/*配置参数*/
@property (nonatomic, strong) ZAVideoCaptureParam *captureParam;
/*预览层,把这个图层加在View上就能播放*/
@property (nonatomic, strong) AVCaptureVideoPreviewLayer *videoPreviewLayer;
//初始化
-(instancetype)initWithCaptureParam:(ZAVideoCaptureParam *)param;
/*动态修改视频帧*/
-(void)adjustFrameRate:(NSInteger)frameRate;
/*抓图 block返回UIImage*/
-(void)imageCapture:(void(^)(UIImage *image))completion;
/*摄像头的翻转*/
-(void)reverseCamera;
/*动态修改视频分辨率*/
-(void)changeSessionPreset:(AVCaptureSessionPreset)sesstionPreset;
/*开始采集*/
-(void)startCapture;
/*停止采集*/
-(void)stopCapture;
@end

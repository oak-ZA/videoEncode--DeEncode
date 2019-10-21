//
//  ZAVideoCapture.m
//  VideoAudio
//
//  Created by 张奥 on 2019/10/21.
//  Copyright © 2019 张奥. All rights reserved.
//

#import "ZAVideoCapture.h"

@implementation ZAVideoCaptureParam

-(instancetype)init{
    self = [super init];
    if (self) {
        _devicePostion = AVCaptureDevicePositionFront;
        _sessionPreset = AVCaptureSessionPreset1280x720;
        _frameRate = 15;
        _videoOrientation = AVCaptureVideoOrientationPortrait;
        
        switch ([UIDevice currentDevice].orientation) {
            case UIDeviceOrientationPortrait:
                _videoOrientation = AVCaptureVideoOrientationPortrait;
                break;
            case UIDeviceOrientationPortraitUpsideDown:
                _videoOrientation = AVCaptureVideoOrientationPortrait;
                break;
            case UIDeviceOrientationLandscapeLeft:
                _videoOrientation = AVCaptureVideoOrientationLandscapeLeft;
                break;
            case UIDeviceOrientationLandscapeRight:
                _videoOrientation = AVCaptureVideoOrientationLandscapeRight;
                break;
                
            default:
                break;
        }
    }
    return self;
}

@end

@interface ZAVideoCapture()<AVCaptureVideoDataOutputSampleBufferDelegate>
/*采集会话*/
@property (nonatomic, strong) AVCaptureSession *captureSession;
/*采集输入设备,也就是摄像头*/
@property (nonatomic, strong) AVCaptureDeviceInput *captureDeviceInput;
/*采集输出*/
@property (nonatomic, strong) AVCaptureVideoDataOutput *captureVideoOutput;
/*抓图输出*/
@property (nonatomic, strong) AVCaptureStillImageOutput *captureStillImageOutput;
/*输出连接*/
@property (nonatomic, strong) AVCaptureConnection *captureConnection;
/*是否已经在采集*/
@property (nonatomic, assign) BOOL isCapturing;
@end

@implementation ZAVideoCapture

//视频采集
/*
 
 视频采集的步骤
 
 1、创建并初始化输入（AVCaptureInput）和输出（AVCaptureOutput）
 2、创建并初始化AVCaptureSession，把AVCaptureInput和AVCaptureOutput添加到AVCaptureSession中
 3、调用AVCaptureSession的startRunning开启采集
 
 */

-(instancetype)initWithCaptureParam:(ZAVideoCaptureParam *)param{
    
    if (self = [super init]) {
        
        self.captureParam = param;
        //获取所有摄像头
        NSArray *cameras = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
        //获取当前的摄像头
        NSArray *captureDeviceArray = [cameras filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"position == %d",self.captureParam.devicePostion]];
        if (captureDeviceArray.count == 0) {
            NSLog(@"没有可用的设备");
            return nil;
        }
        //输入设备
        AVCaptureDevice *camera = captureDeviceArray.firstObject;
        self.captureDeviceInput = [AVCaptureDeviceInput deviceInputWithDevice:camera error:nil];
        //输出设备
        self.captureVideoOutput = [[AVCaptureVideoDataOutput alloc] init];
        //设置视频参数 色源 YUV
        NSDictionary *videoSetting = [NSDictionary dictionaryWithObjectsAndKeys: [NSNumber numberWithInt:kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange], kCVPixelBufferPixelFormatTypeKey, nil];
        [self.captureVideoOutput setVideoSettings:videoSetting];
        //设置输出串行队列和数据回调
        dispatch_queue_t outputQueue = dispatch_queue_create("ACVideoCaptureOutputQueue", DISPATCH_QUEUE_SERIAL);
        [self.captureVideoOutput setSampleBufferDelegate:self queue:outputQueue];
        //丢弃延迟的帧
        self.captureVideoOutput.alwaysDiscardsLateVideoFrames = YES;
        //设置抓图输出
        self.captureStillImageOutput = [[AVCaptureStillImageOutput alloc] init];
        [self.captureStillImageOutput setOutputSettings:@{AVVideoCodecKey:AVVideoCodecTypeJPEG}];
        //初始化会话
        self.captureSession = [[AVCaptureSession alloc] init];
        //不使用应用的实例,避免被异常挂断
        self.captureSession.usesApplicationAudioSession = NO;
        //添加输入设备到会话
        if ([self.captureSession canAddInput:self.captureDeviceInput]) {
            [self.captureSession addInput:self.captureDeviceInput];
        }
        //添加输出设备
        if ([self.captureSession canAddOutput:self.captureVideoOutput]) {
            [self.captureSession addOutput:self.captureVideoOutput];
        }
        //设置分辨率
        if ([self.captureSession canSetSessionPreset:AVCaptureSessionPreset1280x720]) {
            self.captureSession.sessionPreset = AVCaptureSessionPreset1280x720;
        }
        
        //连接
        self.captureConnection = [self.captureVideoOutput connectionWithMediaType:AVMediaTypeVideo];
        //设置摄像头镜像,不设置的话前置摄像头采集的图像是反转的
        if (self.captureParam.devicePostion == AVCaptureDevicePositionFront && self.captureConnection.supportsVideoMirroring) {
            self.captureConnection.videoMirrored = YES;
        }
        self.captureConnection.videoOrientation = self.captureParam.videoOrientation;
        //预览层
        self.videoPreviewLayer = [AVCaptureVideoPreviewLayer layerWithSession:self.captureSession];
        self.videoPreviewLayer.connection.videoOrientation = self.captureParam.videoOrientation;
        self.videoPreviewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
        //设置帧率
        [self adjustFrameRate:self.captureParam.frameRate];
    }
    return self;
    
}

/*开始采集*/
-(void)startCapture{
    if (self.isCapturing) {
        NSLog(@"正处于采集状态.....");
        return;
    }
    
    //摄像头权限判断
    AVAuthorizationStatus authStatus = [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeVideo];
    if (authStatus == AVAuthorizationStatusNotDetermined) {
        [AVCaptureDevice requestAccessForMediaType:AVMediaTypeVideo completionHandler:^(BOOL granted) {
            if (granted) {
                NSLog(@"授权成功");
                [self.captureSession startRunning];
                self.isCapturing = YES;
            }else{
                NSLog(@"授权不成功");
            }
        }];
    }else if (authStatus == AVAuthorizationStatusRestricted || authStatus == AVAuthorizationStatusDenied){
        NSLog(@"未授权");
    }else{
        NSLog(@"已授权");
        [self.captureSession startRunning];
        self.isCapturing = YES;
    }
}

/*停止采集*/
-(void)stopCapture{
    if (!self.isCapturing) {
        NSLog(@"已经处于停止采集状态");
        return;
    }
    [self.captureSession stopRunning];
    self.isCapturing = NO;
}
/*动态修改视频帧*/
-(void)adjustFrameRate:(NSInteger)frameRate{
    
    AVFrameRateRange *frameRateRange = self.captureDeviceInput.device.activeFormat.videoSupportedFrameRateRanges.firstObject;
    //处理大于和小于最大帧率和最小帧率的情况
    if (frameRate > frameRateRange.maxFrameRate) {
        frameRate = frameRateRange.maxFrameRate;
    }
    if (frameRate < frameRateRange.minFrameRate) {
        frameRate = frameRateRange.minFrameRate;
    }
    self.captureParam.frameRate = frameRate;
    [self.captureDeviceInput.device lockForConfiguration:nil];
    self.captureDeviceInput.device.activeVideoMinFrameDuration = CMTimeMake(1, (int)frameRate);
    self.captureDeviceInput.device.activeVideoMaxFrameDuration = CMTimeMake(1, (int)frameRate);
    [self.captureDeviceInput.device unlockForConfiguration];
    
}
/*抓图 block返回UIImage*/
-(void)imageCapture:(void(^)(UIImage *image))completion{
    //根据连接取得设备输出的数据
    [self.captureStillImageOutput captureStillImageAsynchronouslyFromConnection:self.captureConnection completionHandler:^(CMSampleBufferRef  _Nullable imageDataSampleBuffer, NSError * _Nullable error) {
       
        if (imageDataSampleBuffer && completion) {
            UIImage *image = [UIImage imageWithData:[AVCaptureStillImageOutput jpegStillImageNSDataRepresentation:imageDataSampleBuffer]];
            completion(image);
        }
        
    }];
}
/*摄像头的翻转*/
-(void)reverseCamera{
    
    //获取摄像头
    NSArray *cameras = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
    //获取当前摄像头方向
    AVCaptureDevicePosition currentPostion = self.captureDeviceInput.device.position;
    AVCaptureDevicePosition toPosition = AVCaptureDevicePositionUnspecified;
    if (currentPostion == AVCaptureDevicePositionBack || currentPostion == AVCaptureDevicePositionUnspecified) {
        toPosition = AVCaptureDevicePositionFront;
    }else{
        toPosition = AVCaptureDevicePositionBack;
    }
    NSArray *captureDeviceArray = [cameras filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"position == %d",toPosition]];
    if (captureDeviceArray.count) {
        NSLog(@"无可用设备");
        return;
    }
    AVCaptureDevice *camera = captureDeviceArray.firstObject;
    AVCaptureDeviceInput *newInput = [AVCaptureDeviceInput deviceInputWithDevice:camera error:nil];
    //修改输入设备
    [self.captureSession beginConfiguration];
    [self.captureSession removeInput:self.captureDeviceInput];
    if ([self.captureSession canAddInput:newInput]) {
        [self.captureSession addInput:newInput];
        self.captureDeviceInput = newInput;
    }
    [self.captureSession commitConfiguration];
    //重新获取连接
    self.captureConnection = [self.captureVideoOutput connectionWithMediaType:AVMediaTypeVideo];
    //设置镜像,否则前置摄像头采集出来的图像是反的
    if (toPosition == AVCaptureDevicePositionFront && self.captureConnection.supportsVideoMirroring) {
        self.captureConnection.videoMirrored = YES;
    }
    self.captureConnection.videoOrientation = self.captureParam.videoOrientation;
    
}

/*动态修改视频分辨率*/
-(void)changeSessionPreset:(AVCaptureSessionPreset)sesstionPreset{
    self.captureParam.sessionPreset = sesstionPreset;
    if ([self.captureSession canSetSessionPreset:sesstionPreset]) {
        self.captureSession.sessionPreset = sesstionPreset;
    }
}

/*摄像头采集的数据回调*/
-(void)captureOutput:(AVCaptureOutput *)output didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection{
    if ([self.delegate respondsToSelector:@selector(videoCaptureOutputDataCallback:)]) {
        [self.delegate videoCaptureOutputDataCallback:sampleBuffer];
    }
}




//获取摄像
-(AVCaptureDevice*)cameraWithPosition:(AVCaptureDevicePosition)postion{
    if (@available(iOS 10.0, *)) {
        
        AVCaptureDeviceDiscoverySession *deviceSession = [AVCaptureDeviceDiscoverySession discoverySessionWithDeviceTypes:@[AVCaptureDeviceTypeBuiltInWideAngleCamera] mediaType:AVMediaTypeVideo position:postion];
        NSArray *cameras = deviceSession.devices;
        for (AVCaptureDevice *device in cameras) {
            return device;
        }
        
    }else{
        NSArray *cameras = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
        for (AVCaptureDevice *device in cameras) {
            if (device.position == postion) {
                return device;
            }
        }
    }
    
    return nil;
}

@end

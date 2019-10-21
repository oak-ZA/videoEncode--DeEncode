//
//  ViewController.m
//  VideoAudio
//
//  Created by 张奥 on 2019/10/18.
//  Copyright © 2019 张奥. All rights reserved.
//

#import "ViewController.h"
#import "ZAVideoCapture.h"
#import <AVFoundation/AVFoundation.h>
#import "VEVideoEncoder.h"
#import "H264Decoder.h"

@interface ViewController ()<ZAVideoCaptureDelegate,VEVideoEncoderDelegate,H264DecoderDelegate>

@property (nonatomic, strong) ZAVideoCapture *videoCapture;
//预览图层
@property (nonatomic, strong) AVCaptureVideoPreviewLayer *previewLayer;
//编码器VideoToolbox
@property (nonatomic, strong) VEVideoEncoder *videoEncoder;
//H264解码器
@property (nonatomic, strong) H264Decoder *h264Decoder;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    ZAVideoCaptureParam *param = [[ZAVideoCaptureParam alloc] init];
    param.sessionPreset = AVCaptureSessionPreset1280x720;
    self.videoCapture = [[ZAVideoCapture alloc] initWithCaptureParam:param];
    self.videoCapture.delegate = self;
    
    //初始化并开始启用视频编码
    VEVideoEncoderParam *encodeParam = [[VEVideoEncoderParam alloc] init];
    encodeParam.encodeWidth = 180;
    encodeParam.encodeHeight = 320;
    encodeParam.bitRate = 512 * 1024;
    self.videoEncoder = [[VEVideoEncoder alloc] initWithParam:encodeParam];
    self.videoEncoder.delegate = self;
    [self.videoEncoder startVideoEncode];
    
    //h264解码
    self.h264Decoder = [[H264Decoder alloc] init];
    self.h264Decoder.delegate = self;
    
    self.previewLayer = self.videoCapture.videoPreviewLayer;
    self.previewLayer.frame = CGRectMake(10, 64, 200, 200);
    
}

- (IBAction)startCapture:(id)sender {
    
    [self.videoCapture startCapture];
    [self.view.layer addSublayer:self.previewLayer];
    
}
- (IBAction)stopCapture:(id)sender {
    [self.videoCapture stopCapture];
    
}

//视频输出回调AVFoundation
-(void)videoCaptureOutputDataCallback:(CMSampleBufferRef)sampleBuffer{

    [self.videoEncoder videoEncodeInputData:sampleBuffer forceKeyFrame:NO];
}
//视频编码回调VideoToolbox
-(void)videoEncodeOutputDataCallback:(NSData *)data isKeyFrame:(BOOL)isKeyFrame{
    NSLog(@"data=====\n%@",data);
    [self.h264Decoder decodeNaluData:data];
}
//视频解码回调h264
-(void)videoDecodeOutputDataCallback:(CVImageBufferRef)imageBuffer{
    
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end

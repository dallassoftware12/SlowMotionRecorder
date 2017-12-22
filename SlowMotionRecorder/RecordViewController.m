//
//  RecordViewController.m
//  SlowMotionRecorder
//
//  Created by Marvin on 12/18/17.
//  Copyright © 2017 Marvin. All rights reserved.
//

#import "RecordViewController.h"
#import "TTMCaptureManager.h"
#import <AssetsLibrary/AssetsLibrary.h>
#import <SVProgressHUD/SVProgressHUD.h>

@interface RecordViewController () <TTMCaptureManagerDelegate>

@property (nonatomic, strong) TTMCaptureManager *captureManager;
@property (nonatomic, strong) UIImage *recStartImage;
@property (nonatomic, strong) UIImage *recStopImage;
@property (nonatomic, strong) UIImage *outerImage1;
@property (nonatomic, strong) UIImage *outerImage2;

@property (nonatomic, assign) NSTimer *timer;
@property (nonatomic, assign) NSTimeInterval startTime;
@property (nonatomic, assign) BOOL isNeededToSave;

@property (nonatomic, weak) IBOutlet UILabel *statusLabel;
@property (nonatomic, weak) IBOutlet UISegmentedControl *fpsControl;
@property (nonatomic, weak) IBOutlet UIButton *recBtn;
@property (nonatomic, weak) IBOutlet UIImageView *outerImageView;
@property (nonatomic, weak) IBOutlet UIView *previewView;

@end


@implementation RecordViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.captureManager = [[TTMCaptureManager alloc] initWithPreviewView:self.previewView
                                                     preferredCameraType:CameraTypeBack
                                                              outputMode:OutputModeVideoData];
    self.captureManager.delegate = self;
    
    UITapGestureRecognizer *tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleDoubleTap:)];
    tapGesture.numberOfTapsRequired = 2;
    [self.view addGestureRecognizer:tapGesture];
    
    
    // Setup images for the Shutter Button
    self.recStartImage = [[UIImage imageNamed:@"ShutterButtonStart"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    [self.recBtn setImage:self.recStartImage forState:UIControlStateNormal];
    
    self.recStopImage = [[UIImage imageNamed:@"ShutterButtonStop"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    
    [self.recBtn setTintColor:[UIColor colorWithRed:245.0/255.0
                                              green:51./255.
                                               blue:51./255.
                                              alpha:1.0]];
    self.outerImage1 = [UIImage imageNamed:@"outer1"];
    self.outerImage2 = [UIImage imageNamed:@"outer2"];
    self.outerImageView.image = self.outerImage1;
}

- (void)dealloc {
    self.isNeededToSave = NO;
    [self.captureManager stopRecording];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation {
    [self.captureManager updateOrientationWithPreviewView:self.previewView];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    
    NSArray<CALayer *> *subLayers = self.previewView.layer.sublayers;
    for (CALayer *layer in subLayers) {
        if ([TTMCaptureManager isCaptureVideoPreviewLayer:layer]) {
            layer.frame = self.previewView.bounds;
            break;
        }
    }
}

#pragma mark - Gesture Handler
- (void)handleDoubleTap:(UITapGestureRecognizer *)sender {
    [self.captureManager toggleContentsGravity];
}


#pragma mark - Private
- (void)saveRecordedFile:(NSURL *)recordedFile {
    [SVProgressHUD showWithStatus:@"Saving..."];
    
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    dispatch_async(queue, ^{
        ALAssetsLibrary *assetLibrary = [[ALAssetsLibrary alloc] init];
        [assetLibrary writeVideoAtPathToSavedPhotosAlbum:recordedFile completionBlock: ^(NSURL *assetURL, NSError *error) {
             dispatch_async(dispatch_get_main_queue(), ^{
                 [SVProgressHUD dismiss];
                 NSString *title = @"Saved!";
                 NSString *message = nil;
                 if (error != nil) {
                     title = @"Failed to save video";
                     message = [error localizedDescription];
                 }
                 
                 UIAlertController *alerController = [UIAlertController alertControllerWithTitle:title message:message preferredStyle:UIAlertControllerStyleAlert];
                 UIAlertAction *okAction = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:nil];
                 [alerController addAction:okAction];
                 [self presentViewController:alerController animated:YES completion:nil];
             });
         }];
    });
}



#pragma mark - Timer Handler
- (void)startStatusTimer {
    [self stopStatusTimer];
    
    self.startTime = [[NSDate date] timeIntervalSince1970];
    self.timer = [NSTimer scheduledTimerWithTimeInterval:0.01 target:self selector:@selector(timerHandler:) userInfo:nil repeats:YES];
}

- (void)stopStatusTimer {
    if (self.timer) {
        [self.timer invalidate];
        self.timer = nil;
    }
}

- (void)timerHandler:(NSTimer *)timer {
    NSTimeInterval current = [[NSDate date] timeIntervalSince1970];
    NSTimeInterval recorded = current - self.startTime;
    
    self.statusLabel.text = [NSString stringWithFormat:@"%.2f", recorded];
}


#pragma mark - IBAction
- (IBAction)onToggleRecord:(id)sender {
    if (!self.captureManager.isRecording) { // REC START
        // change UI
        [self.recBtn setImage:self.recStopImage forState:UIControlStateNormal];
        self.fpsControl.enabled = NO;
        
        // timer start
        [self startStatusTimer];
        
        [self.captureManager startRecording];
    } else { // REC STOP
        
        self.isNeededToSave = YES;
        [self.captureManager stopRecording];
        
        // timer stop
        [self stopStatusTimer];
        
        // change UI
        [self.recBtn setImage:self.recStartImage forState:UIControlStateNormal];
        self.fpsControl.enabled = YES;
    }
}

- (IBAction)onChangedFPS:(UISegmentedControl *)sender {
    // Switch FPS
    CGFloat desiredFps = 0.0;
    switch (self.fpsControl.selectedSegmentIndex) {
        case 1:
            desiredFps = 60.0;
            break;
        case 2:
            desiredFps = 240.0;
            break;
        default:
            break;
    }
    
    
    [SVProgressHUD showWithStatus:@"Switching..."];
    
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    dispatch_async(queue, ^{
        
        if (desiredFps > 0.0) {
            [self.captureManager switchFormatWithDesiredFPS:desiredFps];
        } else {
            [self.captureManager resetFormat];
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if (desiredFps >= 120.0) {
                self.outerImageView.image = self.outerImage2;
            }
            else {
                self.outerImageView.image = self.outerImage1;
            }
            [SVProgressHUD dismiss];
        });
    });
}


#pragma mark - TTMCaptureManager Delegate
- (void)didFinishRecordingToOutputFileAtURL:(NSURL *)outputFileURL error:(NSError *)error {
    if (error) {
        NSLog(@"error:%@", error);
        return;
    }
    
    if (!self.isNeededToSave) {
        return;
    }
    
    [self saveRecordedFile:outputFileURL];
}

@end

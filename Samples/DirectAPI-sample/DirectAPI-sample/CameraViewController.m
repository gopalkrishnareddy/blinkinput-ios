//
//  ViewController.m
//  Camera-Sample
//
//  Created by Jura on 09/08/15.
//  Copyright © 2015 MicroBlink. All rights reserved.
//

#import "CameraViewController.h"
#import "CameraView.h"
#import <AVFoundation/AVFoundation.h>
#import <MicroBlink/MicroBlink.h>

@interface CameraViewController () <AVCaptureAudioDataOutputSampleBufferDelegate, AVCaptureVideoDataOutputSampleBufferDelegate, PPCoordinatorDelegate>

@property (weak, nonatomic) IBOutlet CameraView *cameraView;

@property (nonatomic, strong) AVCaptureSession *captureSession;

@property (nonatomic, strong) PPCoordinator *coordinator;

@end

@implementation CameraViewController

static NSString *rawOcrParserId = @"Raw ocr";

- (void)viewDidLoad {
    [super viewDidLoad];
}

- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator {
    [super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];

    // Note that the app delegate controls the device orientation notifications required to use the device orientation.
    UIDeviceOrientation deviceOrientation = [UIDevice currentDevice].orientation;
    if (UIDeviceOrientationIsPortrait(deviceOrientation) || UIDeviceOrientationIsLandscape(deviceOrientation)) {
        AVCaptureVideoPreviewLayer *previewLayer = (AVCaptureVideoPreviewLayer *)self.cameraView.layer;
        previewLayer.connection.videoOrientation = (AVCaptureVideoOrientation)deviceOrientation;
    }
}

- (IBAction)closeCamera:(id)sender {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)viewDidAppear:(BOOL)animate {
    [super viewDidAppear:animate];
    [self startCaptureSession];
};

- (void)addNotificationObserver {
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(appplicationWillResignActive:)
                                                 name:UIApplicationWillResignActiveNotification
                                               object:nil];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(appplicationWillEnterForeground:)
                                                 name:UIApplicationWillEnterForegroundNotification
                                               object:nil];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(applicationDidEnterBackgroundNotification:)
                                                 name:UIApplicationDidEnterBackgroundNotification
                                               object:nil];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(applicationWillTerminateNotification:)
                                                 name:UIApplicationWillTerminateNotification
                                               object:nil];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(captureSessionDidStartRunningNotification:)
                                                 name:AVCaptureSessionDidStartRunningNotification
                                               object:nil];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(captureSessionDidStopRunningNotification:)
                                                 name:AVCaptureSessionDidStopRunningNotification
                                               object:nil];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(captureSessionRuntimeErrorNotification:)
                                                 name:AVCaptureSessionRuntimeErrorNotification
                                               object:nil];
}

- (void)removeNotificationObserver {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self addNotificationObserver];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [self stopCaptureSession];
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    [self removeNotificationObserver];
}

- (void)appplicationWillResignActive:(NSNotification*)note {
    NSLog(@"Will resign active!");
}

- (void)appplicationWillEnterForeground:(NSNotification*)note {
    NSLog(@"appplicationWillEnterForeground!");
    [self startCaptureSession];
}

- (void)applicationDidEnterBackgroundNotification:(NSNotification*)note {
    NSLog(@"applicationDidEnterBackgroundNotification!");
    [self stopCaptureSession];
}

- (void)applicationWillTerminateNotification:(NSNotification*)note {
    NSLog(@"applicationWillTerminateNotification!");
}

- (void)captureSessionDidStartRunningNotification:(NSNotification*)note {
    NSLog(@"captureSessionDidStartRunningNotification!");

    [UIView animateWithDuration:0.3 animations:^{
        self.cameraPausedLabel.alpha = 0.0;
    }];
}

- (void)captureSessionDidStopRunningNotification:(NSNotification*)note {
    NSLog(@"captureSessionDidStopRunningNotification!");

    [UIView animateWithDuration:0.3 animations:^{
        self.cameraPausedLabel.alpha = 1.0;
    }];
}

- (void)captureSessionRuntimeErrorNotification:(NSNotification*)note {
    NSLog(@"captureSessionRuntimeErrorNotification!");
}


- (void)startCaptureSession {

    // Create session
    self.captureSession = [[AVCaptureSession alloc] init];
    self.captureSession.sessionPreset = AVCaptureSessionPresetHigh;

    // Init the device inputs
    AVCaptureDeviceInput *videoInput = [[AVCaptureDeviceInput alloc] initWithDevice:[self cameraWithPosition:AVCaptureDevicePositionBack]
                                                                              error:nil];
    [self.captureSession addInput:videoInput];

    // setup video data output
    AVCaptureVideoDataOutput *videoDataOutput = [[AVCaptureVideoDataOutput alloc] init];
    [videoDataOutput setVideoSettings:[NSDictionary dictionaryWithObject:[NSNumber numberWithInt:kCVPixelFormatType_32BGRA] forKey:(id)kCVPixelBufferPixelFormatTypeKey]];
    [self.captureSession addOutput:videoDataOutput];
    
    dispatch_queue_t queue = dispatch_queue_create("myQueue", NULL);
    [videoDataOutput setSampleBufferDelegate:self queue:queue];

    // Setup the preview view.
    self.cameraView.session = self.captureSession;
    
    [self createCoordinator];

    [self.captureSession startRunning];
}

- (void)stopCaptureSession {
    [self.captureSession stopRunning];
    self.captureSession = nil;
}

// Find a camera with the specificed AVCaptureDevicePosition, returning nil if one is not found
- (AVCaptureDevice *)cameraWithPosition:(AVCaptureDevicePosition) position {
    NSArray *devices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
    for (AVCaptureDevice *device in devices) {
        if ([device position] == position) {
            return device;
        }
    }
    return nil;
}

- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection {
    PPImage *image = [PPImage imageWithCmSampleBuffer:sampleBuffer];
    image.orientation = PPProcessingOrientationLeft;
    [self.coordinator processImage:image];
}

- (void)createCoordinator {
    
    
    
    /** 1. Initialize the Scanning settings */
    
    // Initialize the scanner settings object. This initialize settings with all default values.
    PPSettings *settings = [[PPSettings alloc] init];
    
    
    /** 2. Setup the license key */
    
    // Visit www.microblink.com to get the license key for your app
    // // Valid until 2017-12-21
    settings.licenseSettings.licenseKey = @"VVDNJH5C-2NATW4P4-7TYCJVR4-EEX53IOG-VL7U3D6C-FP5ITGVQ-6SW4L45J-JDDQ4BGZ";
    
    
    /**
     * 3. Set up what is being scanned. See detailed guides for specific use cases.
     * Here's an example for initializing raw OCR scanning.
     */
    
    // To specify we want to perform OCR recognition, initialize the OCR recognizer settings
    PPBlinkInputRecognizerSettings *ocrRecognizerSettings = [[PPBlinkInputRecognizerSettings alloc] init];
    
    // We want raw OCR parsing
    [ocrRecognizerSettings addOcrParser:[[PPRawOcrParserFactory alloc] init] name:rawOcrParserId];
    
    // Add the recognizer setting to a list of used recognizer
    [settings.scanSettings addRecognizerSettings:ocrRecognizerSettings];
    
    /** 4. Initialize the Scanning Coordinator object */
    
    PPCoordinator *coordinator = [[PPCoordinator alloc] initWithSettings:settings delegate:self];
    
    self.coordinator = coordinator;
}

- (void)coordinator:(PPCoordinator *)coordinator didOutputResults:(NSArray<PPRecognizerResult *> *)results {
    // Here you process scanning results. Scanning results are given in the array of PPRecognizerResult objects.
    
    
    // Collect data from the result
    for (PPRecognizerResult* result in results) {
        
        if ([result isKindOfClass:[PPBlinkInputRecognizerResult class]]) {
            PPBlinkInputRecognizerResult* ocrRecognizerResult = (PPBlinkInputRecognizerResult*)result;
            
            NSLog(@"OCR results are:");
            NSLog(@"Raw ocr: %@", [ocrRecognizerResult parsedResultForName:rawOcrParserId]);
            
            PPOcrLayout* ocrLayout = [ocrRecognizerResult ocrLayout];
            NSLog(@"Dimensions of ocrLayout are %@", NSStringFromCGRect([ocrLayout box]));
        }
    };
    
}

@end

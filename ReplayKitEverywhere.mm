//
//  ReplayKitObj.mm
//  ReplayKitObj
//
//  Created by ester on 2017/12/12.
//  Copyright (c) 2017年 __MyCompanyName__. All rights reserved.
//

#if TARGET_OS_SIMULATOR
#error Do not support the simulator, please use the real iPhone Device.
#endif

#import <Foundation/Foundation.h>

#import <ReplayKit/ReplayKit.h>


@interface ReplayKitEverywhere : UIViewController
@end

static RPPreviewViewController *previewControllerShare = NULL;

@implementation ReplayKitEverywhere

+(void)startRec{
    
    RPScreenRecorder* recorder = RPScreenRecorder.sharedRecorder;
    
    if ([recorder respondsToSelector:@selector(startRecordingWithHandler:)]){
        //iOS 10+
        [recorder startRecordingWithHandler:^(NSError * error) {
            if(error != nil) {
                return;
            }
        }];
    } else {
        //iOS 9
        [recorder startRecordingWithMicrophoneEnabled:true handler:^(NSError * error) {
            if(error != nil) {
                return;
            }
        }];
    }
    
}

+(void)stopRec{
    [[RPScreenRecorder sharedRecorder] stopRecordingWithHandler:^(RPPreviewViewController * _Nullable previewViewController, NSError * _Nullable error){
        if(error){
            return;
        }else if(previewViewController != nil){
            
            previewViewController.previewControllerDelegate = self;
            previewControllerShare = previewViewController;
            
            UIViewController *rootController = [UIApplication sharedApplication].keyWindow.rootViewController;
            [rootController presentViewController:previewViewController animated:YES completion:nil];
            
        }
        
    }];
    
}

+(void)startOrStopRec{
    RPScreenRecorder* recorder = RPScreenRecorder.sharedRecorder;
    if (!recorder.available) {
        UIAlertController* alert = [UIAlertController alertControllerWithTitle:@"ReplayKit Everywhere"
                                                                       message:@"ReplayKit is not available and cannot start the recording.\nAre you mirroring through Airplay? Or is another app using ReplayKit right now? "
                                                                preferredStyle:UIAlertControllerStyleAlert];
        UIAlertAction* defaultAction = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault
                                                              handler:^(UIAlertAction * action) {}];
        
        [alert addAction:defaultAction];
        [[UIApplication sharedApplication].keyWindow.rootViewController presentViewController:alert animated:YES completion:nil];
        return;
    }
    if (recorder.recording) {
        [self stopRec];
    } else {
        [self startRec];
    }
}

+(void)previewControllerDidFinish:(RPPreviewViewController *)previewController {
    NSLog(@"previewControllerDidFinish");
    if (previewControllerShare != NULL) {
        [previewControllerShare dismissViewControllerAnimated:YES completion:nil];
        previewControllerShare = NULL;
    }
}

+(void)previewController:(RPPreviewViewController *)previewController didFinishWithActivityTypes:(NSSet <NSString *>*)activityTypes {
	NSLog(@"activity - %@",activityTypes);
}

@end



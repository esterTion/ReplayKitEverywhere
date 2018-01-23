//
//  ReplayKitObj.mm
//  ReplayKitObj
//
//  Created by ester on 2017/12/12.
//  Copyright (c) 2017年 __MyCompanyName__. All rights reserved.
//

// CaptainHook by Ryan Petrich
// see https://github.com/rpetrich/CaptainHook/

#if TARGET_OS_SIMULATOR
#error Do not support the simulator, please use the real iPhone Device.
#endif

#import <Foundation/Foundation.h>

// Objective-C runtime hooking using CaptainHook:
//   1. declare class using CHDeclareClass()
//   2. load class using CHLoadClass() or CHLoadLateClass() in CHConstructor
//   3. hook method using CHOptimizedMethod()
//   4. register hook using CHHook() in CHConstructor
//   5. (optionally) call old method using CHSuper()

#import <ReplayKit/ReplayKit.h>


@interface ReplayKitEverywhere : UIViewController
@end

@implementation ReplayKitEverywhere

+(void)startRec{
    
    RPScreenRecorder* recorder = RPScreenRecorder.sharedRecorder;
    
    if ([recorder respondsToSelector:@selector(startRecordingWithHandler:)]){
        [recorder startRecordingWithHandler:^(NSError * error) {
            if(error != nil) {
                return;
            }
        }];
    } else {
        [recorder startRecordingWithMicrophoneEnabled:false handler:^(NSError * error) {
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
            
            UIViewController *rootController = [UIApplication sharedApplication].keyWindow.rootViewController;
            [rootController presentViewController:previewViewController animated:YES completion:nil];
            
        }
        
    }];
    
    NSLog(@"end");
    
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
    [[UIApplication sharedApplication].keyWindow.rootViewController dismissViewControllerAnimated:YES completion:nil];
}

+(void)previewController:(RPPreviewViewController *)previewController didFinishWithActivityTypes:(NSSet <NSString *>*)activityTypes {
	NSLog(@"activity - %@",activityTypes);
}

@end



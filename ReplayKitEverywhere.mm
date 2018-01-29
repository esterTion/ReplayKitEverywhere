//
//  ReplayKitEverywhere.mm
//  ReplayKitEverywhere
//
//  Created by ester on 2017/12/12.
//

#if TARGET_OS_SIMULATOR
#error Do not support the simulator, please use the real iPhone Device.
#endif

#import <Foundation/Foundation.h>
#import <ReplayKit/ReplayKit.h>
#define LIGHTMESSAGING_TIMEOUT 500
#import <LightMessaging/LightMessaging.h>

LMConnection connection = {
    MACH_PORT_NULL,
    "com.estertion.replaykiteverywhere.lmserver"
};


@interface ReplayKitEverywhere : UIViewController
@end

static RPPreviewViewController *previewControllerShare = NULL;

@implementation ReplayKitEverywhere

+(void)warnWithError:(NSError *)error {
    NSString *errorMessage;
    switch([error code]) {
        case RPRecordingErrorUserDeclined:
            errorMessage = @"You've cancelled recording";
            break;
        case RPRecordingErrorDisabled:
            errorMessage = @"Recording disabled via parental controls";
            break;
        case RPRecordingErrorFailedToStart:
            errorMessage = @"Failed to start recording";
            break;
        case RPRecordingErrorFailed:
        case RPRecordingErrorUnknown:
            errorMessage = @"Unknown error occurred";
            break;
        case RPRecordingErrorInsufficientStorage:
            errorMessage = @"There's not enough storage available on the device for saving the recording";
            break;
        case RPRecordingErrorContentResize:
            errorMessage = @"Recording interrupted by multitasking and content resizing";
            break;
        default:
            errorMessage = [error localizedDescription];
    }
    [self showBulletin:errorMessage];
}

+(void)showBulletin:(NSString *)message {
    //send message
    NSData *msg = [message dataUsingEncoding:NSUTF8StringEncoding];
    SInt32 messageId = 0x1111; // this is arbitrary i think
    LMConnectionSendOneWayData(&connection, messageId, (CFDataRef)msg);
}

+(void)startRec{
    
    RPScreenRecorder* recorder = RPScreenRecorder.sharedRecorder;
    
    @try {
    if ([recorder respondsToSelector:@selector(startRecordingWithHandler:)]){
        //iOS 10+
        recorder.microphoneEnabled = true;
        [recorder startRecordingWithHandler:^(NSError * error) {
            if(error != nil) {
                [ReplayKitEverywhere warnWithError:error];
                return;
            } else {
                [ReplayKitEverywhere showBulletin:@"Record started"];
            }
        }];
    } else {
        //iOS 9
        [recorder startRecordingWithMicrophoneEnabled:true handler:^(NSError * error) {
            if(error != nil) {
                [ReplayKitEverywhere warnWithError:error];
                return;
            } else {
                [ReplayKitEverywhere showBulletin:@"Record started"];
            }
        }];
    }

    } @catch (NSException *exception) {
        [ReplayKitEverywhere showBulletin:@"ReplayKit is not compatible with this app"];
    }
    
}

+(void)stopRec{
    [[RPScreenRecorder sharedRecorder] stopRecordingWithHandler:^(RPPreviewViewController * _Nullable previewViewController, NSError * _Nullable error){
        if(error){
            [ReplayKitEverywhere warnWithError:error];
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
                                                                       message:[[NSBundle bundleWithPath:@"/Library/Application Support/ReplayKit Everywhere.bundle"] localizedStringForKey:@"RKE_NOT_AVAILABLE" value:@"ReplayKit is not available and cannot start the recording.\nAre you mirroring through Airplay? Or is another app using ReplayKit right now?" table:nil]
                                                                preferredStyle:UIAlertControllerStyleAlert];
        UIAlertAction* defaultAction = [UIAlertAction actionWithTitle:[[NSBundle bundleWithIdentifier:@"com.apple.UIKit"] localizedStringForKey:@"Dismiss" value:@"" table:nil]

 style:UIAlertActionStyleDefault
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
    if (previewControllerShare != NULL) {
        [previewControllerShare dismissViewControllerAnimated:YES completion:nil];
        previewControllerShare = NULL;
    }
}

+(void)previewController:(RPPreviewViewController *)previewController didFinishWithActivityTypes:(NSSet <NSString *>*)activityTypes {
}

@end



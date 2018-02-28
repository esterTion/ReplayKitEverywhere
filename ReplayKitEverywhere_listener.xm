//
//	ReplayKitEverywhere_listener.m
//	ReplayKitEverywhere
//
//	Created by ester on 2018/1/17.
//

#import <libactivator/libactivator.h>
#import <BulletinBoard/BBBulletinRequest.h>
#import <SpringBoard/SpringBoard.h>
#import <SpringBoard/SBAlertItemsController.h>
#import <SpringBoard/SBApplication.h>
#import <SpringBoard/SBApplicationController.h>
#import <SpringBoard/SBBulletinBannerController.h>
#import <Foundation/Foundation.h>
#import <ReplayKit/ReplayKit.h>
#import <objc/runtime.h>
#import <notify.h>
#import "ReplayKitEverywhere.h"
#define LIGHTMESSAGING_TIMEOUT 500
#import <LightMessaging/LightMessaging.h>
//#import <PhotoLibraryServices/PLAssetsSaver.h>
@interface PLAssetsSaver : NSObject {
	NSMutableArray * __pendingSaveAssetJobs;
}

@property (nonatomic, retain) NSMutableArray *_pendingSaveAssetJobs;

+ (id)sharedAssetsSaver;

- (void)saveVideoAtPath:(id)arg1 properties:(id)arg2 completionBlock:(id /* block */)arg3;

@end


static NSBundle *tweakBundle = NULL;

void showBulletin(NSString *message) {
	BBBulletinRequest *bulletin = [[%c(BBBulletinRequest) alloc] init];
	bulletin.sectionID = @"com.estertion.replaykiteverywhere";
	bulletin.title = @"ReplayKit Everywhere";
	bulletin.message = message;
	SBBulletinBannerController *controller = [%c(SBBulletinBannerController) sharedInstance];
	if ([controller respondsToSelector:@selector(observer:addBulletin:forFeed:playLightsAndSirens:withReply:)])
		[controller observer:nil addBulletin:bulletin forFeed:2 playLightsAndSirens:YES withReply:nil];
	else if ([controller respondsToSelector:@selector(observer:addBulletin:forFeed:)])
		[controller observer:nil addBulletin:bulletin forFeed:2];
	[bulletin release];
}

//http://iphonedevwiki.net/index.php/LightMessaging
void showBulletinListener(CFMachPortRef port, LMMessage *message, CFIndex size, void *info) {
	// get the reply port
	mach_port_t replyPort = message->head.msgh_remote_port;

	// Check validity of message
	if (!LMDataWithSizeIsValidMessage(message, size)) {
		LMSendReply(replyPort, NULL, 0);
		LMResponseBufferFree((LMResponseBuffer *)message);
		return;
	}
	
	// Get the data you received
	void *data = LMMessageGetData(message);
	size_t length = LMMessageGetDataLength(message);
	// Make it into a CFDataRef object
	CFDataRef cfdata = CFDataCreateWithBytesNoCopy(kCFAllocatorDefault, (const UInt8 *)data ?: (const UInt8 *)&data, length, kCFAllocatorNull);

	NSString *msg = [[NSString alloc] initWithData:(NSData*)cfdata encoding:NSUTF8StringEncoding];;
	showBulletin([tweakBundle localizedStringForKey:msg value:@"" table:nil]);

	// Free the CFDataRef object
	if (cfdata) {
		CFRelease(cfdata);
	}
}

@interface RKEverywhereListener : NSObject <LAListener>
@end

static BOOL recording = false;
static NSString* recordingApp = NULL;
@implementation RKEverywhereListener

- (void)activator:(LAActivator *)activator receiveEvent:(LAEvent *)event {
	SpringBoard *springBoard = (SpringBoard*) [objc_getClass("SpringBoard") sharedApplication];
	SBApplication *front = (SBApplication*) [springBoard _accessibilityFrontMostApplication];
	recordingApp = front.bundleIdentifier;
	notify_post([[front.bundleIdentifier stringByAppendingString:@".replaykit_receiver"] cStringUsingEncoding:NSUTF8StringEncoding]);
}


- (NSString *)activator:(LAActivator *)activator requiresLocalizedGroupForListenerName:(NSString *)listenerName {
	return @"ReplayKit Everywhere";
}
- (NSString *)activator:(LAActivator *)activator requiresLocalizedTitleForListenerName:(NSString *)listenerName {
	if (recording)
		return [tweakBundle localizedStringForKey:@"Stop recording" value:@"" table:nil];
	else
		return [tweakBundle localizedStringForKey:@"Start recording" value:@"" table:nil];
}
- (NSString *)activator:(LAActivator *)activator requiresLocalizedDescriptionForListenerName:(NSString *)listenerName {
	return [tweakBundle localizedStringForKey:@"Record your screen with/without microphone, right in the app" value:@"" table:nil];
}
- (NSArray *)activator:(LAActivator *)activator requiresCompatibleEventModesForListenerWithName:(NSString *)listenerName {
	return [NSArray arrayWithObjects:@"application", nil];
}

@end

static id observer;
static id RKEListenerInstance = NULL;
%ctor
{
	@autoreleasepool
	{
		observer = [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidFinishLaunchingNotification object:nil queue:[NSOperationQueue mainQueue]
			usingBlock:^(NSNotification *notification) {
				NSString *bundleId = [[NSBundle mainBundle] bundleIdentifier];
				@try {
					if ([bundleId isEqualToString:@"com.apple.springboard"]) {

						RKEListenerInstance = [RKEverywhereListener new];
						[LASharedActivator registerListener:RKEListenerInstance forName:@"com.estertion.replaykiteverywhere"];
						LMStartService((char *)"com.estertion.replaykiteverywhere.lmserver", CFRunLoopGetCurrent(), (CFMachPortCallBack)showBulletinListener);
						tweakBundle = [NSBundle bundleWithPath:@"/Library/PreferenceBundles/ReplayKitEverywherePrefs.bundle"];
						NSLog(@"[ReplayKit Everywhere] Registered activator listener");
						int notify_token;
						notify_register_dispatch("com.estertion.replaykiteverywhere.record_started",
							&notify_token,
							dispatch_get_main_queue(),^(int token) {
								recording = true;
								[LASharedActivator unregisterListenerWithName:@"com.estertion.replaykiteverywhere"];
								[RKEListenerInstance release];
								RKEListenerInstance = [RKEverywhereListener new];
								[LASharedActivator registerListener:RKEListenerInstance forName:@"com.estertion.replaykiteverywhere"];
							}
						);
						notify_register_dispatch("com.estertion.replaykiteverywhere.record_stopped",
							&notify_token,
							dispatch_get_main_queue(),^(int token) {
								recording = false;
								[LASharedActivator unregisterListenerWithName:@"com.estertion.replaykiteverywhere"];
								[RKEListenerInstance release];
								RKEListenerInstance = [RKEverywhereListener new];
								[LASharedActivator registerListener:RKEListenerInstance forName:@"com.estertion.replaykiteverywhere"];
							}
						);
						notify_register_dispatch("com.estertion.replaykiteverywhere.save_record",
							&notify_token,
							dispatch_get_main_queue(),^(int token) {
								NSFileManager *fm = [NSFileManager defaultManager];
								NSString *path = [NSString stringWithFormat:@"/var/mobile/Library/ReplayKit/RPMovie_%@.m4v", recordingApp];
								if ([fm fileExistsAtPath:path]) {
									showBulletin([tweakBundle localizedStringForKey:@"Saving record to camera roll" value:@"" table:nil]);
									[[PLAssetsSaver sharedAssetsSaver] saveVideoAtPath:path properties:nil completionBlock:^(NSURL *url) {
										if (url) {
											showBulletin([tweakBundle localizedStringForKey:@"Record saved! " value:@"" table:nil]);
											[[NSFileManager defaultManager] removeItemAtPath:[NSString stringWithFormat:@"/var/mobile/Library/ReplayKit/RPMovie_%@.m4v", recordingApp] error:nil];
										}
									}];
								} else {
									showBulletin([NSString stringWithFormat:[tweakBundle localizedStringForKey:@"Failed to save record, file RPMovie_%@.m4v not found" value:@"" table:nil], recordingApp]);
								}
							}
						);

					} else {
						
						NSProcessInfo *processInfo = [NSClassFromString(@"NSProcessInfo") processInfo];
						NSArray *args = processInfo.arguments;
						NSUInteger count = args.count;
						if (count != 0) {
							NSString *executablePath = args[0];
							BOOL isExtensionOrApp = [executablePath rangeOfString:@"/Application"].location != NSNotFound;
							if (isExtensionOrApp) {
								NSString *bundleId = [[NSBundle mainBundle] bundleIdentifier];
								int notify_token;
								notify_register_dispatch([[bundleId stringByAppendingString:@".replaykit_receiver"] cStringUsingEncoding:NSUTF8StringEncoding],
									&notify_token,
									dispatch_get_main_queue(),^(int token) {
										[ReplayKitEverywhere startOrStopRec];	
									}
								);
								NSLog(@"[ReplayKit Everywhere] Started record listener for app %@", bundleId);
								[[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidEnterBackgroundNotification object:nil queue:[NSOperationQueue mainQueue]
									usingBlock:^(NSNotification *notification) {
										if (RPScreenRecorder.sharedRecorder.recording){
											[ReplayKitEverywhere stopRec];
										}
									}
								];
							}
						}

					}
				} @catch (NSException *exception) {
					NSLog(@"[ReplayKit Everywhere] Not compatible with app %@", bundleId);
				}
			}
		];
	}
}

%hook RPPreviewViewController 
- (BOOL)shouldAutorotate
{
	return NO;
}
- (NSUInteger)supportedInterfaceOrientations {
	return [[UIApplication sharedApplication].keyWindow.rootViewController supportedInterfaceOrientations];
}
%end


// ReplayKitEverywhere.mm


LMConnection connection = {
	MACH_PORT_NULL,
	"com.estertion.replaykiteverywhere.lmserver"
};

NSString* RKEGetSettingValue(NSString *key, NSString *defaultValue) {
	NSDictionary *setting = [NSDictionary dictionaryWithContentsOfFile: @"/var/mobile/Library/Preferences/com.estertion.replaykiteverywhere.plist"];
	if (setting == NULL) return defaultValue;
	NSObject *value = [setting objectForKey:key];
	if (value == NULL) return defaultValue;

	NSString *valueStr;
	if ([value isKindOfClass:[NSString class]]) {
		valueStr = (NSString *)value;
	} else if ([value isKindOfClass:[NSNumber class]]) {
		valueStr = [(NSNumber *)value stringValue];
	} else {
		valueStr = defaultValue;
	}
	return valueStr;
}

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

	if (previewControllerShare != NULL) {
		[previewControllerShare dismissViewControllerAnimated:NO completion:nil];
		previewControllerShare = NULL;
	}
	
	RPScreenRecorder* recorder = RPScreenRecorder.sharedRecorder;
	
	@try {
		NSString *microphoneEnabledStr = RKEGetSettingValue(@"microphoneEnabled", @"1");
		NSLog(@"[ReplayKit Everywhere] Retrived setting microphoneEnabled %@", microphoneEnabledStr);
		BOOL microphoneEnabled = [microphoneEnabledStr isEqualToString:@"1"];
	if ([recorder respondsToSelector:@selector(startRecordingWithHandler:)]){
		//iOS 10+
		recorder.microphoneEnabled = microphoneEnabled;
		[recorder startRecordingWithHandler:^(NSError * error) {
			if(error != nil) {
				[ReplayKitEverywhere warnWithError:error];
				return;
			} else {
				notify_post("com.estertion.replaykiteverywhere.record_started");
				[ReplayKitEverywhere showBulletin:@"Record started"];
			}
		}];
	} else {
		//iOS 9
		[recorder startRecordingWithMicrophoneEnabled:microphoneEnabled handler:^(NSError * error) {
			if(error != nil) {
				[ReplayKitEverywhere warnWithError:error];
				return;
			} else {
				notify_post("com.estertion.replaykiteverywhere.record_started");
				[ReplayKitEverywhere showBulletin:@"Record started"];
			}
		}];
	}

	} @catch (NSException *exception) {
		[ReplayKitEverywhere showBulletin:@"ReplayKit is not compatible with this app"];
	}
	
}

+(void)stopRec{
	notify_post("com.estertion.replaykiteverywhere.record_stopped");
	[[RPScreenRecorder sharedRecorder] stopRecordingWithHandler:^(RPPreviewViewController * _Nullable previewViewController, NSError * _Nullable error){
		if(error){
			[ReplayKitEverywhere warnWithError:error];
			return;
		}else if(previewViewController != nil){
			
			if ([RKEGetSettingValue(@"autosave", @"0") isEqualToString:@"1"]) {
				notify_post("com.estertion.replaykiteverywhere.save_record");
				return;
			}
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
																		 message:[[NSBundle bundleWithPath:@"/Library/PreferenceBundles/ReplayKitEverywherePrefs.bundle"] localizedStringForKey:@"RKE_NOT_AVAILABLE" value:@"ReplayKit is not available and cannot start the recording.\nAre you mirroring through Airplay? Or is another app using ReplayKit right now?" table:nil]
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

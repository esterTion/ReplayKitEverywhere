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
#import "GetBSDProcessList.h"
//#import <PhotoLibraryServices/PLAssetsSaver.h>
@interface PLAssetsSaver : NSObject {
	NSMutableArray * __pendingSaveAssetJobs;
}
@property (nonatomic, retain) NSMutableArray *_pendingSaveAssetJobs;
+ (id)sharedAssetsSaver;
- (void)saveVideoAtPath:(id)arg1 properties:(id)arg2 completionBlock:(id /* block */)arg3;
@end

static id observer;
static id RKEListenerInstance = NULL;
static BOOL inApp = false;
static NSDictionary *setting = NULL;
static NSMutableArray* touches = NULL;
static NSMutableArray* pendingRemove = NULL;
static NSBundle *tweakBundle = NULL;
static BOOL recording = false;
static RPPreviewViewController *previewControllerShare = NULL;
static int remainingTouch = 0;
static int fadeStartCount = 0;
static int fadeEndCount = 0;

@interface RKEBulletinRequest: BBBulletinRequest
@end
@implementation RKEBulletinRequest
 -(bool)bulletinAlertShouldOverrideQuietMode {
	 return true;
 }
@end

@interface RKE_RPScreenRecorder : NSObject
-stopRecordingWithVideoURLHandler:(id)block;
@end

void showBulletin(NSString *message) {
	NSLog(@"[replaykit] %@", message);
	RKEBulletinRequest *bulletin = [[RKEBulletinRequest alloc] init];
	bulletin.sectionID = @"com.estertion.replaykiteverywhere";
	bulletin.title = @"ReplayKit Everywhere";
	bulletin.message = message;
	SBBulletinBannerController *controller = [%c(SBBulletinBannerController) sharedInstance];
	[controller observer:nil addBulletin:bulletin forFeed:2 playLightsAndSirens:YES withReply:nil];
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

@try{
	NSError* error;
	NSDictionary *msg = [NSJSONSerialization JSONObjectWithData:(NSData*)cfdata options:kNilOptions error:&error];
	if ([msg[@"cmd"] isEqualToString:@"bulletin"]) {
		showBulletin([tweakBundle localizedStringForKey:msg[@"value"] value:@"" table:nil]);
	} else if ([msg[@"cmd"] isEqualToString:@"save_record"]) {
		NSFileManager *fm = [NSFileManager defaultManager];
		NSString *path = msg[@"value"];
		if ([fm fileExistsAtPath:path]) {
			showBulletin([tweakBundle localizedStringForKey:@"Saving record to camera roll" value:@"" table:nil]);
			[[PLAssetsSaver sharedAssetsSaver] saveVideoAtPath:path properties:nil completionBlock:^(NSURL *url) {
				if (url) {
					showBulletin([tweakBundle localizedStringForKey:@"Record saved! " value:@"" table:nil]);
					[[NSFileManager defaultManager] removeItemAtPath:path error:nil];
				}
			}];
		} else {
			showBulletin([NSString stringWithFormat:[tweakBundle localizedStringForKey:@"Failed to save record, file %@ not found" value:@"" table:nil], path]);
		}
	} else {
		NSLog(@"[ReplayKit Everywhere] Unknown cmd received: %@", msg[@"cmd"]);
	}
}@catch(NSException *e) {}
	// Free the CFDataRef object
	if (cfdata) {
		CFRelease(cfdata);
	}
}

@interface RKEverywhereListener : NSObject <LAListener>
@end

@implementation RKEverywhereListener

- (void)activator:(LAActivator *)activator receiveEvent:(LAEvent *)event {
	SpringBoard *springBoard = (SpringBoard*) [objc_getClass("SpringBoard") sharedApplication];
	SBApplication *front = (SBApplication*) [springBoard _accessibilityFrontMostApplication];
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

/*
 * From https://developer.apple.com/library/content/technotes/tn2050/_index.html#//apple_ref/doc/uid/DTS10003081-CH1-SUBSECTION10
 */
static void replaydDidExited(
    CFFileDescriptorRef f, 
    CFOptionFlags       callBackTypes, 
    void *              info
)
{
    struct kevent   event;
    (void) kevent( CFFileDescriptorGetNativeDescriptor(f), NULL, 0, &event, 1, NULL);

    NSLog(@"[ReplayKit Everywhere] replayd[%d] terminated", (int) (pid_t) event.ident);
		if (recording) {
			showBulletin([tweakBundle localizedStringForKey:@"Warning: recorder just crashed, current recording might be corrupted and it might not work until app restarted" value:@"" table:nil]);
			recording = false;
			[LASharedActivator unregisterListenerWithName:@"com.estertion.replaykiteverywhere"];
			[RKEListenerInstance release];
			RKEListenerInstance = [RKEverywhereListener new];
			[LASharedActivator registerListener:RKEListenerInstance forName:@"com.estertion.replaykiteverywhere"];
		}
}
static void observeReplaydExit() {
	kinfo_proc *results = NULL;
	size_t procCount=0;
	GetBSDProcessList(&results, &procCount);
	kinfo_proc* current_process = results;
	for (int i=0; i<procCount && i<max_processes; i++)
	{
		if (strcmp(current_process->kp_proc.p_comm, "replayd") == 0) {
			int                     kq;
			struct kevent           changes;
			CFFileDescriptorContext context = { 0, NULL, NULL, NULL, NULL };
			CFRunLoopSourceRef      rls;

			// Create the kqueue and set it up to watch for SIGCHLD. Use the 
			// new-in-10.5 EV_RECEIPT flag to ensure that we get what we expect.

			kq = kqueue();

			EV_SET(&changes, current_process->kp_proc.p_pid, EVFILT_PROC, EV_ADD | EV_RECEIPT, NOTE_EXIT, 0, NULL);
			(void) kevent(kq, &changes, 1, &changes, 1, NULL);

			// Wrap the kqueue in a CFFileDescriptor (new in Mac OS X 10.5!). Then 
			// create a run-loop source from the CFFileDescriptor and add that to the 
			// runloop.

			CFFileDescriptorRef noteExitKQueueRef = CFFileDescriptorCreate(NULL, kq, true, replaydDidExited, &context);
			rls = CFFileDescriptorCreateRunLoopSource(NULL, noteExitKQueueRef, 0);
			CFRunLoopAddSource(CFRunLoopGetCurrent(), rls, kCFRunLoopDefaultMode);
			CFRelease(rls);

			CFFileDescriptorEnableCallBacks(noteExitKQueueRef, kCFFileDescriptorReadCallBack);

			NSLog(@"[ReplayKit Everywhere] replayd[%d] started", current_process->kp_proc.p_pid);

			break;
		}
		current_process += 1;
	}
	free(results);
	results = NULL;
}

UIWindow* customWindowMethod(id self, SEL _cmd) {
	return [UIApplication sharedApplication].keyWindow;
}

void reloadSetting() {
	[setting release];
	setting = [[NSMutableDictionary alloc] initWithContentsOfFile: @"/var/mobile/Library/Preferences/com.estertion.replaykiteverywhere.plist"];
	NSLog(@"[ReplayKit Everywhere] Reloaded settings");
}
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
						notify_register_dispatch("com.estertion.replaykiteverywhere.replayd_started",
							&notify_token,
							dispatch_get_main_queue(),^(int token) {
								observeReplaydExit();
							}
						);
						observeReplaydExit();

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
								[[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidBecomeActiveNotification object:nil queue:[NSOperationQueue mainQueue]
									usingBlock:^(NSNotification *notification) {
										reloadSetting();
									}
								];
								inApp = true;

								//Check and set window selector method
								if (![[[UIApplication sharedApplication] delegate] respondsToSelector:@selector(window)]) {
									class_addMethod(
										[[[UIApplication sharedApplication] delegate] class],
										@selector(window),
										(IMP) customWindowMethod,
										"@@:"
									);
								}

								touches = [[NSMutableArray alloc] init];
								pendingRemove = [[NSMutableArray alloc] init];
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
- (BOOL)prefersStatusBarHidden
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

+(void)showBulletin:(NSString*)msg {
	[self sendDataToSB:msg cmd:@"bulletin"];
}
+(void)sendDataToSB:(NSString *)value cmd:(NSString *)cmd {
	//send message
	NSDictionary *dict = @{
		@"cmd": cmd,
		@"value": value
	};
	NSError *error;
	NSData *msg = [NSJSONSerialization dataWithJSONObject:dict options:kNilOptions error:&error];
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
	if ([RKEGetSettingValue(@"autosave", @"0") isEqualToString:@"1"]) {
		[(RKE_RPScreenRecorder*)[RPScreenRecorder sharedRecorder] stopRecordingWithVideoURLHandler:^(NSURL* url) {
			NSString *path = [[url standardizedURL] path];
			[self sendDataToSB:path cmd:@"save_record"];
		}];
	} else {
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
	dispatch_async(dispatch_get_main_queue(), ^{
		if (previewControllerShare != NULL) {
			[previewControllerShare dismissViewControllerAnimated:YES completion:nil];
			previewControllerShare = NULL;
		}
	});
}

+(void)previewController:(RPPreviewViewController *)previewController didFinishWithActivityTypes:(NSSet <NSString *>*)activityTypes {
}

@end

int findTouch(double x, double y) {
	for (int i=0; i<touches.count; i++) {
		CGPoint touch;
		[touches[i][@"point"] getValue:&touch];
		if (touch.x == x && touch.y == y) return i;
	}
	return -1;
}
%hook UIApplication

-(void) sendEvent:(UIEvent*)event {
	%orig;
	if (!inApp) return;
	if ([RKEGetSettingValue(@"indicator", @"1") isEqualToString:@"0"]) return;
	if ([RKEGetSettingValue(@"indicator_always", @"0") isEqualToString:@"0"] && !RPScreenRecorder.sharedRecorder.recording) return;
	if ([event type] == UIEventTypeTouches) {
		for (UITouch* touch in event.allTouches) {
			UIView *keyWindow = [UIApplication sharedApplication].keyWindow;
			CGPoint point = [touch locationInView:keyWindow];
			CGPoint prevPoint = [touch previousLocationInView:keyWindow];
			int foundTouchIndex;
			UIView* touchIndicator = NULL;
			switch ([touch phase]) {
				case UITouchPhaseBegan:
					touchIndicator = [[UIView alloc] initWithFrame:CGRectMake(point.x - 10, point.y - 10, 20, 20)];
					touchIndicator.userInteractionEnabled = NO;
					touchIndicator.alpha = 0.7;
					touchIndicator.layer.cornerRadius = 10;
					touchIndicator.backgroundColor = [UIColor whiteColor];
					touchIndicator.layer.borderColor = [UIColor blackColor].CGColor;
					touchIndicator.layer.borderWidth = 1.0f;
					[keyWindow addSubview:touchIndicator];
					[touches addObject: @{@"point":[NSValue valueWithCGPoint:point], @"indicator": touchIndicator}];
					remainingTouch++;
					break;
				case UITouchPhaseMoved:
					foundTouchIndex = findTouch(prevPoint.x, prevPoint.y);
					if (foundTouchIndex != -1) {
						touchIndicator = touches[foundTouchIndex][@"indicator"];
						[touches replaceObjectAtIndex:foundTouchIndex withObject:@{@"point":[NSValue valueWithCGPoint:point], @"indicator": touchIndicator}];
						touchIndicator.frame = CGRectMake(point.x - 10, point.y - 10, 20, 20);
					}
					break;
				case UITouchPhaseEnded:
				case UITouchPhaseCancelled:
					foundTouchIndex = findTouch(prevPoint.x, prevPoint.y);
					if (foundTouchIndex != -1) {
						touchIndicator = touches[foundTouchIndex][@"indicator"];
					} else {
						foundTouchIndex = findTouch(point.x, point.y);
						if (foundTouchIndex != -1) {
							touchIndicator = touches[foundTouchIndex][@"indicator"];
						} else {
							NSLog(@"[ReplayKit Everywhere] touch [%g,%g] not found to remove", point.x, point.y);
						}
					}
					remainingTouch--;

					//found touch, add to remove queue & remove from touches array
					if (touchIndicator != NULL) {
						[pendingRemove addObject:@{
							@"animated": @NO,
							@"view": touchIndicator
						}];
						[touches removeObjectAtIndex:foundTouchIndex];
						[UIView animateWithDuration:0.2 animations:^() {
							for (int i=0; i<pendingRemove.count; i++) {
								NSNumber *animated = pendingRemove[i][@"animated"];
								if ([animated boolValue] == NO) {
									UIView *touchIndicator = pendingRemove[i][@"view"];
									pendingRemove[i] = @{
										@"animated": @YES,
										@"view": touchIndicator
									};
									touchIndicator.alpha = 0.0;
									fadeStartCount++;
								}
							}
						} completion:^(BOOL finished) {
							fadeEndCount++;
							if (fadeStartCount <= fadeEndCount) {
								@try {
									for (int i=0; i<pendingRemove.count; i++) {
										UIView *touchIndicator = pendingRemove[i][@"view"];
										[touchIndicator removeFromSuperview];
										[touchIndicator release];
									}
									[pendingRemove removeObjectsInRange:NSMakeRange(0, pendingRemove.count)];
									fadeStartCount = 0;
									fadeEndCount = 0;
								} @catch(NSException *e) {
								}
							}
						}];
					}

					//clear point not removed
					if (remainingTouch == 0 && touches.count > 0) {
						NSLog(@"[ReplayKit Everywhere] cleaning remaining touch");
						for (int i=0; i<touches.count; i++) {
							touchIndicator = touches[i][@"indicator"];
							[touchIndicator removeFromSuperview];
							[touchIndicator release];
						}
						[touches removeObjectsInRange:NSMakeRange(0, touches.count)];
					}
					break;
			}
		}
	}
}

%end

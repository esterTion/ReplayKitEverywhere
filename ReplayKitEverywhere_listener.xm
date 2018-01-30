//
//  ReplayKitEverywhere_listener.m
//  ReplayKitEverywhere
//
//  Created by ester on 2018/1/17.
//

#import <libactivator/libactivator.h>
#import <BulletinBoard/BBBulletinRequest.h>
#import <SpringBoard/SpringBoard.h>
#import <SpringBoard/SBAlertItemsController.h>
#import <SpringBoard/SBApplication.h>
#import <SpringBoard/SBApplicationController.h>
#import <SpringBoard/SBBulletinBannerController.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <notify.h>
#import "ReplayKitEverywhere.h"
#define LIGHTMESSAGING_TIMEOUT 500
#import <LightMessaging/LightMessaging.h>

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
	return [tweakBundle localizedStringForKey:@"Start/Stop recording" value:@"" table:nil];
}
- (NSString *)activator:(LAActivator *)activator requiresLocalizedDescriptionForListenerName:(NSString *)listenerName {
	return [tweakBundle localizedStringForKey:@"Record your screen with/withour microphone, right in the app" value:@"" table:nil];
}
- (NSArray *)activator:(LAActivator *)activator requiresCompatibleEventModesForListenerWithName:(NSString *)listenerName {
	return [NSArray arrayWithObjects:@"application", nil];
}

@end

%hook UIApplication

static NSArray *blackList = @[ @"MailAppController", @"FBWildeApplication" ];

- (void)_run {
	NSString *classString = NSStringFromClass([self class]);
	if ([@"SpringBoard" isEqualToString:classString]) {
		[LASharedActivator registerListener:[RKEverywhereListener new] forName:@"com.estertion.replaykiteverywhere"];
		LMStartService((char *)"com.estertion.replaykiteverywhere.lmserver", CFRunLoopGetCurrent(), (CFMachPortCallBack)showBulletinListener);
		tweakBundle = [NSBundle bundleWithPath:@"/Library/PreferenceLoader/Preferences/ReplayKitEverywhere"];
	} else if (![blackList containsObject:classString]) {
		NSProcessInfo *processInfo = [NSClassFromString(@"NSProcessInfo") processInfo];
		NSArray *args = processInfo.arguments;
		NSUInteger count = args.count;
		if (count != 0) {
			NSString *executablePath = args[0];
			if (executablePath) {
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
				}
			}
		}
	}

 %orig;
}

%end

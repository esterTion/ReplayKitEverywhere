//
//  ReplayKitEverywhere_activator.m
//  ReplayKitObj
//
//  Created by lcz on 2018/1/17.
//
//

#import <libactivator/libactivator.h>
#import <SpringBoard/SpringBoard.h>
#import <SpringBoard/SBAlertItemsController.h>
#import <SpringBoard/SBApplication.h>
#import <SpringBoard/SBApplicationController.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <notify.h>
#import "ReplayKitEverywhere.h"

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
	return @"Start/Stop recording";
}
- (NSString *)activator:(LAActivator *)activator requiresLocalizedDescriptionForListenerName:(NSString *)listenerName {
	return @"Record your screen with/withour microphone, right in the app";
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
		%log(@"Registering SpringBoard for activator events");
		[LASharedActivator registerListener:[RKEverywhereListener new] forName:@"com.estertion.replaykiteverywhere"];
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

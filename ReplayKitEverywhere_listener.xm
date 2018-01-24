//
//  ReplayKitEverywhere_activator.m
//  ReplayKitObj
//
//  Created by lcz on 2018/1/17.
//
//

#import <libactivator/libactivator.h>
#import <libobjcipc/objcipc.h>
#import <SpringBoard/SpringBoard.h>
#import <SpringBoard/SBAlertItemsController.h>
#import <SpringBoard/SBApplication.h>
#import <SpringBoard/SBApplicationController.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import "ReplayKitEverywhere.h"

@interface RKEverywhereListener : NSObject <LAListener>
@end

static SpringBoard *springBoard = nil;

@implementation RKEverywhereListener

- (void)activator:(LAActivator *)activator receiveEvent:(LAEvent *)event {

	SpringBoard *springBoard = (SpringBoard*) [objc_getClass("SpringBoard") sharedApplication];
	SBApplication *front = (SBApplication*) [springBoard _accessibilityFrontMostApplication];
	[OBJCIPC sendMessageToAppWithIdentifier:front.bundleIdentifier messageName:@"startOrStopRecord" dictionary:nil replyHandler:^(NSDictionary *response) {
                event.handled = YES;
	}];
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
		springBoard = (SpringBoard*) self;
		[LASharedActivator registerListener:[RKEverywhereListener new] forName:@"com.estertion.replaykiteverywhere"];
	} else if (![blackList containsObject:classString]) {
		[OBJCIPC registerIncomingMessageFromSpringBoardHandlerForMessageName:@"startOrStopRecord" handler:^NSDictionary *(NSDictionary *message) {
			   dispatch_async(dispatch_get_main_queue(), ^{
           		[ReplayKitEverywhere startOrStopRec];	
        	});
            return nil;
        }];
	}

 %orig;
}

%end

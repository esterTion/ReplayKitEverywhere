#include "RKERootListController.h"

static NSBundle *tweakBundle;
static NSBundle *uikitBundle;

@implementation RKERootListController

- (NSArray *)specifiers {
	if (!_specifiers) {
		tweakBundle = [NSBundle bundleWithPath:@"/Library/PreferenceBundles/ReplayKitEverywherePrefs.bundle"];
		uikitBundle = [NSBundle bundleWithIdentifier:@"com.apple.UIKit"];
		_specifiers = [[self loadSpecifiersFromPlistName:@"Root" target:self] retain];
	}

	return _specifiers;
}

- (NSString *)getTempFileSize {
	unsigned int totalSize = 0;
	NSFileManager *fm = [NSFileManager defaultManager];
	NSArray *files = [fm contentsOfDirectoryAtPath: @"/User/Library/ReplayKit" error:NULL];
	for (id file in files) {
		NSDictionary *attribute = [fm attributesOfItemAtPath:[@"/User/Library/ReplayKit/" stringByAppendingString:(NSString *)file] error:NULL];
		totalSize += [attribute[@"NSFileSize"] unsignedIntValue];
	}
	return [self prettifySize:totalSize];
}

- (void)deleteTempFiles {
	UIAlertController* alert = [UIAlertController alertControllerWithTitle:[tweakBundle localizedStringForKey:@"Delete all temporary files?" value:nil table:nil]
                                                                 message:[tweakBundle localizedStringForKey:@"This action cannot be reverted" value:nil table:nil]
                                                        preferredStyle:UIAlertControllerStyleAlert];
	UIAlertAction* confirmAction = [UIAlertAction actionWithTitle:[uikitBundle localizedStringForKey:@"Delete" value:@"" table:nil] style:UIAlertActionStyleDestructive handler:^(UIAlertAction * actionIn) {
		NSFileManager *fm = [NSFileManager defaultManager];
		NSArray *files = [fm contentsOfDirectoryAtPath: @"/User/Library/ReplayKit" error:NULL];
		for (id file in files) {
			[fm removeItemAtPath:[@"/User/Library/ReplayKit/" stringByAppendingString:(NSString *)file] error:NULL];
		}
		UIAlertController* alert = [UIAlertController alertControllerWithTitle:[tweakBundle localizedStringForKey:@"Files deleted" value:nil table:nil] message:nil preferredStyle:UIAlertControllerStyleAlert];
		UIAlertAction* action = [UIAlertAction actionWithTitle:[uikitBundle localizedStringForKey:@"Dismiss" value:@"" table:nil] style:UIAlertActionStyleDefault handler:nil];
		[alert addAction:action];
		[[UIApplication sharedApplication].keyWindow.rootViewController presentViewController:alert animated:YES completion:nil];
	}];
  [alert addAction:confirmAction];
  UIAlertAction* cancelAction = [UIAlertAction actionWithTitle:[uikitBundle localizedStringForKey:@"Cancel" value:@"" table:nil] style:UIAlertActionStyleCancel handler:nil];
  [alert addAction:cancelAction];
  [[UIApplication sharedApplication].keyWindow.rootViewController presentViewController:alert animated:YES completion:nil];
}

- (NSString *)prettifySize:(unsigned int)size {
	double sizeF = size;
	NSArray *sizeUnit = @[
		@" B",
		@" KB",
		@" MB",
		@" GB"
	];
	char sizeUnitIndex = 0;
	while (sizeF >= 1024) {
		sizeF /= 1024;
		sizeUnitIndex++;
	}
	return [[NSString stringWithFormat:@"%.2f", sizeF] stringByAppendingString:sizeUnit[sizeUnitIndex]];
}

@end

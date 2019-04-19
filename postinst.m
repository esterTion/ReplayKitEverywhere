#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <stdio.h>
#include <spawn.h>

extern char **environ;

void run_cmd(char *cmd)
{
    pid_t pid;
    char *argv[] = {"sh", "-c", cmd, NULL};
    int status;
    
    status = posix_spawn(&pid, "/bin/sh", NULL, NULL, argv, environ);
    if (status == 0) {
        if (waitpid(pid, &status, 0) == -1) {
            perror("waitpid");
        }
    }
}

int main (int argc, const char * argv[])
{
	bool supportHEVC = [[AVAssetExportSession allExportPresets] containsObject:@"AVAssetExportPresetHEVCHighestQuality"];
  if (supportHEVC) {
    NSString* rootSpecifierPlistPath = @"/Library/PreferenceBundles/ReplayKitEverywherePrefs.bundle/Root.plist";
    NSMutableDictionary* rootSpecifierPlist = [NSMutableDictionary dictionaryWithContentsOfFile:rootSpecifierPlistPath];
    for (NSMutableDictionary *item in rootSpecifierPlist[@"items"]) {
      if ([item[@"key"] isEqualToString:@"useHEVC"]) {
        item[@"enabled"] = @"1";
        printf("Your device support HEVC encoding\n");
        break;
      }
    }
    [rootSpecifierPlist writeToFile:rootSpecifierPlistPath atomically:true];
  }

  printf("Restarting replayd\n");
  run_cmd("launchctl stop com.apple.replayd");
  run_cmd("launchctl start com.apple.replayd");
  return 0;
}
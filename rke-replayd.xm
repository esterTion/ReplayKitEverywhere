//
//  rke-replayd.xm
//  ReplayKitEverywhere
//
//  Created by ester on 2018/1/30.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <AudioToolbox/AudioToolbox.h>

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

%hookf(OSStatus, AudioQueueNewInput, AudioStreamBasicDescription *inFormat, AudioQueueInputCallback inCallbackProc, void *inUserData, CFRunLoopRef inCallbackRunLoop, CFStringRef inCallbackRunLoopMode, UInt32 inFlags, AudioQueueRef  _Nullable *outAQ) {
    inFormat->mBytesPerPacket = 4;
    inFormat->mBytesPerFrame = 4;
    inFormat->mChannelsPerFrame = 2;
    NSString *quality = RKEGetSettingValue(@"quality", @"0");
    if ([quality isEqualToString:@"2"] || [quality isEqualToString:@"3"]) {
      inFormat->mSampleRate = 48000.0;
    }

    return %orig;
}

static NSDictionary *videoBitrate = @{
  @"1": @4000000LL,
  @"2": @8000000LL,
  @"3": @15000000LL
};
static NSDictionary *audioBitrate = @{
  @"1": @128000LL,
  @"2": @256000LL,
  @"3": @320000LL
};
static NSDictionary *audioSampleRate = @{
  @"1": @44100.0,
  @"2": @48000.0,
  @"3": @48000.0
};

%hook AVAssetWriterInput

- (instancetype)initWithMediaType:(NSString *)mediaType outputSettings:(NSDictionary<NSString *, id> *)outputSettings {
  NSString *quality = RKEGetSettingValue(@"quality", @"0");
  if (videoBitrate[quality] != nil) {
    NSMutableDictionary *modify = [outputSettings mutableCopy];
    if ([mediaType isEqualToString:@"vide"]) {
      NSLog(@"[ReplayKit Everywhere] Recording at quality level %@", quality);
      NSMutableDictionary *compressModify = [modify[@"AVVideoCompressionPropertiesKey"] mutableCopy];
      compressModify[AVVideoAverageBitRateKey] = videoBitrate[quality];
      modify[@"AVVideoCompressionPropertiesKey"] = compressModify;
    } else if ([mediaType isEqualToString:@"soun"]) {
      modify[AVSampleRateKey] = audioSampleRate[quality];
      modify[AVEncoderBitRateKey] = audioBitrate[quality];
    }
    outputSettings = [NSDictionary dictionaryWithDictionary:modify];
    [modify release];
  }

  return %orig(mediaType, outputSettings);
}

%end

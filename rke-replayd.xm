//
//  rke-replayd.xm
//  ReplayKitEverywhere
//
//  Created by ester on 2018/1/30.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <AudioToolbox/AudioToolbox.h>

NSNumber* getQualitySetting() {
  NSDictionary *setting = [NSDictionary dictionaryWithContentsOfFile: @"/var/mobile/Library/Preferences/com.estertion.replaykiteverywhere.plist"];
  if (setting == NULL) return @0;
  NSString *quality = [setting objectForKey:@"quality"];
  if (quality == NULL) return @0;
  NSNumberFormatter *f = [[NSNumberFormatter alloc] init];
  f.numberStyle = NSNumberFormatterDecimalStyle;
  NSNumber *qua = [f numberFromString:quality];
  [f release];
  if (qua == NULL) return @0;
  if ([qua compare:@0] == NSOrderedDescending && [qua compare:@4] == NSOrderedAscending) return qua;
  else return @0;
}

%hookf(OSStatus, AudioQueueNewInput, AudioStreamBasicDescription *inFormat, AudioQueueInputCallback inCallbackProc, void *inUserData, CFRunLoopRef inCallbackRunLoop, CFStringRef inCallbackRunLoopMode, UInt32 inFlags, AudioQueueRef  _Nullable *outAQ) {
    inFormat->mBytesPerPacket = 4;
    inFormat->mBytesPerFrame = 4;
    inFormat->mChannelsPerFrame = 2;
    NSNumber *quality = getQualitySetting();
    if ([quality isEqualToNumber:@2] || [quality isEqualToNumber:@3]) {
      inFormat->mSampleRate = 48000.0;
    }

    return %orig;
}

static NSDictionary *videoBitrate = @{
  @1: @4000000LL,
  @2: @8000000LL,
  @3: @15000000LL,
};
static NSDictionary *audioBitrate = @{
  @1: @128000LL,
  @2: @256000LL,
  @3: @320000LL,
};
static NSDictionary *audioSampleRate = @{
  @1: @44100.0,
  @2: @48000.0,
  @3: @48000.0,
};

%hook AVAssetWriterInput

- (instancetype)initWithMediaType:(NSString *)mediaType outputSettings:(NSDictionary<NSString *, id> *)outputSettings {
  NSNumber *quality = getQualitySetting();
  if (![quality isEqualToNumber:@0]) {
    NSMutableDictionary *modify = [outputSettings mutableCopy];
    if ([mediaType isEqualToString:@"vide"]) {
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

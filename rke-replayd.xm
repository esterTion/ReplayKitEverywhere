//
//  rke-replayd.xm
//  ReplayKitEverywhere
//
//  Created by ester on 2018/1/30.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <AudioToolbox/AudioToolbox.h>

%hookf(OSStatus, AudioQueueNewInput, AudioStreamBasicDescription *inFormat, AudioQueueInputCallback inCallbackProc, void *inUserData, CFRunLoopRef inCallbackRunLoop, CFStringRef inCallbackRunLoopMode, UInt32 inFlags, AudioQueueRef  _Nullable *outAQ) {
    inFormat->mBytesPerPacket = 4;
    inFormat->mBytesPerFrame = 4;
    inFormat->mChannelsPerFrame = 2;

    NSLog(@"AudioStreamBasicDescription:\n mSampleRate: %f\n mFormatID:%u\n mFormatFlags:%d\n mFramesPerPacket:%d\n mChannelsPerFrame:%d\n mBitsPerChannel:%d\n mBytesPerPacket:%d\n mBytesPerFrame:%d", 
      inFormat->mSampleRate,
      inFormat->mFormatID,
      inFormat->mFormatFlags,
      inFormat->mFramesPerPacket,
      inFormat->mChannelsPerFrame,
      inFormat->mBitsPerChannel,
      inFormat->mBytesPerPacket ,
      inFormat->mBytesPerFrame );
    return %orig;
}

%hook AVAssetWriterInput

- (instancetype)initWithMediaType:(NSString *)mediaType outputSettings:(NSDictionary<NSString *, id> *)outputSettings {
  if ([mediaType isEqualToString:@"soun"]) {
    NSMutableDictionary *modify = [[NSMutableDictionary alloc] init];
    [modify addEntriesFromDictionary:outputSettings];
    [modify setValue:[NSNumber numberWithDouble:44100.0] forKey:AVSampleRateKey];
    [modify setValue:[NSNumber numberWithInt:256000LL] forKey:AVEncoderBitRateKey];
    outputSettings = [NSDictionary dictionaryWithDictionary:modify];
    [modify release];
  }
  NSLog(@"[rke-avfoundation-param-logger] initWithMediaType:%@ outputSettings:%@", mediaType, outputSettings);

  return %orig(mediaType, outputSettings);
}

%end

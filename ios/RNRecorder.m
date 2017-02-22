//
//  RNRecorder.m
//  IOSVoiceRecorder
//
//  Created by CiKa on 2/22/17.
//  Copyright © 2017 Facebook. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "RNRecorder.h"
#import <React/RCTConvert.h>
#import <React/RCTBridge.h>
#import <React/RCTUtils.h>
#import <React/RCTEventDispatcher.h>
#import <AVFoundation/AVFoundation.h>

NSString *const AudioRecorderEventProgress = @"recordingProgress";
NSString *const AudioRecorderEventFinished = @"recordingFinished";

@implementation RNRecorder {
  
  AVAudioRecorder *_audioRecorder;
  
  NSURL *_audioFileURL;
  NSNumber *_audioQuality;
  NSNumber *_audioEncoding;
  NSNumber *_audioChannels;
  NSNumber *_audioSampleRate;
  AVAudioSession *_recordSession;
  NSString *pathForFile;
}

@synthesize bridge = _bridge;

RCT_EXPORT_MODULE();

- (void)audioRecorderDidFinishRecording:(AVAudioRecorder *)recorder successfully:(BOOL)flag {
  [self.bridge.eventDispatcher sendAppEventWithName:AudioRecorderEventFinished body:@{
                                                                                      @"status": flag ? @"OK" : @"ERROR",
                                                                                      @"audioFileURL": [_audioFileURL absoluteString]
                                                                                      }];
}

- (NSString *) applicationDocumentsDirectory
{
  NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
  NSString *basePath = ([paths count] > 0) ? [paths objectAtIndex:0] : nil;
  return basePath;
}

RCT_EXPORT_METHOD(prepareRecordingAtPath:(NSString *)fileName sampleRate:(float)sampleRate channels:(nonnull NSNumber *)channels quality:(NSString *)quality encoding:(NSString *)encoding)
{

  NSString *cachePath = [self getCachePath];
  pathForFile = [NSString stringWithFormat:@"%@/%@", cachePath, fileName];
  _audioFileURL = [NSURL fileURLWithPath: pathForFile];
  
  // Default options
  _audioQuality = [NSNumber numberWithInt:AVAudioQualityHigh];
  _audioEncoding = [NSNumber numberWithInt:kAudioFormatAppleIMA4];
  _audioChannels = [NSNumber numberWithInt:2];
  _audioSampleRate = [NSNumber numberWithFloat:44100.0];

  
  // Set audio quality from options
  if (quality != nil) {
    if ([quality  isEqual: @"Low"]) {
      _audioQuality =[NSNumber numberWithInt:AVAudioQualityLow];
    } else if ([quality  isEqual: @"Medium"]) {
      _audioQuality =[NSNumber numberWithInt:AVAudioQualityMedium];
    } else if ([quality  isEqual: @"High"]) {
      _audioQuality =[NSNumber numberWithInt:AVAudioQualityHigh];
    }
  }
  
  // Set channels from options
  if (channels != nil) {
    _audioChannels = channels;
  }
  
  // Set audio encoding from options
  if (encoding != nil) {
    if ([encoding  isEqual: @"lpcm"]) {
      _audioEncoding =[NSNumber numberWithInt:kAudioFormatLinearPCM];
    } else if ([encoding  isEqual: @"ima4"]) {
      _audioEncoding =[NSNumber numberWithInt:kAudioFormatAppleIMA4];
    } else if ([encoding  isEqual: @"aac"]) {
      _audioEncoding =[NSNumber numberWithInt:kAudioFormatMPEG4AAC];
    } else if ([encoding  isEqual: @"MAC3"]) {
      _audioEncoding =[NSNumber numberWithInt:kAudioFormatMACE3];
    } else if ([encoding  isEqual: @"MAC6"]) {
      _audioEncoding =[NSNumber numberWithInt:kAudioFormatMACE6];
    } else if ([encoding  isEqual: @"ulaw"]) {
      _audioEncoding =[NSNumber numberWithInt:kAudioFormatULaw];
    } else if ([encoding  isEqual: @"alaw"]) {
      _audioEncoding =[NSNumber numberWithInt:kAudioFormatALaw];
    } else if ([encoding  isEqual: @"mp1"]) {
      _audioEncoding =[NSNumber numberWithInt:kAudioFormatMPEGLayer1];
    } else if ([encoding  isEqual: @"mp2"]) {
      _audioEncoding =[NSNumber numberWithInt:kAudioFormatMPEGLayer2];
    } else if ([encoding  isEqual: @"alac"]) {
      _audioEncoding =[NSNumber numberWithInt:kAudioFormatAppleLossless];
    } else if ([encoding  isEqual: @"amr"]) {
      _audioEncoding =[NSNumber numberWithInt:kAudioFormatAMR];
    }
  }
  
  // Set sample rate from options
  _audioSampleRate = [NSNumber numberWithFloat:sampleRate];
  
  NSDictionary *recordSettings = [NSDictionary dictionaryWithObjectsAndKeys:
                                  _audioQuality, AVEncoderAudioQualityKey,
                                  _audioEncoding, AVFormatIDKey,
                                  _audioChannels, AVNumberOfChannelsKey,
                                  _audioSampleRate, AVSampleRateKey,
                                  nil];
  
  
  NSError *error = nil;
  
  _recordSession = [AVAudioSession sharedInstance];
  [_recordSession setCategory:AVAudioSessionCategoryMultiRoute error:nil];
  
  _audioRecorder = [[AVAudioRecorder alloc]
                    initWithURL:_audioFileURL
                    settings:recordSettings
                    error:&error];
  

  _audioRecorder.delegate = self;
  
  if (error) {
    NSLog(@"error: %@", [error localizedDescription]);
    // TODO: dispatch error over the bridge
  } else {
    [_audioRecorder prepareToRecord];
  }
}

RCT_EXPORT_METHOD(startRecording)
{
  if (!_audioRecorder.recording) {
    
    [_recordSession setActive:YES error:nil];
    [_audioRecorder record];
    
  }
}

RCT_EXPORT_METHOD(stopRecording)
{
  [_audioRecorder stop];
  [_recordSession setActive:NO error:nil];

}

RCT_EXPORT_METHOD(pauseRecording)
{
  if (_audioRecorder.recording) {
    [_audioRecorder pause];
  }
}

RCT_EXPORT_METHOD(checkAuthorizationStatus:(RCTPromiseResolveBlock)resolve reject:(__unused RCTPromiseRejectBlock)reject)
{
  AVAudioSessionRecordPermission permissionStatus = [[AVAudioSession sharedInstance] recordPermission];
  switch (permissionStatus) {
    case AVAudioSessionRecordPermissionUndetermined:
      resolve(@("undetermined"));
      break;
    case AVAudioSessionRecordPermissionDenied:
      resolve(@("denied"));
      break;
    case AVAudioSessionRecordPermissionGranted:
      resolve(@("granted"));
      break;
    default:
      reject(RCTErrorUnspecified, nil, RCTErrorWithMessage(@("Error checking device authorization status.")));
      break;
  }
}

RCT_EXPORT_METHOD(requestAuthorization:(RCTPromiseResolveBlock)resolve
                  rejecter:(__unused RCTPromiseRejectBlock)reject)
{
  [[AVAudioSession sharedInstance] requestRecordPermission:^(BOOL granted) {
    if(granted) {
      resolve(@YES);
    } else {
      resolve(@NO);
    }
  }];
}


- (NSString *)getCachePath
{
  NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
  NSString *documentsDirectory = [paths objectAtIndex:0];
  return [NSString stringWithFormat:@"%@/audioCache", documentsDirectory];
}



@end

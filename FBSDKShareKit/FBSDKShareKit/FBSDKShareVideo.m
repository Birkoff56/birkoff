/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 * All rights reserved.
 *
 * This source code is licensed under the license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import "FBSDKShareVideo.h"

#import <FBSDKShareKit/FBSDKShareErrorDomain.h>
#import <FBSDKShareKit/_FBSDKShareUtility.h>

#import "FBSDKSharePhoto.h"

NSString *const kFBSDKShareVideoURLKey = @"videoURL";

@implementation FBSDKShareVideo

#pragma mark - Class Methods

+ (instancetype)videoWithData:(NSData *)data
{
  FBSDKShareVideo *video = [FBSDKShareVideo new];
  video.data = data;
  return video;
}

+ (instancetype)videoWithData:(NSData *)data previewPhoto:(FBSDKSharePhoto *)previewPhoto
{
  FBSDKShareVideo *video = [FBSDKShareVideo new];
  video.data = data;
  video.previewPhoto = previewPhoto;
  return video;
}

+ (instancetype)videoWithVideoAsset:(PHAsset *)videoAsset
{
  FBSDKShareVideo *video = [FBSDKShareVideo new];
  video.videoAsset = videoAsset;
  return video;
}

+ (instancetype)videoWithVideoAsset:(PHAsset *)videoAsset previewPhoto:(FBSDKSharePhoto *)previewPhoto
{
  FBSDKShareVideo *video = [FBSDKShareVideo new];
  video.videoAsset = videoAsset;
  video.previewPhoto = previewPhoto;
  return video;
}

+ (instancetype)videoWithVideoURL:(NSURL *)videoURL
{
  FBSDKShareVideo *video = [FBSDKShareVideo new];
  video.videoURL = videoURL;
  return video;
}

+ (instancetype)videoWithVideoURL:(NSURL *)videoURL previewPhoto:(FBSDKSharePhoto *)previewPhoto
{
  FBSDKShareVideo *video = [FBSDKShareVideo new];
  video.videoURL = videoURL;
  video.previewPhoto = previewPhoto;
  return video;
}

#pragma mark - Properties

- (void)setData:(NSData *)data
{
  _data = data;
  _videoAsset = nil;
  _videoURL = nil;
  _previewPhoto = nil;
}

- (void)setVideoAsset:(PHAsset *)videoAsset
{
  _data = nil;
  _videoAsset = [videoAsset copy];
  _videoURL = nil;
  _previewPhoto = nil;
}

- (void)setVideoURL:(NSURL *)videoURL
{
  _data = nil;
  _videoAsset = nil;
  _videoURL = [videoURL copy];
  _previewPhoto = nil;
}

#pragma mark - FBSDKSharingValidation

- (BOOL)_validateData:(NSData *)data
          withOptions:(FBSDKShareBridgeOptions)bridgeOptions
                error:(NSError *__autoreleasing *)errorRef
{
  if (data) {
    if (bridgeOptions & FBSDKShareBridgeOptionsVideoData) {
      return YES; // will bridge the data
    }
  }
  if ((errorRef != NULL) && !*errorRef) {
    id<FBSDKErrorCreating> errorFactory = [FBSDKErrorFactory new];
    *errorRef = [errorFactory invalidArgumentErrorWithDomain:FBSDKShareErrorDomain
                                                        name:@"data"
                                                       value:data
                                                     message:@"Cannot share video data."
                                             underlyingError:nil];
  }
  return NO;
}

- (BOOL)_validateVideoAsset:(PHAsset *)videoAsset
                withOptions:(FBSDKShareBridgeOptions)bridgeOptions
                      error:(NSError *__autoreleasing *)errorRef
{
  if (videoAsset) {
    if (PHAssetMediaTypeVideo == videoAsset.mediaType) {
      if (bridgeOptions & FBSDKShareBridgeOptionsVideoAsset) {
        return YES; // will bridge the PHAsset.localIdentifier
      } else {
        return YES; // will bridge the legacy "assets-library" URL from AVAsset
      }
    } else {
      if (errorRef != NULL) {
        id<FBSDKErrorCreating> errorFactory = [FBSDKErrorFactory new];
        *errorRef = [errorFactory invalidArgumentErrorWithDomain:FBSDKShareErrorDomain
                                                            name:@"videoAsset"
                                                           value:videoAsset
                                                         message:@"Must refer to a video file."
                                                 underlyingError:nil];
      }
      return NO;
    }
  }
  return NO;
}

- (BOOL)_validateVideoURL:(NSURL *)videoURL
              withOptions:(FBSDKShareBridgeOptions)bridgeOptions
                    error:(NSError *__autoreleasing *)errorRef
{
  if (videoURL) {
    if ([videoURL.scheme.lowercaseString isEqualToString:@"assets-library"]) {
      return YES; // will bridge the legacy "assets-library" URL
    } else if (videoURL.isFileURL) {
      if (bridgeOptions & FBSDKShareBridgeOptionsVideoData) {
        return YES; // will load the contents of the file and bridge the data
      }
    }
  }
  if ((errorRef != NULL) && !*errorRef) {
    id<FBSDKErrorCreating> errorFactory = [FBSDKErrorFactory new];
    *errorRef = [errorFactory invalidArgumentErrorWithDomain:FBSDKShareErrorDomain
                                                        name:kFBSDKShareVideoURLKey
                                                       value:videoURL
                                                     message:@"Must refer to an asset file."
                                             underlyingError:nil];
  }
  return NO;
}

- (BOOL)validateWithOptions:(FBSDKShareBridgeOptions)bridgeOptions error:(NSError *__autoreleasing *)errorRef
{
  // validate that a valid asset, data, or videoURL value has been set.
  // don't validate the preview photo; if it isn't valid it'll be dropped from the share; a default one may be created if needed.
  if (_videoAsset) {
    return [self _validateVideoAsset:_videoAsset withOptions:bridgeOptions error:errorRef];
  } else if (_data) {
    return [self _validateData:_data withOptions:bridgeOptions error:errorRef];
  } else if (_videoURL) {
    return [self _validateVideoURL:_videoURL withOptions:bridgeOptions error:errorRef];
  } else {
    if ((errorRef != NULL) && !*errorRef) {
      id<FBSDKErrorCreating> errorFactory = [FBSDKErrorFactory new];
      *errorRef = [errorFactory invalidArgumentErrorWithDomain:FBSDKShareErrorDomain
                                                          name:@"video"
                                                         value:self
                                                       message:@"Must have an asset, data, or videoURL value."
                                               underlyingError:nil];
    }
    return NO;
  }
}

@end

@implementation PHAsset (FBSDKShareVideo)

- (NSURL *)videoURL
{
  __block NSURL *videoURL = nil;
  // obtain the legacy "assets-library" URL from AVAsset
  dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
  PHVideoRequestOptions *const options = [PHVideoRequestOptions new];
  options.version = PHVideoRequestOptionsVersionCurrent;
  options.deliveryMode = PHVideoRequestOptionsDeliveryModeAutomatic;
  options.networkAccessAllowed = YES;
  [[PHImageManager defaultManager] requestAVAssetForVideo:self
                                                  options:options
                                            resultHandler:^(AVAsset *avAsset, AVAudioMix *audioMix, NSDictionary<NSString *, id> *info) {
                                              NSURL *const filePathURL = ((AVURLAsset *)avAsset).URL.filePathURL;
                                              NSString *const pathExtension = filePathURL.pathExtension;
                                              NSString *const localIdentifier = self.localIdentifier;
                                              const NSRange range = [localIdentifier rangeOfString:@"/"];
                                              NSString *const uuid = [localIdentifier substringToIndex:range.location];
                                              NSString *const assetPath = [NSString stringWithFormat:@"assets-library://asset/asset.%@?id=%@&ext=%@",
                                                                           pathExtension,
                                                                           uuid,
                                                                           pathExtension];
                                              videoURL = [NSURL URLWithString:assetPath];
                                              dispatch_semaphore_signal(semaphore);
                                            }];
#ifndef __clang_analyzer__
  dispatch_semaphore_wait(semaphore, dispatch_time(DISPATCH_TIME_NOW, 500 * NSEC_PER_MSEC));
#endif // not __clang_analyzer__
  return videoURL;
}

@end

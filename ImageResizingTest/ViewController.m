//
//  ViewController.m
//  ImageResizingTest
//
//  Created by Howie C on 8/19/17.
//  Copyright © 2017 Howie C. All rights reserved.
//

#import "ViewController.h"
#import <ImageIO/ImageIO.h>
#import <Photos/Photos.h>
#import <MobileCoreServices/MobileCoreServices.h>

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


- (IBAction)pickAnImage:(UIButton *)sender {
    UIImagePickerController *imagePicker = [[UIImagePickerController alloc] init];
    imagePicker.delegate = self;
    imagePicker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
    imagePicker.allowsEditing = NO;
    [self presentViewController:imagePicker animated:NO completion:nil];
}


- (void)resizeByImageIOWithInfo:(NSDictionary *)info {
    NSURL *assetURL = info[UIImagePickerControllerReferenceURL];
    PHFetchResult *fetchResult = [PHAsset fetchAssetsWithALAssetURLs:@[assetURL] options:nil];
    PHAsset *asset = [fetchResult firstObject];
    if (!asset) {
        fprintf(stderr, "Failed to create asset.\n");
        return;
    }
    PHImageManager *imageManager = [PHImageManager defaultManager];
    PHImageRequestOptions *options = [[PHImageRequestOptions alloc] init];
    options.synchronous = YES; // making it easier to observe the result
    [imageManager requestImageDataForAsset:asset options:options resultHandler:^(NSData * _Nullable imageData, NSString * _Nullable dataUTI, UIImageOrientation orientation, NSDictionary * _Nullable info) {
        // Create an image source from NSData; no options.
        CGImageSourceRef imageSource = CGImageSourceCreateWithData((CFDataRef)imageData, NULL);
        if (imageSource == NULL) {
            fprintf(stderr, "Image source is NULL.\n");
            return;
        }
        CFStringRef thumbnailOptionKeys[3];
        CFTypeRef thumbnailOptionValues[3]; // same as (const void **)
        unsigned long maxPixelSize = [self maxPixelSize:imageSource];
        // fprintf(stderr, "max pixel size: %lu\n", maxPixelSize);
        CFNumberRef maxThumbnailPixelSize= CFNumberCreate(NULL, kCFNumberIntType, &maxPixelSize);
        thumbnailOptionKeys[0] = kCGImageSourceCreateThumbnailWithTransform;
        thumbnailOptionValues[0] = kCFBooleanTrue;
        thumbnailOptionKeys[1] = kCGImageSourceCreateThumbnailFromImageAlways;
        thumbnailOptionValues[1] = kCFBooleanTrue;
        thumbnailOptionKeys[2] = kCGImageSourceThumbnailMaxPixelSize;
        thumbnailOptionValues[2] = maxThumbnailPixelSize;
        CFDictionaryRef thumbnailImageOptions = CFDictionaryCreate(NULL, (const void **)thumbnailOptionKeys, thumbnailOptionValues, 3, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
        CFRelease(maxThumbnailPixelSize);
        CGImageRef thumbnailImage = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, thumbnailImageOptions);
        // NSLog(@"width: %zu, height: %zu", CGImageGetWidth(thumbnailImage), CGImageGetHeight(thumbnailImage));
        CFRelease(imageSource);
        CFRelease(thumbnailImageOptions);
        // Make sure the thumbnail image exists before continuing.
        if (thumbnailImage == NULL){
            fprintf(stderr, "Thumbnail image not created from image source.\n");
            return;
        }
//        UIImage *resultImage = [[UIImage alloc] initWithCGImage:thumbnailImage];
        CFRelease(thumbnailImage);
//        _imageView.image = resultImage;
    }];
}

- (unsigned long)maxPixelSize:(CGImageSourceRef)imageSource {
    // specifying the cache strategy does not seem to affect the memory usage
//    CFStringRef keys[1];
//    CFTypeRef values[1];
    CFDictionaryRef options = NULL;
//    keys[0] = kCGImageSourceShouldCache;
//    values[0] = kCFBooleanFalse;
//    options = CFDictionaryCreate(NULL, (const void **)keys, values, 1, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
    CFDictionaryRef imageProperties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, options);
//    CFRelease(options);
    if (!imageProperties) {
        fprintf(stderr, "Could not get image source properties\n");
        return 0;
    }
    CFNumberRef width = CFDictionaryGetValue(imageProperties, kCGImagePropertyPixelWidth);
    CFNumberRef height = CFDictionaryGetValue(imageProperties, kCGImagePropertyPixelHeight);
    CFRelease(imageProperties);
    if (!width || !height) {
        fprintf(stderr, "Could not get image width or height from image properties\n");
        return 0;
    }
    float actualWidth = 0.0;
    float actualHeight = 0.0;
    CFNumberGetValue(width, kCFNumberFloatType, &actualWidth);
    CFNumberGetValue(height, kCFNumberFloatType, &actualHeight);
    float maxLongSide = 3840.0;
    float maxShortSide = 2160.0;
    float actualRatio = actualWidth / actualHeight;
    float maxRatio = 0.0;
    if (actualWidth >= actualHeight) {
        maxRatio = maxLongSide / maxShortSide;
    } else {
        maxRatio = maxShortSide / maxLongSide;
    }
    if (actualWidth > actualHeight) {
        if (actualWidth > maxLongSide || actualHeight > maxShortSide) {
            if (actualRatio < maxRatio) {
                return actualWidth * (maxShortSide / actualHeight);
            } else {
                return maxLongSide;
            }
        } else {
            return maxLongSide;
        }
    } else if (actualWidth < actualHeight) {
        if (actualWidth > maxShortSide || actualHeight > maxLongSide) {
            if (actualRatio > maxRatio) {
                return actualHeight * (maxShortSide / actualWidth);
            } else {
                return maxLongSide;
            }
        } else {
            return maxLongSide;
        }
    } else {
        return maxShortSide;
    }
}


- (void)resizeByPhotosWithInfo:(NSDictionary *)info {
    NSURL *assetURL = info[UIImagePickerControllerReferenceURL];
    PHFetchResult *fetchResult = [PHAsset fetchAssetsWithALAssetURLs:@[assetURL] options:nil];
    PHAsset *asset = [fetchResult firstObject];
    if (!asset) {
        fprintf(stderr, "Failed to create asset.\n");
        return;
    }
    PHImageManager *imageManager = [PHImageManager defaultManager];
    PHImageRequestOptions *options = [[PHImageRequestOptions alloc] init];
    options.resizeMode = PHImageRequestOptionsResizeModeExact;
    options.deliveryMode = PHImageRequestOptionsDeliveryModeHighQualityFormat;
    options.synchronous = YES; // making it easier to observe the result
    CGSize targetSize = {0};
    if (asset.pixelWidth >= asset.pixelHeight) {
        targetSize = CGSizeMake(3840, 2160);
    } else {
        targetSize = CGSizeMake(2160, 3840);
    }
    [imageManager requestImageForAsset:asset targetSize:targetSize contentMode:PHImageContentModeAspectFit options:options resultHandler:^(UIImage * _Nullable result, NSDictionary * _Nullable info) {
        // NSLog(@"width: %f, height: %f", result.size.width, result.size.height);
//        _imageView.image = result;
    }];
}


- (NSURL *)urlForDocumentDirectoryOfFile:(NSString *)file {
    NSURL *documentDirectoryURL = [[NSFileManager defaultManager] URLForDirectory:NSDocumentDirectory inDomain:NSUserDomainMask appropriateForURL:nil create:YES error:nil];
    if (!documentDirectoryURL) {
        return nil;
    }
    NSURL *fileURL = [documentDirectoryURL URLByAppendingPathComponent:file];
    return fileURL;
}


- (void)compressByImageIOWithImage:(UIImage *)image {
    NSURL *imageURL = [self urlForDocumentDirectoryOfFile:@"tmp.jpg"];
    CGImageDestinationRef imageDestination = CGImageDestinationCreateWithURL((CFURLRef)imageURL, kUTTypeJPEG, 1, NULL);
    if (imageDestination == NULL) {
        fprintf(stderr, "Fail to create image destination.\n");
        return;
    }
    float level = 0.8; // compression level
    CFNumberRef compressionLevel = CFNumberCreate(NULL, kCFNumberFloatType, &level);
    CFStringRef keys[1];
    CFTypeRef values[1];
    CFDictionaryRef properties = NULL;
    keys[0] = kCGImageDestinationLossyCompressionQuality;
    values[0] = compressionLevel;
    properties = CFDictionaryCreate(NULL, (const void **)keys, values, 1, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
    CFRelease(compressionLevel);
    CGImageDestinationAddImage(imageDestination, image.CGImage, properties);
    CFRelease(properties);
    BOOL result = CGImageDestinationFinalize(imageDestination);
    CFRelease(imageDestination);
    if (!result) {
        fprintf(stderr, "Failed to save image.\n");
    }
}


- (void)compressByUIKitWithImage:(UIImage *)image {
    NSURL *imageURL = [self urlForDocumentDirectoryOfFile:@"tmp.jpg"];
    float compressionLevel = 0.8; // compression level
    NSData *data = UIImageJPEGRepresentation(image, compressionLevel);
    BOOL result = [data writeToURL:imageURL options:NSDataWritingAtomic error:nil];
    if (!result) {
        fprintf(stderr, "Failed to save image.\n");
    }
}


- (void)resizeImageByPhotosAndCompressImageByImageIOWithInfo:(NSDictionary *)info {
    NSURL *assetURL = info[UIImagePickerControllerReferenceURL];
    PHFetchResult *fetchResult = [PHAsset fetchAssetsWithALAssetURLs:@[assetURL] options:nil];
    PHAsset *asset = [fetchResult firstObject];
    if (!asset) {
        fprintf(stderr, "Failed to create asset.\n");
        return;
    }
    PHImageManager *imageManager = [PHImageManager defaultManager];
    PHImageRequestOptions *options = [[PHImageRequestOptions alloc] init];
    options.resizeMode = PHImageRequestOptionsResizeModeExact;
    options.deliveryMode = PHImageRequestOptionsDeliveryModeHighQualityFormat;
    options.synchronous = YES; // making it easier to observe the result
    CGSize targetSize = {0};
    if (asset.pixelWidth >= asset.pixelHeight) {
        targetSize = CGSizeMake(3840, 2160);
    } else {
        targetSize = CGSizeMake(2160, 3840);
    }
    [imageManager requestImageForAsset:asset targetSize:targetSize contentMode:PHImageContentModeAspectFit options:options resultHandler:^(UIImage * _Nullable result, NSDictionary * _Nullable info) {
        NSURL *imageURL = [self urlForDocumentDirectoryOfFile:@"tmp.jpg"];
        CGImageDestinationRef imageDestination = CGImageDestinationCreateWithURL((CFURLRef)imageURL, kUTTypeJPEG, 1, NULL);
        if (imageDestination == NULL) {
            fprintf(stderr, "Fail to create image destination.\n");
            return;
        }
        float level = 0.8; // compression level
        CFNumberRef compressionLevel = CFNumberCreate(NULL, kCFNumberFloatType, &level);
        CFStringRef keys[1];
        CFTypeRef values[1];
        CFDictionaryRef properties = NULL;
        keys[0] = kCGImageDestinationLossyCompressionQuality;
        values[0] = compressionLevel;
        properties = CFDictionaryCreate(NULL, (const void **)keys, values, 1, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
        CFRelease(compressionLevel);
        CGImageDestinationAddImage(imageDestination, result.CGImage, properties);
        CFRelease(properties);
        BOOL rslt = CGImageDestinationFinalize(imageDestination);
        CFRelease(imageDestination);
        if (!rslt) {
            fprintf(stderr, "Failed to save image.\n");
        }
    }];
}


- (void)resizeAndCompressImageDataByImageIOWithInfo:(NSDictionary *)info {
    NSURL *assetURL = info[UIImagePickerControllerReferenceURL];
    PHFetchResult *fetchResult = [PHAsset fetchAssetsWithALAssetURLs:@[assetURL] options:nil];
    PHAsset *asset = [fetchResult firstObject];
    if (!asset) {
        fprintf(stderr, "Failed to create asset.\n");
        return;
    }
    PHImageManager *imageManager = [PHImageManager defaultManager];
    PHImageRequestOptions *options = [[PHImageRequestOptions alloc] init];
    options.synchronous = YES; // making it easier to observe the result
    [imageManager requestImageDataForAsset:asset options:options resultHandler:^(NSData * _Nullable imageData, NSString * _Nullable dataUTI, UIImageOrientation orientation, NSDictionary * _Nullable info) {
        // write data
        BOOL result = NO;
        NSURL *imageURL = [self urlForDocumentDirectoryOfFile:@"tmp.jpg"];
        result = [imageData writeToURL:imageURL options:NSDataWritingAtomic error:nil];
        if (!result) {
            fprintf(stderr, "Failed to save image data.\n");
        }
        // read file
        CGImageSourceRef imageSource = NULL;
        imageSource = CGImageSourceCreateWithURL((CFURLRef)imageURL, NULL);
        if (imageSource == NULL) {
            fprintf(stderr, "Image Source is NULL.\n");
            return;
        }
        CGImageDestinationRef imageDestination = CGImageDestinationCreateWithURL((CFURLRef)imageURL, kUTTypeJPEG, 1, NULL);
        if (imageDestination == NULL) {
            fprintf(stderr, "Fail to create image destination.\n");
            return;
        }
        // resize
        CFStringRef thumbnailOptionKeys[3];
        CFTypeRef thumbnailOptionValues[3]; // same as (const void **)
        unsigned long maxPixelSize = [self maxPixelSize:imageSource];
        // fprintf(stderr, "max pixel size: %lu\n", maxPixelSize);
        CFNumberRef maxThumbnailPixelSize= CFNumberCreate(NULL, kCFNumberIntType, &maxPixelSize);
        thumbnailOptionKeys[0] = kCGImageSourceCreateThumbnailWithTransform;
        thumbnailOptionValues[0] = kCFBooleanTrue;
        thumbnailOptionKeys[1] = kCGImageSourceCreateThumbnailFromImageAlways;
        thumbnailOptionValues[1] = kCFBooleanTrue;
        thumbnailOptionKeys[2] = kCGImageSourceThumbnailMaxPixelSize;
        thumbnailOptionValues[2] = maxThumbnailPixelSize;
        CFDictionaryRef thumbnailImageOptions = CFDictionaryCreate(NULL, (const void **)thumbnailOptionKeys, thumbnailOptionValues, 3, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
        CFRelease(maxThumbnailPixelSize);
        CGImageRef thumbnailImage = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, thumbnailImageOptions);
        // NSLog(@"width: %zu, height: %zu", CGImageGetWidth(thumbnailImage), CGImageGetHeight(thumbnailImage));
        CFRelease(imageSource);
        CFRelease(thumbnailImageOptions);
        // Make sure the thumbnail image exists before continuing.
        if (thumbnailImage == NULL){
            fprintf(stderr, "Thumbnail image not created from image source.\n");
            return;
        }
        // compress
        float level = 0.8; // compression level
        CFNumberRef compressionLevel = CFNumberCreate(NULL, kCFNumberFloatType, &level);
        CFStringRef keys[1];
        CFTypeRef values[1];
        CFDictionaryRef properties = NULL;
        keys[0] = kCGImageDestinationLossyCompressionQuality;
        values[0] = compressionLevel;
        properties = CFDictionaryCreate(NULL, (const void **)keys, values, 1, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
        CFRelease(compressionLevel);
        CGImageDestinationAddImage(imageDestination, thumbnailImage, properties);
        CFRelease(thumbnailImage);
        CFRelease(properties);
        result = CGImageDestinationFinalize(imageDestination);
        CFRelease(imageDestination);
        if (!result) {
            fprintf(stderr, "Failed to save image.\n");
        }
    }];
}


- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary<NSString *,id> *)info {
    float start = 0;
    float end = 0;
    start = CACurrentMediaTime();
    [self resizeAndCompressImageDataByImageIOWithInfo:info];
    end = CACurrentMediaTime();
    NSLog(@"time by ImageIO: %f\n", end - start);
    [NSThread sleepForTimeInterval:8.0];
    start = CACurrentMediaTime();
    [self resizeImageByPhotosAndCompressImageByImageIOWithInfo:info];
    end = CACurrentMediaTime();
    NSLog(@"resize time by Photos and compressed by ImageIO: %f\n", end - start);
    
//    start = CACurrentMediaTime();
//    for (int i = 0; i < 50; i++) {
//        [self compressByImageIOWithImage:info[UIImagePickerControllerOriginalImage]];
//    }
//    end = CACurrentMediaTime();
//    NSLog(@"compression time by ImageIO: %f\n", end - start);
//    sleep(5);
//    start = CACurrentMediaTime();
//    for (int i = 0; i < 50; i++) {
//        [self compressByUIKitWithImage:info[UIImagePickerControllerOriginalImage]];
//    }
//    end = CACurrentMediaTime();
//    NSLog(@"compression time by UIKit: %f\n", end - start);
    [self dismissViewControllerAnimated:NO completion:nil];
}


- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker {
    [self dismissViewControllerAnimated:NO completion:nil];
}


@end

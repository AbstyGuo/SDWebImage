/*
 * This file is part of the SDWebImage package.
 * (c) Olivier Poitrey <rs@dailymotion.com>
 *
 * For the full copyright and license information, please view the LICENSE
 * file that was distributed with this source code.
 */

#import "SDWebImageCodersManager.h"
#import "SDWebImageImageIOCoder.h"
#import "SDWebImageGIFCoder.h"
#import "SDWebImageAPNGCoder.h"
#ifdef SD_WEBP
#import "SDWebImageWebPCoder.h"
#endif
#import "NSImage+Compatibility.h"
#import "UIImage+WebCache.h"
#import "SDWebImageDefine.h"

#define LOCK(lock) dispatch_semaphore_wait(lock, DISPATCH_TIME_FOREVER);
#define UNLOCK(lock) dispatch_semaphore_signal(lock);

@interface SDWebImageCodersManager ()

@property (nonatomic, strong, nonnull) dispatch_semaphore_t codersLock;

@end

@implementation SDWebImageCodersManager

+ (nonnull instancetype)sharedManager {
    static dispatch_once_t once;
    static id instance;
    dispatch_once(&once, ^{
        instance = [self new];
    });
    return instance;
}

- (instancetype)init {
    if (self = [super init]) {
        // initialize with default coders
        NSMutableArray<id<SDImageCoder>> *mutableCoders = [@[[SDWebImageImageIOCoder sharedCoder], [SDWebImageGIFCoder sharedCoder], [SDWebImageAPNGCoder sharedCoder]] mutableCopy];
#ifdef SD_WEBP
        [mutableCoders addObject:[SDWebImageWebPCoder sharedCoder]];
#endif
        _coders = [mutableCoders copy];
        _codersLock = dispatch_semaphore_create(1);
    }
    return self;
}

#pragma mark - Coder IO operations

- (void)addCoder:(nonnull id<SDImageCoder>)coder {
    if (![coder conformsToProtocol:@protocol(SDImageCoder)]) {
        return;
    }
    LOCK(self.codersLock);
    NSMutableArray<id<SDImageCoder>> *mutableCoders = [self.coders mutableCopy];
    if (!mutableCoders) {
        mutableCoders = [NSMutableArray array];
    }
    [mutableCoders addObject:coder];
    self.coders = [mutableCoders copy];
    UNLOCK(self.codersLock);
}

- (void)removeCoder:(nonnull id<SDImageCoder>)coder {
    if (![coder conformsToProtocol:@protocol(SDImageCoder)]) {
        return;
    }
    LOCK(self.codersLock);
    NSMutableArray<id<SDImageCoder>> *mutableCoders = [self.coders mutableCopy];
    [mutableCoders removeObject:coder];
    self.coders = [mutableCoders copy];
    UNLOCK(self.codersLock);
}

#pragma mark - SDImageCoder
- (BOOL)canDecodeFromData:(NSData *)data {
    LOCK(self.codersLock);
    NSArray<id<SDImageCoder>> *coders = self.coders;
    UNLOCK(self.codersLock);
    for (id<SDImageCoder> coder in coders.reverseObjectEnumerator) {
        if ([coder canDecodeFromData:data]) {
            return YES;
        }
    }
    return NO;
}

- (BOOL)canEncodeToFormat:(SDImageFormat)format {
    LOCK(self.codersLock);
    NSArray<id<SDImageCoder>> *coders = self.coders;
    UNLOCK(self.codersLock);
    for (id<SDImageCoder> coder in coders.reverseObjectEnumerator) {
        if ([coder canEncodeToFormat:format]) {
            return YES;
        }
    }
    return NO;
}

- (UIImage *)decodedImageWithData:(NSData *)data options:(nullable SDImageCoderOptions *)options {
    if (!data) {
        return nil;
    }
    UIImage *image;
    LOCK(self.codersLock);
    NSArray<id<SDImageCoder>> *coders = self.coders;
    UNLOCK(self.codersLock);
    for (id<SDImageCoder> coder in coders.reverseObjectEnumerator) {
        if ([coder canDecodeFromData:data]) {
            image = [coder decodedImageWithData:data options:options];
            break;
        }
    }
    
    return image;
}

- (NSData *)encodedDataWithImage:(UIImage *)image format:(SDImageFormat)format options:(nullable SDImageCoderOptions *)options {
    if (!image) {
        return nil;
    }
    LOCK(self.codersLock);
    NSArray<id<SDImageCoder>> *coders = self.coders;
    UNLOCK(self.codersLock);
    for (id<SDImageCoder> coder in coders.reverseObjectEnumerator) {
        if ([coder canEncodeToFormat:format]) {
            return [coder encodedDataWithImage:image format:format options:nil];
        }
    }
    return nil;
}

@end

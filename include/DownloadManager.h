#pragma once
#import <Cocoa/Cocoa.h>
#import <WebKit/WebKit.h>

typedef NS_ENUM(NSInteger, DownloadState) {
    DownloadStateInProgress,
    DownloadStateComplete,
    DownloadStateFailed,
};

@interface DownloadItem : NSObject
@property (copy)   NSString*       filename;
@property (copy)   NSString*       destinationPath;
@property (assign) int64_t         bytesReceived;
@property (assign) int64_t         totalBytes;       // -1 if unknown
@property (assign) DownloadState   state;
@property (strong) WKDownload*     download;
@end

// Manages all in-progress and completed downloads for the session
@interface DownloadManager : NSObject <WKDownloadDelegate>
+ (instancetype)profileShared;
@property (readonly) NSArray<DownloadItem*>* items;
@property (copy) void (^onUpdate)(void);   // called on any state change
- (void)startDownload:(WKDownload*)dl;
@end

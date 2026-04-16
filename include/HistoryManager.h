#pragma once
#import <Foundation/Foundation.h>

@interface HistoryEntry : NSObject <NSSecureCoding>
@property (copy)   NSString* title;
@property (copy)   NSString* url;
@property (strong) NSDate*   visitDate;
- (instancetype)initWithTitle:(NSString*)title url:(NSString*)url;
@end

// Persists history to ~/Library/Application Support/KBrowser/history.plist
// Keeps the 2000 most recent entries; auto-deduplicates by URL per day.
@interface HistoryManager : NSObject
+ (instancetype)shared;
@property (readonly) NSArray<HistoryEntry*>* entries;  // newest first
- (void)recordVisitWithTitle:(NSString*)title url:(NSString*)url;
- (void)clearAll;
- (void)save;
@end

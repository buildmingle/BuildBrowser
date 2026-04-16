#pragma once
#import <Foundation/Foundation.h>

@interface Bookmark : NSObject <NSSecureCoding>
@property (copy) NSString* title;
@property (copy) NSString* url;
@property (strong) NSDate* dateAdded;
- (instancetype)initWithTitle:(NSString*)title url:(NSString*)url;
@end

// Persists bookmarks to ~/Library/Application Support/KBrowser/bookmarks.plist
@interface BookmarkManager : NSObject
+ (instancetype)shared;
@property (readonly) NSArray<Bookmark*>* bookmarks;
- (void)addBookmarkWithTitle:(NSString*)title url:(NSString*)url;
- (void)removeBookmarkAtIndex:(NSInteger)index;
- (BOOL)isBookmarked:(NSString*)url;
- (void)save;
@end

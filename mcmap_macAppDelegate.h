//
//  mcmap_macAppDelegate.h
//  mcmap-mac
//
//  Created by DK on 10/7/10.
//

#import <Cocoa/Cocoa.h>

#if (MAC_OS_X_VERSION_MAX_ALLOWED <= MAC_OS_X_VERSION_10_5)
@interface mcmap_macAppDelegate : NSObject {
#else
@interface mcmap_macAppDelegate : NSObject <NSApplicationDelegate> {
#endif

    
    NSWindow* window;
}

- (void)windowWillClose:(NSNotification *)aNotification;
- (void)applicationDidFinishLaunching:(NSNotification *)aNotification;
- (void)applicationWillTerminate:(NSNotification *)aNotification;
- (BOOL)fileManager:(NSFileManager *)fm shouldProceedAfterError:(NSError *)error copyingItemAtPath:(NSString *)srcPath toPath:(NSString *)dstPath;

@property (assign) IBOutlet NSWindow *window;

@end

//
//  mcmap_macAppDelegate.m
//  mcmap-mac
//
//  Created by DK on 10/7/10.
//

#import "mcmap_macAppDelegate.h"

@implementation mcmap_macAppDelegate

@synthesize window;

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    
    NSString* temp_dir = @"/tmp/mcmap/";
    NSFileManager* fm = [[[NSFileManager alloc] init] autorelease];
    [fm setDelegate: self];
    NSDirectoryEnumerator* en;    
    NSError* err = nil;
    NSString* file;
    BOOL res;
    
    // Make sure our scratch folder exists.
    [fm createDirectoryAtPath:temp_dir withIntermediateDirectories:YES attributes:nil error:nil];
    
    // Empty it in case renders from last time are hanging around.
    en = [fm enumeratorAtPath:temp_dir];
    err = nil;

    while (file = [en nextObject]) {
        res = [fm removeItemAtPath:[temp_dir stringByAppendingPathComponent:file] error:&err];
        if (!res && err) {
            NSLog(@"Cache moved: %@", err);
        }
    }
    
    // Check if the application has ever been run before
    BOOL isdir;
    [fm fileExistsAtPath:[@"~/Library/Application Support/MCMap Live" stringByExpandingTildeInPath] isDirectory:&isdir];
    if(!isdir)
    {
        NSLog(@"Creating Application Support Folder");
        [fm createDirectoryAtPath:[@"~/Library/Application Support/MCMap Live" stringByExpandingTildeInPath] withIntermediateDirectories:YES attributes:nil error:&err];
        if (err)
            NSLog(@"Error making Application Support folder: %@", err);
    }
    
    /*
    NSLog(@"Updating Application Support files...", err);
    [fm copyItemAtPath:[NSString stringWithFormat:@"%@/Colors",[ [ NSBundle mainBundle ] resourcePath ]] 
    toPath:[@"~/Library/Application Support/MCMap Live/Colors" stringByExpandingTildeInPath] 
    error:&err];
    if (err)
        NSLog(@"Error updating files: %@", err);
    else
        NSLog(@"Files updated!");
    */
}

- (BOOL)fileManager:(NSFileManager *)fm shouldProceedAfterError:(NSError *)error copyingItemAtPath:(NSString *)srcPath toPath:(NSString *)dstPath
{
    NSLog(@"Failed to copy: %@ Continuing...",srcPath);
    return YES;
}

- (void)windowWillClose:(NSNotification *)aNotification {
[NSApp terminate:self];
}

- (void)applicationWillTerminate:(NSNotification *)aNotification {
	// Ditch the ramdisk before quitting
    //system("diskutil eject /Volumes/mcmap_scratch");
    
    NSLog(@"Deleting Cache...");
    NSString* temp_dir = @"/tmp/mcmap/";
    
    // Empty the cache!
    NSFileManager* fm = [[[NSFileManager alloc] init] autorelease];
    NSDirectoryEnumerator* en = [fm enumeratorAtPath:temp_dir];    
    NSError* err = nil;
    BOOL res;
    NSString* file;

    while (file = [en nextObject]) {
        res = [fm removeItemAtPath:[temp_dir stringByAppendingPathComponent:file] error:&err];
        if (!res && err) {
            NSLog(@"oops: %@", err);
        }
    }
}

@end

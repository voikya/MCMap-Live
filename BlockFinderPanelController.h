//
//  BlockFinderPanelController.h
//  MCMap Live
//
//  Created by DK on 10/23/10.
//

#import <Cocoa/Cocoa.h>
#import "MCMapOpenGLView.h"

@interface BlockFinderPanelController : NSWindowController {
    
    IBOutlet NSPopUpButton * blockSelector;
    IBOutlet NSMenu * blockFinderMenu;
    IBOutlet NSMenuItem * selectNoneMenuItem;
    IBOutlet MCMapOpenGLView * mapview;
    IBOutlet NSColorWell * finderColor;
    IBOutlet NSButton * xraySet;
    IBOutlet NSSlider * xraySlider;
}

- (IBAction)selectBlock:(id)sender;
- (IBAction)startBlockFinder:(id)sender;
- (void) awakeFromNib;
- (void) windowWillClose:(NSNotification *)notification;
- (void) windowDidBecomeKey:(NSNotification *)notification; 

@end
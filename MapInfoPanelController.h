//
//  MapInfoPanelController.h
//  MCMap Live
//
//  Created by DK on 11/12/10.
//

#import <Cocoa/Cocoa.h>

@interface MapInfoPanelController : NSWindowController {
    
    IBOutlet NSPopUpButton * blockSelector;
    IBOutlet NSMenu * blockFinderMenu;
    IBOutlet NSMenuItem * selectNoneMenuItem;
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
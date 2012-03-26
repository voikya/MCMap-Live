//
//  MCMapPrefsController.h
//  MCMap Live
//
//  Created by DK on 10/24/10.
//

#import <Cocoa/Cocoa.h>
#import "MCMapOpenGLView.h"

@interface MCMapPrefsController : NSWindowController {
    
    IBOutlet MCMapOpenGLView * mapview;
    IBOutlet NSTableView * colorsTable;
    IBOutlet NSTextField * numberOfRenderers;
    IBOutlet NSStepper * numberOfRenderersStepper;
}

- (IBAction)setRenderSettings:(id)sender;
- (IBAction)defaultRenderSettings:(id)sender;
- (IBAction)setMaxRenderers:(id)sender;
- (IBAction)showColorsInFinder:(id)sender;
- (void) awakeFromNib;
- (void) populateColorsList;
- (IBAction) addColor:(id)sender;
- (IBAction) removeColor:(id)sender;
- (void) windowWillClose:(NSNotification *)notification;
- (void) windowDidBecomeKey:(NSNotification *)notification; 

// These are so it can act as a data source
- (id)tableView:(NSTableView *)aTableView
    objectValueForTableColumn:(NSTableColumn *)aTableColumn
    row:(NSInteger)rowIndex;
- (void)tableView:(NSTableView *)aTableView
    setObjectValue:anObject
    forTableColumn:(NSTableColumn *)aTableColumn
    row:(NSInteger)rowIndex;
- (NSInteger)numberOfRowsInTableView:(NSTableView *)aTableView;

@end
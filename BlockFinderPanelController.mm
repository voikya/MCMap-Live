//
//  BlockFinderPanelController.m
//  MCMap Live
//
//  Created by DK on 10/23/10.
//

#import "BlockFinderPanelController.h"

NSDictionary* minecraft_blocks;
BOOL color_stored = NO;

@implementation BlockFinderPanelController

- (IBAction)selectBlock:(id)sender
{
    if(sender == selectNoneMenuItem)
    {
        NSArray* menuitems = [blockFinderMenu itemArray];
        for (NSMenuItem* item in menuitems)
            [item setState:NSOffState];
    }
    else 
    {
        //NSLog(@"Got event to change state of %@",[sender title]);
        if ([sender state]==NSOnState)
            [sender setState: NSOffState];
        else
            [sender setState: NSOnState];
    }
    //[blockFinderMenu update];

}

- (IBAction)startBlockFinder:(id)sender
{
    NSArray* menuitems = [blockFinderMenu itemArray];
    NSMutableArray* blocks = [[NSMutableArray alloc] init];
    
    for (NSMenuItem* item in menuitems)
    {
        if ([item state]== NSOnState)
        {
            NSNumber* blockid = [minecraft_blocks objectForKey:[item title]];
            if (blockid != Nil)
            {
                [blocks addObject: [blockid copy]];
                //NSLog(@"Block %@ added to blocks",[item title]);
            }
        }
    }
    
    double xray = [xraySlider doubleValue];
    //NSLog(@"Ready to fire setup message.");
    [mapview startBlockFinder:blocks inColor:[finderColor color] xray:xray];
    //NSLog(@"Set up Block Finder color set.");
    [blocks release];
}

- (void)awakeFromNib
{
    // Load up the dictionary of minecraft block names and IDs
    minecraft_blocks = [[NSDictionary dictionaryWithContentsOfFile:[ NSString stringWithFormat:@"%@/tiles.plist",[ [ NSBundle mainBundle ] resourcePath ]]] retain] ;
    // Populate the Blockfinder Menu
    
    [blockSelector setAutoenablesItems:NO];
    for (NSString* tilename in [minecraft_blocks keysSortedByValueUsingSelector:@selector(compare:)]) 
    {
        NSMenuItem* tileitem = [[NSMenuItem alloc] initWithTitle:tilename action:@selector(selectBlock:) keyEquivalent:@""]; 
        [blockFinderMenu addItem:tileitem];
    }
    [blockSelector setMenu:blockFinderMenu];
}

- (void)windowWillClose:(NSNotification *)notification 
{
    [mapview restoreColor];
    color_stored = NO;
}

- (void)windowDidBecomeKey:(NSNotification *)notification 
{
    if (!color_stored)
    {
        [mapview storeColor];
        color_stored = YES;
    }
}



@end

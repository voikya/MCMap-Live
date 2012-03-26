//
//  BlockFinderPanelController.m
//  MCMap Live
//
//  Created by DK on 10/23/10.
//

#import "MCMapPrefsController.h"

NSMutableArray* user_colors;

@implementation MCMapPrefsController

- (IBAction)setRenderSettings:(id)sender
{
    [mapview setRenderDefaults];
}

- (IBAction)defaultRenderSettings:(id)sender
{
    [mapview resetRenderDefaults];
}

- (IBAction)setMaxRenderers:(id)sender
{
    [numberOfRenderers setTitleWithMnemonic:[NSString stringWithFormat:@"&%i",[sender integerValue]]];
    [mapview setMaxSimultaneousRenders:[sender integerValue]];
}

- (IBAction)showColorsInFinder:(id)sender
{
    [[NSWorkspace sharedWorkspace] openFile:[@"~/Library/Application Support/MCMap Live/" stringByExpandingTildeInPath] withApplication:@"Finder"];
}

- (void) populateColorsList
{
    [user_colors removeAllObjects];
    // Fill the colors listbox.
    NSFileManager* fm = [[[NSFileManager alloc] init] autorelease];
    NSDirectoryEnumerator* en = [fm enumeratorAtPath:[@"~/Library/Application Support/MCMap Live/" stringByExpandingTildeInPath]];    
    NSError* err = nil;
    NSString* file;
    while (file = [en nextObject]) {
        if([file hasSuffix:@".txt"])
        {
            [user_colors addObject:[[file substringToIndex:[file length] - 4]copy] ];
        }
        
        if (err) {
            NSLog(@"Color set moved: %@", err);
        }
    }
    [colorsTable reloadData];
}

- (IBAction) addColor:(id)sender
{
    
    NSString* savepath = [@"~/Library/Application Support/MCMap Live/New Color Set.txt" stringByExpandingTildeInPath];
    
    int i = 0;
    while([[NSFileManager defaultManager] fileExistsAtPath: savepath])
    {
        i++;
        savepath = [NSString stringWithFormat:[@"~/Library/Application Support/MCMap Live/New Color Set %i.txt" stringByExpandingTildeInPath],i];
    }
    
    NSOpenPanel *panel = [NSOpenPanel openPanel];
    [panel setCanChooseFiles:YES];
    [panel setAllowedFileTypes:[NSArray arrayWithObjects:@"txt",@"png",nil]];
    [panel setCanChooseDirectories:NO];
    [panel setResolvesAliases:YES];
    [panel setAllowsMultipleSelection:NO];
    [panel setPrompt:@"Add Color Set"];

    if ([panel runModal] == NSOKButton)
    {
        if ([[panel filename] hasSuffix: @".txt"])
        {
            // Copy the file
            [[NSFileManager defaultManager] copyItemAtPath:[panel filename] toPath:savepath error:nil];
        }
        else if ([[panel filename] hasSuffix: @".png"])
        {
            MinecraftColors colors;
            if([mapview createColorArrayFromPng:[panel filename] colorArray:&colors])
            {
                [mapview writeColorsFromArray:&colors savePath:savepath];
            }
        }
    }
    
    [self populateColorsList];
    [mapview rescanColorsMenu];
    
}

- (IBAction) removeColor:(id)sender
{
    NSInteger rowIndex = [colorsTable selectedRow];
    if (rowIndex >= 0 && rowIndex < [user_colors count])
    {
        NSString* srcpath = [NSString stringWithFormat:[@"~/Library/Application Support/MCMap Live/%@.txt" stringByExpandingTildeInPath],
                                    [user_colors objectAtIndex:rowIndex]];
        
        NSError* err = nil;
        [[NSFileManager defaultManager] removeItemAtPath:srcpath error:&err];
        if(!err)
            [user_colors removeObjectAtIndex:rowIndex];
        else
            NSLog(@"Couldn't remove texture pack: %@",err);
    
        [colorsTable reloadData];
    }
    [mapview rescanColorsMenu];
}

// DATA SOURCE METHODS FOR THE TABLE

- (id)tableView:(NSTableView *)aTableView
    objectValueForTableColumn:(NSTableColumn *)aTableColumn
    row:(NSInteger)rowIndex
{
    if (rowIndex >= 0 && rowIndex < [user_colors count])
        return [user_colors objectAtIndex:rowIndex];
    else
        return @"";
}

- (void)tableView:(NSTableView *)aTableView
    setObjectValue:anObject
    forTableColumn:(NSTableColumn *)aTableColumn
    row:(NSInteger)rowIndex
{
    NSParameterAssert(rowIndex >= 0 && rowIndex < [user_colors count]);
    
    NSString* srcpath = [NSString stringWithFormat:[@"~/Library/Application Support/MCMap Live/%@.txt" stringByExpandingTildeInPath],
                                [user_colors objectAtIndex:rowIndex]];
    
    NSString* dstpath = [NSString stringWithFormat:[@"~/Library/Application Support/MCMap Live/%@.txt" stringByExpandingTildeInPath],
                                anObject];
    
    // NSLog(@"%@ -> %@",srcpath,dstpath);
    // This effectively renames the color set
    
    NSError* err = nil;
    [[NSFileManager defaultManager] moveItemAtPath:srcpath toPath:dstpath error:&err];
    if(!err)
        [user_colors replaceObjectAtIndex:rowIndex withObject:anObject];
    else
        NSLog(@"Couldn't rename texture pack: %@",err);
    
    [mapview rescanColorsMenu];
    
    return;
    
    
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)aTableView
{
    return [user_colors count];
}

// END DATA SOURCE METHODS


- (void)awakeFromNib
{
    user_colors = [[NSMutableArray alloc] init];
    [self populateColorsList];
    
    NSUserDefaults *defaults;
    defaults = [NSUserDefaults standardUserDefaults];
    if ([defaults integerForKey:@"maxRenders"] == 0)
        [numberOfRenderersStepper setIntegerValue:4];
    else
        [numberOfRenderersStepper setIntegerValue:[defaults integerForKey:@"maxRenders"]];
        
    [self setMaxRenderers:numberOfRenderersStepper];
    
}

- (void)windowWillClose:(NSNotification *)notification 
{

}

- (void)windowDidBecomeKey:(NSNotification *)notification 
{
    [self populateColorsList];
}

@end

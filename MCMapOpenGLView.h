/*
 *  MCMapOpenGLView.h
 *  MCMap Live
 *
 *  Created by DK on 10/13/10.
 *
 */

#define MINECRAFT_TILE_COUNT 256

#import <OpenGL/gl.h>
#import <OpenGL/glext.h>
#import <OpenGL/glu.h>
#import <ApplicationServices/ApplicationServices.h>
#import <list>
#import <set>

typedef struct {
   GLdouble x,y,z;
} recVec;

typedef struct { int c[MINECRAFT_TILE_COUNT][5]; } MinecraftColors;

typedef struct {
	recVec viewPos; // View position
	GLint viewWidth, viewHeight; // current window/screen height and width
} recCamera;

@interface MCMapOpenGLView : NSOpenGLView
{
	// string attributes
	NSMutableDictionary * stanStringAttrib;
	
	NSTimer* timer;
 
    bool fAnimate;
	IBOutlet NSMenuItem * animateMenuItem;
    bool fInfo;
	IBOutlet NSMenuItem * infoMenuItem;
    
    // Controls
    IBOutlet NSMenuItem * resetViewMenuItem;
    
    // Info
    IBOutlet NSTextField * statusTextField;
    
    // Render Options
    IBOutlet NSMenuItem * netherMenuItem;
    IBOutlet NSMenuItem * endMenuItem;
    IBOutlet NSMenuItem * showplayersMenuItem;
    
    // Colors
    IBOutlet NSMenu * colorsMenu;
    IBOutlet NSMenuItem * defaultcolorsMenuItem;
    IBOutlet NSMenuItem * customcolorsMenuItem;
    
    // Lighting Mode Menu Items
    IBOutlet NSMenuItem * uniformMenuItem;
    IBOutlet NSMenuItem * dayMenuItem;
    IBOutlet NSMenuItem * torchlightMenuItem;
    IBOutlet NSMenuItem * nightMenuItem;
    IBOutlet NSMenuItem * caveMenuItem;
    
    // Noise Menu Items
    IBOutlet NSMenuItem * noise0menuItem;
    IBOutlet NSMenuItem * noise5menuItem;
    IBOutlet NSMenuItem * noise10menuItem;
    IBOutlet NSMenuItem * noise15menuItem;
    IBOutlet NSMenuItem * noise20menuItem;
    
    // Depth Slider
    IBOutlet NSSlider * depthSlider;
    IBOutlet NSTextField * depthIndicator;
    
    // Singleplayer World openers
    IBOutlet NSMenu * worldsMenu;
    
    // Orientations
    IBOutlet NSMenuItem * seUpMenuItem;
    IBOutlet NSMenuItem * swUpMenuItem;
    IBOutlet NSMenuItem * nwUpMenuItem;
    IBOutlet NSMenuItem * neUpMenuItem;
    
    // Save menu items
    IBOutlet NSMenuItem * saveChunkMenuItem;
    IBOutlet NSMenuItem * saveWorldMenuItem;
    IBOutlet NSView * imageFormat;
    IBOutlet NSPopUpButton * imageFormatPopup;
    
    // Biome Menu
    IBOutlet NSMenuItem * showBiomesMenuItem;
    IBOutlet NSMenuItem * deleteBiomeDataMenuItem;
    
    // Tools
    IBOutlet NSPanel * blockFinderPanel;
    IBOutlet NSPopUpButton* blockFinderPopButton;
    IBOutlet NSMenu * blockFinderPopup;

    bool show_players;
	
	CFAbsoluteTime time;
	
	// camera handling
	recCamera camera;
}

+ (NSOpenGLPixelFormat*) basicPixelFormat;

// File Menu
- (IBAction) openWorldFolder: (id) sender;
- (IBAction) openWorld: (id) sender;
- (IBAction) saveWorld: (id) sender;
- (IBAction) saveChunk: (id) sender;
- (IBAction) changeSaveFormat: (id) sender;
- (void) rescanWorldsMenu;

// Options Menu
-(IBAction) setDimensionToNether: (id) sender;
-(IBAction) setDimensionToEnd: (id) sender;
-(void) resetLightingModeMenu;
-(IBAction) setLightingMode: (id) sender;
-(void) resetNoiseLevelMenu;
-(IBAction) setNoiseLevel: (id) sender;
-(void) resetOrientationMenu;
-(IBAction) setOrientation: (id) sender;
-(IBAction) setColors: (id) sender;
-(IBAction) showPlayerLocations: (id) sender;
-(IBAction) resetView: (id) sender;
-(IBAction) flushCache: (id) sender;

// Biomes Menu
-(IBAction) setUseBiomes: (id) sender;
-(IBAction) generateBiomes: (id) sender;
-(IBAction) deleteBiomes: (id) sender;
-(void) toggleUseBiomes:(BOOL)forceon;
-(void) startGenerateBiomes:(BOOL)forceon;
-(void) finishGenerateBiomes;


// Tools Menu
- (IBAction) createColorsTxt: (id) sender;
- (IBAction) saveSliceSequence:(id)sender;

// User Interface Controls
- (IBAction) setHeight: (id) sender;

// OpenGL view functions
- (void) updateProjection;
- (void) updateModelView;
- (void) resizeGL;
- (void) prepareOpenGL;
- (void) drawRect:(NSRect)rect;

// Keeping the map updated
- (void)chunkDidRender:(NSNotification *)aNotification;
- (void)animationTimer:(NSTimer *)timer;

// User input even handling
- (void) magnifyWithEvent:(NSEvent *)theEvent;
- (void) swipeWithEvent:(NSEvent *)anEvent;
- (void) beginGestureWithEvent:(NSEvent *)event;
- (void) endGestureWithEvent:(NSEvent *)event;
- (void) keyDown:(NSEvent *)theEvent;
- (void) mouseDown:(NSEvent *)theEvent;
- (void) mouseUp:(NSEvent *)theEvent;
- (void) mouseDragged:(NSEvent *)theEvent;
- (void) scrollWheel:(NSEvent *)theEvent;

// Mapping functions
- (void) drawChunk:(GLuint)texture X:(int)bx Y:(int)by;
- (BOOL) blockIsVisibleX:(int)bx Y:(int)by;
- (void) resetForNewWorld:(BOOL)setView;
- (void) scanAndInitWorld:(NSString*)world_path newBounds:(BOOL)newBounds;
- (void) changeCoords:(int*)coords fromOrientation:(int)fromOr toOrientation:(int)toOr;
- (void) reorientCamera:(int)new_orientation;
- (void) setupMapChunk;
- (void) invalidateAllChunks;
- (void) checkProcessingTask;

// Utility functions
- (BOOL) createColorArrayFromTextFile:(NSString*)textpath colorArray:(MinecraftColors*)colors;
- (BOOL) createColorArrayFromPng:(NSString*)loadpath colorArray:(MinecraftColors*)colors;
- (void) writeColorsFromArray:(MinecraftColors*)colors savePath:(NSString*)savepath;
- (void) startBlockFinder:(NSArray*)blocksToShow inColor:(NSColor*)color xray:(double)xray;
- (void) storeColor;
- (void) restoreColor;

// User Preferences
- (void) loadRenderDefaults;
- (void) setRenderDefaults;
- (void) resetRenderDefaults;
- (void) rescanColorsMenu;
- (void) setMaxSimultaneousRenders:(int)count;
- (int) getMaxSimultaneousRenders;

- (void) saveChunkRange:(NSString*)savepath minx:(int)minx maxx:(int)maxx miny:(int)miny maxy:(int)maxy;

// Cocoa implementation details 
- (BOOL) acceptsFirstResponder;
- (BOOL) becomeFirstResponder;
- (BOOL) resignFirstResponder;
- (id) initWithFrame: (NSRect) frameRect;
- (void) awakeFromNib;

@end

/*
 *  MCMapOpenGLView.mm
 *  MCMap Live
 *
 *  Created by DK on 10/13/10.
 *
 */

#import "MCMapOpenGLView.h"
#include "MapChunk.h"
#include "extractcolors.h"

// ==================================

typedef enum RenderLightingModes {UNIFORM, DAY, NIGHT, TORCHLIGHT, CAVE} LightingMode;

recVec gOrigin = {0.0, 0.0, 0.0};


float zoom_level = 0;
LightingMode lighting_mode = UNIFORM;
int maxdepth = 256;
int newdepth = 256;
int noise_level = 0;
int orientation = 0; // 0=SE, 1=NE, 2=NW, 3=SW
bool showBiomes = NO;

// single set of interaction flags and states
bool useMipMaps = YES;
bool worldLoaded = NO;
std::set< std::pair<int,int> > hasContent;
MapChunk **worldmap = NULL;
int dimension = 0;  // 0=regular world, 1=nether, 2=end
NSSavePanel* currentsavepanel;

int nox,noy,nmx,nmy;
int ox,oy,mx,my;        // Offset X,Y - Mapsize X,Y (in my code I call the map Z coord Y)
                        // It became convention before I knew it was Z internally, sorry!

bool processing = NO;
NSTask* processingTask = Nil;
bool saveSliceSequence = NO;
int slice_minx;
int slice_miny;
int slice_maxx;
int slice_maxy;
int clean_x = 0;
int clean_y = 0;
NSString* slice_basename;
bool saveWorld = NO;   
bool saveChunk = NO;
bool extractBiome = NO;

NSString* current_world_path = @"none";
bool drawnOnce = false;

// Debug vars
BOOL lock_zoom = NO;
float dzoom = 0;

// Special textures
GLuint renderingTexture = 0;
GLuint saveChunkTexture = 0;
GLuint saveWorldTexture = 0;
GLuint biomeExtractTexture = 0;
GLuint beginTexture = 0;

float ffx = 0.998; // 0.978; // The amount by which we tweak tile spacing to avoid seams.
float ffy = 0.998; //0.974;

NSString* mcmap_path;
NSString* temp_dir;

// Colors system
NSString* colors_path;
BOOL default_colors;
NSMenuItem * storedColorStateMenuItem = Nil;
NSString* storedColorsPath;
BOOL slowblending = false;

// Listing of all the worlds
NSMutableArray* mcWorlds;

NSMutableArray * render_settings;

int renders = 0;
std::list<MapChunk*> renderers;
int MAX_SIMULTANEOUS_RENDERS = 4;

GLint gDollyPanStartPoint[2] = {0, 0};
GLboolean gDolly = GL_FALSE;
GLboolean gPan = GL_FALSE;
GLboolean gTrackball = GL_FALSE;
MCMapOpenGLView * gTrackingViewInfo = NULL;
BOOL isGesture = NO;
int userTimer = 0;
int userTimerReset = 20;

// time and message info
CFAbsoluteTime gMsgPresistance = 10.0f;

// error output
float gErrorTime;

// ==================================

#pragma mark ---- Utilities ----

static CFAbsoluteTime gStartTime = 0.0f;

static int max(int a, int b)
{
    if (a > b)
        return a;
    return b;
}

static int min(int a, int b)
{
    if (a < b)
        return a;
    return b;
}

// set app start time
static void setStartTime (void)
{	
	gStartTime = CFAbsoluteTimeGetCurrent ();
}

// ---------------------------------

// return float elpased time in seconds since app start
static CFAbsoluteTime getElapsedTime (void)
{	
	return CFAbsoluteTimeGetCurrent () - gStartTime;
}

#pragma mark ---- Error Reporting ----

// error reporting as both window message and debugger string
void reportError (char * strError)
{
    NSMutableDictionary *attribs = [NSMutableDictionary dictionary];
    [attribs setObject: [NSFont fontWithName: @"Monaco" size: 9.0f] forKey: NSFontAttributeName];
    [attribs setObject: [NSColor whiteColor] forKey: NSForegroundColorAttributeName];

	gErrorTime = getElapsedTime ();
	NSString * errString = [NSString stringWithFormat:@"Error: %s (at time: %0.1f secs).", strError, gErrorTime];
	NSLog (@"%@\n", errString);

}

// ---------------------------------

// if error dump gl errors to debugger string, return error
GLenum glReportError (void)
{
	GLenum err = glGetError();
	if (GL_NO_ERROR != err)
    {
		reportError ((char *) gluErrorString (err));
        NSLog(@"OpenGL Error: %s",reportError);
    }
	return err;
}

#pragma mark ---- OpenGL Utils ----

// --------------------------------
// 

// This function is for loading plain old textures, nothing fancy.
GLuint loadTexture(NSString* filepath)
{
    NSBitmapImageRep *theImage;
    int width, height, bytesPRow;
    unsigned char *fixedImageData;
    
    // Load the image into an NSBitmapImageRep
    theImage = [ NSBitmapImageRep imageRepWithContentsOfFile:filepath ];
    if( theImage != nil )
    {
        // Get some key info on the texture that was just loaded.
        bytesPRow = [ theImage bytesPerRow ];
        width = [ theImage pixelsWide ];
        height = [ theImage pixelsHigh ];

        
        // Convert the NSImage to a CGImage
        CGImageRef image = [theImage CGImage];
        
        // Use CGImage to mask out the pure black areas
        //CGFloat mask[] = {0, 0, 0, 0, 0, 0}; // Change black to transparent
        //CGImageRef masked_image = CGImageCreateWithMaskingColors(image,mask);
                    
        //Set up a Core Graphics context that's compatible with OpenGL's RGBA
        
        fixedImageData = (unsigned char*)calloc(width * 4, height);
        CGColorSpaceRef color_space = CGColorSpaceCreateDeviceRGB();
        CGContextRef myBitmapContext = CGBitmapContextCreate(
                         fixedImageData,                // pointer raw storage
                         width,                         // the width of the context
                         height,                        // the height of the context
                         8,                             // bits per pixel
                         width*4,                       // bytes per row
                         color_space,                   // what color space to use
                         kCGImageAlphaPremultipliedLast // the format of the alpha channel
                         );
        CGContextSetInterpolationQuality(myBitmapContext,kCGInterpolationNone);
        CGContextDrawImage(myBitmapContext, CGRectMake(0,0, width, height), image);
        
        glEnable(GL_TEXTURE_2D);
        GLuint texture[1];
        glGenTextures(1,texture);
        glBindTexture(GL_TEXTURE_2D, texture[0]);
        glTexParameteri( GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE );
        glTexParameteri( GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE );
        
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR_MIPMAP_LINEAR);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
        
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_BASE_LEVEL, 0);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAX_LEVEL, 4);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_LOD, 0);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAX_LOD, 4);
        glTexParameteri(GL_TEXTURE_2D, GL_GENERATE_MIPMAP, GL_TRUE);
        glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, width,height, 0, GL_RGBA, GL_UNSIGNED_BYTE, fixedImageData);
        
        // Release all the stuff we allocated
        CGContextRelease(myBitmapContext);
        CGColorSpaceRelease(color_space);
        free(fixedImageData);
        
        return texture[0];
        
    } else {
        NSLog(@"File not found: %@",filepath);
        return renderingTexture;
    }

}

// ---------------------------------

static void block2screen(int bx, int by, float* screenCoords)
{
    // This function will need to change if we're working with a rotation
        screenCoords[0] = ffx*256*(bx+by);
        screenCoords[1] = ffy*128*(-bx+by);
}

static void screen2block(float x, float y, int* boxCoords)
{
        boxCoords[0] = floor(x/512-y/256);
        boxCoords[1] = floor(x/512+y/256);
}

static void block2screenf(float bx, float by, float* screenCoords)
{
    // This function will need to change if we're working with a rotation
        screenCoords[0] = ffx*256*(bx+by);
        screenCoords[1] = ffy*128*(-bx+by);
}

static void screen2blockf(float x, float y, float* boxCoords)
{
        boxCoords[0] = x/512-y/256;
        boxCoords[1] = x/512+y/256;
}

// ===================================

@implementation MCMapOpenGLView

// pixel format definition
+ (NSOpenGLPixelFormat*) basicPixelFormat
{
    NSOpenGLPixelFormatAttribute attributes [] = {
        NSOpenGLPFAWindow,
        NSOpenGLPFADoubleBuffer,	// double buffered
        //NSOpenGLPFADepthSize, (NSOpenGLPixelFormatAttribute)16, // 16 bit depth buffer
        (NSOpenGLPixelFormatAttribute)nil
    };
    return [[[NSOpenGLPixelFormat alloc] initWithAttributes:attributes] autorelease];
}

-(void) drawLoadMsg
{
    // First reset the projection to ensure the message is onscreen

    glLoadIdentity ();
    
    float msg_size = 261*exp(zoom_level);

    GLuint texture;
    
    if (saveChunk)
        texture = saveChunkTexture;
    else if (saveWorld)
        texture = saveWorldTexture;
    else if (extractBiome)
        texture = biomeExtractTexture;
    else
        texture = beginTexture;
        
    glBindTexture(GL_TEXTURE_2D, texture);
    glColor3f (1.0, 1.0, 1.0);
    glBegin (GL_QUADS);
    
    // Left, Top
    glTexCoord2f(0, 0);
    glVertex2f(-msg_size,-msg_size);
    
    // Right top
    glTexCoord2f(1, 0);
    glVertex2f(msg_size, -msg_size);
    
    // Right, bottom
    glTexCoord2f(1, 1);
    glVertex2f(msg_size,msg_size);
    
    // Left, Bottom
    glTexCoord2f(0, 1);
    glVertex2f(-msg_size,msg_size);
    
    glEnd ();
}

// draw a chunk based on current parameters
- (void) drawChunk:(GLuint)texture X:(int)bx Y:(int)by
{
    glBindTexture(GL_TEXTURE_2D, texture);
    
    glPushMatrix();
    float sc[2];
    block2screen(bx,by,sc);
    glTranslatef(sc[0],sc[1],0);

    
    glColor3f (1.0, 1.0, 1.0);
    glBegin (GL_QUADS);
    
    // Left, Top
    glTexCoord2f(0,1);
    glVertex2f(-256,256);
    
    // Right top
    glTexCoord2f(1,1);
    glVertex2f(255, 256);
    
    // Right, bottom
    glTexCoord2f(1,0);
    glVertex2f(255,-255);
    
    // Left, Bottom
    glTexCoord2f(0,0);
    glVertex2f(-256,-255);
    
    glEnd ();
    
    glPopMatrix();
}

// ---------------------------------

// update the projection matrix based on camera and view info
- (void) updateProjection
{

    [[self openGLContext] makeCurrentContext];

	// set projection
	glMatrixMode (GL_PROJECTION);
	glLoadIdentity ();
    
    float zoom = exp(zoom_level);
    float debug_zoom = exp(dzoom);
	glOrtho(-camera.viewWidth*debug_zoom*zoom/2, camera.viewWidth*debug_zoom*zoom/2, camera.viewHeight*debug_zoom*zoom/2, -camera.viewHeight*debug_zoom*zoom/2, -1, 200);
}

// ---------------------------------

// updates the contexts model view matrix for object and camera moves
- (void) updateModelView
{
    [[self openGLContext] makeCurrentContext];
	
	// move view
	glMatrixMode (GL_MODELVIEW);
	glLoadIdentity ();
	glTranslatef (-camera.viewPos.x, -camera.viewPos.y,0);

}

// ---------------------------------

// handles resizing of GL need context update and if the window dimensions change, a
// a window dimension update, reseting of viewport and an update of the projection matrix
- (void) resizeGL
{
	NSRect rectView = [self bounds];
	
	// ensure camera knows size changed
	if ((camera.viewHeight != rectView.size.height) ||
	    (camera.viewWidth != rectView.size.width)) {
		camera.viewHeight = rectView.size.height;
		camera.viewWidth = rectView.size.width;
		
		glViewport (0, 0, camera.viewWidth, camera.viewHeight);
		[self updateProjection];  // update projection matrix
	}
}
	
// ---------------------------------
	
// move camera in x/y plane
- (void)mousePan: (NSPoint)location isDelta:(BOOL)isdelta
{
	
    GLfloat panX;
	GLfloat panY;
    
    if (isdelta)
    {
        panX = (location.x);
        panY = (location.y);
    }
    else
    {
        panX = (gDollyPanStartPoint[0] - location.x);
        panY = (gDollyPanStartPoint[1] - location.y);
        gDollyPanStartPoint[0] = location.x;
        gDollyPanStartPoint[1] = location.y;
    }
    camera.viewPos.x += (panX * exp(zoom_level));
	camera.viewPos.y += (panY * exp(zoom_level));
    
    // Place a debug string in the notification area
    int bp[2];
    screen2block(camera.viewPos.x,camera.viewPos.y,bp);
    //[statusTextField setTitleWithMnemonic: [NSString stringWithFormat: @"&S( %f , %f ) B( %i , %i )",camera.viewPos.x,camera.viewPos.y,bp[0],bp[1]]];
    

}

// ---------------------------------

// per-window timer function, basic time based animation preformed here
- (void)animationTimer:(NSTimer *)timer
{
    if (userTimer > 0)
        userTimer--;
    [ self setNeedsDisplay: YES ] ;
}

// ---------------------------------

#pragma mark ---- IB Actions ----

-(IBAction) showPlayerLocations: (id) sender
{
	show_players = !show_players;
	if (show_players)
		[showplayersMenuItem setState: NSOnState];
	else 
		[showplayersMenuItem setState: NSOffState];
}

-(IBAction) setHeight: (id) sender
{
    newdepth = [depthSlider intValue];
    if (newdepth < 1)
        newdepth = 1;
    else if (newdepth > 256)
        newdepth = 256;
    
    // Newdepth will be set by the draw function if it decides this would be prudent.
}

-(void) startBlockFinder:(NSArray*)blocksToShow inColor:(NSColor*)color xray:(double)xray
{
    if (xray)
        slowblending = YES;
    else
        slowblending = NO;
    CGFloat r,g,b,a;
    int red,green,blue,alpha;
    [color getRed:&r green:&g blue:&b alpha:&a];
    red = r*255.0f;
    green = g*255.0f;
    blue = b*255.0f;
    alpha = a*255.0f;
    
    colors_path = @"/tmp/block_finder.txt";
    MinecraftColors colors;
    
    // Load up some colors.
    [self createColorArrayFromTextFile:[ NSString stringWithFormat:@"%@/Colors/Minecraft.txt",[ [ NSBundle mainBundle ] resourcePath ]] colorArray:&colors];
    
    // Alter them so everything but selected blocks are the given color.
    for(int i=0;i<MINECRAFT_TILE_COUNT;i++)
    {
        if([blocksToShow containsObject:[NSNumber numberWithInt:i]])
        {
            //NSLog(@"Set up custom color on block ID %i",i);
            colors.c[i][0] = red;
            colors.c[i][1] = green;
            colors.c[i][2] = blue;
            colors.c[i][3] = alpha;
        }
        else
        {
            int brightness = (colors.c[i][0] + 1.2*colors.c[i][1] + 0.8*colors.c[i][2])/3;
            //brightness = 128;
            colors.c[i][0] = brightness;
            colors.c[i][1] = brightness;
            colors.c[i][2] = brightness;
            colors.c[i][3] = 255*(exp(-4*xray)); // Since the values close to 0 are more important.
        }
    }
    
    // Write them out
    [self writeColorsFromArray:&colors savePath:colors_path];
    
    // Tell the map that new colors were set
    [self setColors:Nil];
}

-(void) storeColor
{
    storedColorStateMenuItem = Nil;
    storedColorsPath = [colors_path copy];
    NSArray* items = [colorsMenu itemArray];
    for (int i=0; i<[items count];i++)
    {
        if ([[items objectAtIndex:i] state] == NSOnState)
            storedColorStateMenuItem = [items objectAtIndex:i];
    }
}

-(void) restoreColor
{
    slowblending = NO;
    if (storedColorStateMenuItem == Nil || storedColorStateMenuItem == defaultcolorsMenuItem)
    {
        colors_path = @"placeholder";
        [self setColors: Nil];
        [self setColors: defaultcolorsMenuItem];
    }
    else
    {
        colors_path = storedColorsPath;
        [self setColors: Nil];
        [storedColorStateMenuItem setState: NSOnState];
    }
}

-(IBAction) setColors: (id) sender
{
    BOOL changed = NO;
    
    if (sender == Nil)
    {
        changed = YES;
        default_colors = NO;
    }
    else if (sender == defaultcolorsMenuItem)
    {
        if (!default_colors)
        {
            changed = YES;
            default_colors = YES;
        }
    }
    else if (sender == customcolorsMenuItem)
    {
        NSOpenPanel *panel = [NSOpenPanel openPanel];
        [panel setCanChooseFiles:YES];
        [panel setAllowedFileTypes:[NSArray arrayWithObjects:@"txt",@"png",nil]];
        [panel setCanChooseDirectories:NO];
        [panel setResolvesAliases:YES];
        [panel setAllowsMultipleSelection:NO];
        [panel setPrompt:@"Set Colors"];

        if ([panel runModal] == NSOKButton)
        {
            if ([[panel filename] hasSuffix: @".txt"])
            {
                colors_path = [[panel filename] retain];
                default_colors = NO;
                changed = YES;
            }
            else if ([[panel filename] hasSuffix: @".png"])
            {
                MinecraftColors colors;
                if([self createColorArrayFromPng:[panel filename] colorArray:&colors])
                {
                    [self writeColorsFromArray:&colors savePath:@"/tmp/terrain.txt"];
                    colors_path = @"/tmp/terrain.txt";
                    default_colors = NO;
                    changed = YES;
                }
            }
        }
    }
    else 
    {
        if (![colors_path hasSuffix: [ NSString stringWithFormat:@"%@.txt",[sender title]]] || default_colors )
        {
            if ([sender tag] == 1)
                colors_path = [ NSString stringWithFormat:@"%@/Colors/%@.txt",[ [ NSBundle mainBundle ] resourcePath ],[sender title]];
            else if ([sender tag] == 2)
                colors_path = [ NSString stringWithFormat:[@"~/Library/Application Support/MCMap Live/%@.txt" stringByExpandingTildeInPath],[sender title]];
            default_colors = NO;
            changed = YES;
        }
    }


    if (changed)
    {
        // Uncheck all items
        NSArray* items = [colorsMenu itemArray];
        for (int i=0; i<[items count];i++)
        {
            [[items objectAtIndex:i] setState:NSOffState];
        }
        if( sender != Nil)
            [sender setState: NSOnState];
        [self setupMapChunk];
        if (worldLoaded)
        {
            [self invalidateAllChunks];
        }
        
    }
}

-(void) resetLightingModeMenu
{
    [uniformMenuItem setState: NSOffState];
    [dayMenuItem setState: NSOffState];
    [torchlightMenuItem setState: NSOffState];
    [nightMenuItem setState: NSOffState];
    [caveMenuItem setState: NSOffState];
    
    if (lighting_mode == UNIFORM)
        [uniformMenuItem setState: NSOnState];
    else if (lighting_mode == DAY)
        [dayMenuItem setState: NSOnState];
    else if (lighting_mode == NIGHT)
        [nightMenuItem setState: NSOnState];
    else if (lighting_mode == TORCHLIGHT)
        [torchlightMenuItem setState: NSOnState];
    else if (lighting_mode == CAVE)
        [caveMenuItem setState: NSOnState];
}

-(IBAction) setLightingMode: (id) sender
{
    [uniformMenuItem setState: NSOffState];
    [dayMenuItem setState: NSOffState];
    [torchlightMenuItem setState: NSOffState];
    [nightMenuItem setState: NSOffState];
    [caveMenuItem setState: NSOffState];
    
    LightingMode newmode = UNIFORM;
    if (sender == uniformMenuItem)
    {
        newmode = UNIFORM;    
        [uniformMenuItem setState: NSOnState];
    }
    else if (sender == dayMenuItem)
    {   
        newmode = DAY;
        [dayMenuItem setState: NSOnState];
    }
    else if (sender == nightMenuItem)
    {
        newmode = NIGHT;
        [nightMenuItem setState: NSOnState];
    }
    else if (sender == torchlightMenuItem)
    {   
        newmode = TORCHLIGHT;
        [torchlightMenuItem setState: NSOnState];
    }
    else if (sender == caveMenuItem)
    {
        newmode = CAVE;
        [caveMenuItem setState: NSOnState];
    }
    
    if (lighting_mode != newmode)
    {
        lighting_mode = newmode;
        // Mode changed. Reset everything.
        
        [self setupMapChunk];
        if (worldLoaded)
        {
            [self invalidateAllChunks];
        }
    }

}

-(void) resetNoiseLevelMenu
{
    [noise0menuItem setState: NSOffState];
    [noise5menuItem setState: NSOffState];
    [noise10menuItem setState: NSOffState];
    [noise15menuItem setState: NSOffState];
    [noise20menuItem setState: NSOffState];
    
    if(noise_level == 0)
        [noise0menuItem setState: NSOnState];
    else if(noise_level == 5)
        [noise5menuItem setState: NSOnState];
    else if(noise_level == 10)
        [noise10menuItem setState: NSOnState];
    else if(noise_level == 15)
        [noise15menuItem setState: NSOnState];
    else if(noise_level == 20)
        [noise20menuItem setState: NSOnState];
}

-(IBAction) setNoiseLevel: (id) sender
{
    int new_level = 0;
    
    [noise0menuItem setState: NSOffState];
    [noise5menuItem setState: NSOffState];
    [noise10menuItem setState: NSOffState];
    [noise15menuItem setState: NSOffState];
    [noise20menuItem setState: NSOffState];
    
    if(sender == noise0menuItem)
    {
        new_level = 0;
        [noise0menuItem setState: NSOnState];
    }
    else if(sender == noise5menuItem)
    {
        new_level = 5;
        [noise5menuItem setState: NSOnState];
    }
    else if(sender == noise10menuItem)
    {
        new_level = 10;
        [noise10menuItem setState: NSOnState];
    }
    else if(sender == noise15menuItem)
    {
        new_level = 15;
        [noise15menuItem setState: NSOnState];
    }
    else if(sender == noise20menuItem)
    {
        new_level = 20;
        [noise20menuItem setState: NSOnState];
    }
    
    if (noise_level != new_level)
    {
        noise_level = new_level;
        // Mode changed. Reset everything.
        [self setupMapChunk];
        if (worldLoaded)
        {
            [self invalidateAllChunks];
        }
    }
}

-(void) resetOrientationMenu
{
    [seUpMenuItem setState: NSOffState];
    [swUpMenuItem setState: NSOffState];
    [nwUpMenuItem setState: NSOffState];
    [neUpMenuItem setState: NSOffState];
    
    if (orientation == 0)
        [seUpMenuItem setState: NSOnState];
    else if (orientation == 3)  
        [swUpMenuItem setState: NSOnState];
    else if (orientation == 2)   
        [nwUpMenuItem setState: NSOnState];
    else if (orientation == 1)   
        [neUpMenuItem setState: NSOnState];
}

-(IBAction) setOrientation: (id) sender
{
    [seUpMenuItem setState: NSOffState];
    [swUpMenuItem setState: NSOffState];
    [nwUpMenuItem setState: NSOffState];
    [neUpMenuItem setState: NSOffState];
    
    int newmode = 0;
    if (sender == seUpMenuItem)
    {
        newmode = 0;    
        [seUpMenuItem setState: NSOnState];
    }
    else if (sender == swUpMenuItem)
    {
        newmode = 3;    
        [swUpMenuItem setState: NSOnState];
    }
    else if (sender == nwUpMenuItem)
    {
        newmode = 2;    
        [nwUpMenuItem setState: NSOnState];
    }
    else if (sender == neUpMenuItem)
    {
        newmode = 1;    
        [neUpMenuItem setState: NSOnState];
    }
    
    if (orientation != newmode)
    {
        [self reorientCamera:newmode];
        orientation = newmode;
        // Mode changed. Reset everything.
        [self setupMapChunk];
        if (worldLoaded)
        {
            [self invalidateAllChunks];
        }
        
                
    }

}

-(IBAction) resetView: (id) sender
{
    // 0 = (x,y)
    // 1 = (y,-x)
    // 2 = (-x,-y)
    // 3 = (-y,x)
    /*
        if (orientation == 0)
        ind = i + j*nmx;
    else if (orientation == 1)
        ind = j+((nmx-i-1)*nmx);
    else if (orientation == 2)
        ind = (nmx-i-1)+(nmy-j-1)*nmx;
    else if (orientation == 3)
        ind = (nmy-j-1) + i*nmx;
    */
    
    float screenpos[2];
    
    if (orientation==0)
        block2screen(nox-1,noy-1,screenpos);
    else if (orientation==1)
        block2screen(nmx-noy+1,nox-1,screenpos);
    else if (orientation==2)
        block2screen(nmx-nox-1,nmy-noy+1,screenpos);
    else if (orientation==3)
        block2screen(noy+1,nmy-nox+1,screenpos);
    
    camera.viewPos.x = screenpos[0];
    camera.viewPos.y = screenpos[1];

    //zoom_level = 0;
    [self updateProjection];
    [self setNeedsDisplay: YES];
}

-(IBAction) setUseBiomes: (id) sender
{
    [self toggleUseBiomes:NO];
}

-(void)toggleUseBiomes:(BOOL)forceon
{
    BOOL changed = NO;
    
    // If the world is loaded 
    if ((worldLoaded || forceon) && !processing)
    {
        // and biomes are not being shown...
        if (!showBiomes || forceon)
        {
            // Check if biomes folder exists
            BOOL isdir;
            BOOL exists = [[NSFileManager defaultManager] fileExistsAtPath:[NSString stringWithFormat: @"%@/biomes",current_world_path] isDirectory:&isdir];
            NSString* mcjarpath = [@"~/Library/Application Support/minecraft/bin/minecraft.jar" stringByExpandingTildeInPath];
            BOOL mcexists = [[NSFileManager defaultManager] fileExistsAtPath:mcjarpath];
            
            if (isdir && exists)
            {
                showBiomes = YES;
                changed = YES;
            }
            else if (mcexists)
            {
                int result = NSRunAlertPanel (@"Biome Extraction Notice",
                    @"This world has no saved biome data. Would you like to extract it?\n\nNOTE: This feature is experimental. It may break with a Minecraft update.\n\nAt the moment, it works best with the Default Colors.\n\nIf your world expands, you will need to select Update Biome Data from the Tools menu.",
                    @"Generate Biome Data",
                    @"Cancel", nil  );
                if (result == NSAlertDefaultReturn)
                {
                    [self startGenerateBiomes:forceon];
                    showBiomes = YES;
                    changed = YES;
                }
            }
            else {
                NSRunAlertPanel (@"Biome Extraction Notice",
                    @"Biome rendering requires singleplayer minecraft is installed.",
                    @"Sorry",nil , nil  );
            }

        }
        else
        {
            showBiomes = NO;
            changed = YES;
        }
    }
    else 
    {
        // There's no world to check on, so just toggle and let scanAndInitWorld call this function again when it's time.
        if (!showBiomes)
        {
            showBiomes = YES;
            changed = YES;
        }
        else
        {
            showBiomes = NO;
            changed = YES;
        }

    }

        
    if (changed)
    {
        // Mode changed. Reset everything.
        if (worldLoaded && !processing)
        {
            [self setupMapChunk];
            [self invalidateAllChunks];
        }
        
        if (showBiomes)
            [showBiomesMenuItem setState:NSOnState];
        else
        {
            [showBiomesMenuItem setState:NSOffState];
        }
    }

}

-(void) finishGenerateBiomes
{
    
    // Check if there's any metadata around.
    BOOL isdir;
    BOOL exists = [[NSFileManager defaultManager] fileExistsAtPath:[NSString stringWithFormat: @"%@/biomes",current_world_path] isDirectory:&isdir];
    if (!(isdir && exists) && showBiomes)          
    {
        //NSRunAlertPanel( @"Biome Extraction Notice", @"Biome extraction failed.", @"Sorry",nil,nil);
        if (showBiomes)
        {
            showBiomes = NO;
            [showBiomesMenuItem setState: NSOffState];
            [self setupMapChunk];
            [self invalidateAllChunks];
        }
    }
    else
    {
        if (showBiomes)
        {
            [self setupMapChunk];
            [self invalidateAllChunks];
        }
        /*
        else
        {
            NSRunAlertPanel (@"Biome Extraction Notice",
                @"Biome metadata has been saved!",
                @"OK",nil , nil  );
        }
        */
    }
    
}

-(IBAction) generateBiomes: (id) sender
{
    [self startGenerateBiomes:NO];
}

-(void) startGenerateBiomes:(BOOL)forceon
{
    if ((worldLoaded || forceon ) && !processing)
    {
        NSString* mcjarpath = [@"~/Library/Application Support/minecraft/bin/minecraft.jar" stringByExpandingTildeInPath];
        BOOL mcexists = [[NSFileManager defaultManager] fileExistsAtPath:mcjarpath];
        if (!mcexists)
        {
            NSRunAlertPanel (   @"Biome Extraction Notice",
                                @"Biome rendering requires singleplayer minecraft is installed.",
                                @"Sorry",nil , nil  );
            return;
        }
        
        // Setup an NSTask to run the java program.
        // Make the task and send it off
        processingTask = [[NSTask alloc] init];
        NSString* biome_jar_path = [ NSString stringWithFormat:@"%@/%@",[ [ NSBundle mainBundle ] resourcePath ],@"MinecraftBiomeExtractor.jar" ];

        // Tell the task where to find java
        [processingTask setLaunchPath: @"/usr/bin/java"];

        // Reuse the chunk argument list and add the stuff we want
        NSArray* args = [NSArray arrayWithObjects:  @"-jar",
                                                    biome_jar_path,
                                                    @"-nogui",
                                                    current_world_path,
                                                    nil ];
        [processingTask setArguments: args];
        [processingTask launch];
        processing = YES;
        extractBiome = YES;
    }
}

-(IBAction) deleteBiomes: (id) sender
{    
    if (worldLoaded && !processing)
    {
        NSString* biome_dir = [NSString stringWithFormat: @"%@/biomes",current_world_path];
        BOOL isdir;
        BOOL exists = [[NSFileManager defaultManager] fileExistsAtPath:biome_dir isDirectory:&isdir];
        if (isdir && exists)        
        {
            // Empty the biome metadata folder.
            NSFileManager* fm = [[[NSFileManager alloc] init] autorelease];
            NSDirectoryEnumerator* en = [fm enumeratorAtPath:biome_dir];    
            NSError* err = nil;
            BOOL res;
            NSString* file;
            
            while (file = [en nextObject]) {
                res = [fm removeItemAtPath:[biome_dir stringByAppendingPathComponent:file] error:&err];
                if (!res && err) {
                    NSLog(@"oops: %@", err);
                }
            }
            [fm removeItemAtPath:biome_dir error:&err];
            
            
            NSRunAlertPanel (@"Biome Extraction Notice",
                                @"Biome metadata for this world has been deleted.",
                                @"OK",nil , nil  );
            
            if (showBiomes)
            {
                showBiomes = NO;
                [showBiomesMenuItem setState: NSOffState];
                [self setupMapChunk];
                [self invalidateAllChunks];
            }
        
        }
        else
        {
             NSRunAlertPanel (@"Biome Extraction Notice",
                            @"This world has no biome metadata.",
                            @"OK",nil , nil  );
        }
    }
}

#pragma mark ---- Method Overrides ----

-(void)keyDown:(NSEvent *)theEvent
{
    float amt = 0.001;
    
    NSString *characters = [theEvent characters];
    if ([characters length]) {
        unichar character = [characters characterAtIndex:0];
		switch (character) {
            case NSDownArrowFunctionKey:
                if (newdepth>1)
                    newdepth--;
                [depthSlider setIntegerValue: newdepth];
                break;
            case NSUpArrowFunctionKey:
                if (newdepth<256)
                    newdepth++;
                [depthSlider setIntegerValue: newdepth];
                break;
			case 't':
				ffx = ffx+amt;
                break;
            case 'y':
				ffx = ffx-amt;
                break;
            case 'g':
				ffy = ffy+amt;
                break;
            case 'h':
				ffy = ffy-amt;
                break;
            case 'r':
                ffx = 0.998;
                ffy = 0.998;
                break;
            case 'T':
				ffx = ffx+amt*10;
                break;
            case 'Y':
				ffx = ffx-amt*10;
                break;
            case 'G':
				ffy = ffy+amt*10;
                break;
            case 'H':
				ffy = ffy-amt*10;
                break;
            case 27:    // Escape Key
                if (processing)
                {
                    if (processingTask != Nil)
                    {
                        [processingTask terminate];
                        [processingTask waitUntilExit];
                        [processingTask release];
                        processingTask = Nil;
                    }
                    processing = NO;
                    saveSliceSequence = NO;
                    saveWorld = NO;   
                    saveChunk = NO;
                    extractBiome = NO;
                }
                break;
		}
        
        if ([theEvent modifierFlags] & NSCommandKeyMask)
        {
            if (character == '=')
            {
                    zoom_level -= 0.5;
                    if (zoom_level > 5)
                        zoom_level = 5;
                    if (zoom_level < -1.5)
                        zoom_level = -1.5;
                    [self updateProjection]; // update projection matrix
                    [self setNeedsDisplay: YES];
                    if (userTimer > 5)
                        userTimer = 5;
            }
            else if (character == '-')
            {
                    zoom_level += 0.5;
                    if (zoom_level > 5)
                        zoom_level = 5;
                    if (zoom_level < -1.5)
                        zoom_level = -1.5;
                    [self updateProjection]; // update projection matrix
                    [self setNeedsDisplay: YES];
                    if (userTimer > 5)
                        userTimer = 5;
            }
            else if (character == '0')
            {
                    zoom_level = 0;
                    [self updateProjection]; // update projection matrix
                    [self setNeedsDisplay: YES];
                    if (userTimer > 5)
                        userTimer = 5;
            }
        }
        
        //NSLog(@"ff: %f,%f",ffx,ffy);
	}
}

// ---------------------------------

- (void)mouseDown:(NSEvent *)theEvent // pan
{
	NSPoint location = [self convertPoint:[theEvent locationInWindow] fromView:nil];
	location.y = camera.viewHeight - location.y;
	gPan = GL_TRUE;
    userTimer = userTimerReset;
	gDollyPanStartPoint[0] = location.x;
	gDollyPanStartPoint[1] = location.y;
	gTrackingViewInfo = self;
    isGesture = NO;
}

- (void)mouseUp:(NSEvent *)theEvent
{
	if (gPan==GL_TRUE) { // end pan
		gPan = GL_FALSE;
        }
    if (userTimer > 5)
        userTimer = 5;
	gTrackingViewInfo = NULL;
    isGesture = NO;
    [self setNeedsDisplay: YES];
    //NSLog(@"Camera Position (%f,%f)",camera.viewPos.x,camera.viewPos.y);
}

- (void)mouseDragged:(NSEvent *)theEvent
{
    userTimer = userTimerReset;
	NSPoint location = [self convertPoint:[theEvent locationInWindow] fromView:nil];
	location.y = camera.viewHeight - location.y;
	if (gPan==GL_TRUE) {
        [self mousePan: location isDelta:NO];
        [self setNeedsDisplay: YES];
        }
}

- (void)beginGestureWithEvent:(NSEvent *)event
{    
    isGesture = YES;
}
- (void)endGestureWithEvent:(NSEvent *)event
{
    // User lifted fingers, is probably expecting some action soon.
    if (userTimer > 5)
        userTimer = 5;
    [self setNeedsDisplay: YES];
}

- (void)scrollWheel:(NSEvent *)theEvent
{
    if (userTimer > 5)
        userTimer = 5;
    if (!isGesture)
    {
        float wheelDelta = [theEvent deltaX] +[theEvent deltaY] + [theEvent deltaZ];
        if (wheelDelta)
        {
            if (lock_zoom)
            {
                dzoom -= (wheelDelta*0.01);
            }
            else
            {
                zoom_level -= (wheelDelta*0.01);
                if (zoom_level > 5)
                    zoom_level = 5;
                if (zoom_level < -1.5)
                    zoom_level = -1.5;
            }
            [self updateProjection]; // update projection matrix
            [self setNeedsDisplay: YES];
        }
    }
    else 
    {
        NSPoint location;
        location.x = -3*[theEvent deltaX];
        location.y = -3*[theEvent deltaY];
        [self mousePan:location isDelta:YES];
        [self setNeedsDisplay: YES];
    }
}

-(void)swipeWithEvent:(NSEvent *)theEvent
{
        NSPoint location;
        location.x = -3*[theEvent deltaX];
        location.y = -3*[theEvent deltaY];
        [self mousePan:location isDelta:YES];
        [self setNeedsDisplay: YES];
}

-(void)magnifyWithEvent:(NSEvent *)anEvent
{
        userTimer = userTimerReset;
        zoom_level -= ([anEvent deltaZ]*0.001);
        if (zoom_level > 5)
            zoom_level = 5;
        if (zoom_level < -1.5)
            zoom_level = -1.5;
		[self updateProjection]; // update projection matrix
		[self setNeedsDisplay: YES];
}

// ---------------------------------

- (BOOL) blockIsVisibleX:(int)bx Y:(int)by
{
    // This code isn't needed for magnification (vs zooming out)
    if (zoom_level < 0)
        return true;
    
    // Check each corner of the block and make sure its screen position
    float ul[2], ur[2], bl[2], br[2];
    float zoom = exp(zoom_level);
    float blocksize = 522;
    
    // Screen Edges
    float left = camera.viewPos.x - (0.5*camera.viewWidth+blocksize)*zoom;
    float right = camera.viewPos.x + (0.5*camera.viewWidth+blocksize)*zoom;
    float top = camera.viewPos.y + (0.5*camera.viewHeight+blocksize)*zoom;
    float bottom = camera.viewPos.y - (0.5*camera.viewHeight+blocksize)*zoom;
    
    block2screen(bx-1,by-1,ul);
    block2screen(bx+2,by-1,ur);
    block2screen(bx-1,by+2,bl);
    block2screen(bx+2,by+2,br);
    
    if (ul[0] > left && ul[0] < right && ul[1] > bottom && ul[1] < top)
        return TRUE;
    if (ur[0] > left && ur[0] < right && ur[1] > bottom && ur[1] < top)
        return TRUE;
    if (bl[0] > left && bl[0] < right && bl[1] > bottom && bl[1] < top)
        return TRUE;
    if (br[0] > left && br[0] < right && br[1] > bottom && br[1] < top)
        return TRUE;
    return FALSE;
}

- (void) drawRect:(NSRect)rect
{	
    [[self openGLContext] update];
    [[self openGLContext] makeCurrentContext];
    
	// setup viewport and prespective
    
	[self resizeGL]; // forces projection matrix update (does test for size changes)
	[self updateModelView];  // update model view matrix for object

	// clear our drawable
	glClear (GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
	
	// model view and projection matricies already set
    if (worldLoaded == YES && !processing)
    {
    
        // Update any properties that would kill us if they updated more than once per frame:
        if (maxdepth != newdepth)
        {
            maxdepth = newdepth;
            [depthIndicator setTitleWithMnemonic: [NSString stringWithFormat: @"%i",maxdepth]];
            [self setupMapChunk];
            [self invalidateAllChunks];
        }
        //[statusTextField setTitleWithMnemonic: [NSString stringWithFormat: @"Depth: %i",maxdepth]];
    
        // Screen Edges
        float zoom = exp(zoom_level);
        float left = camera.viewPos.x - 0.5*camera.viewWidth*zoom;
        float right = camera.viewPos.x + 0.5*camera.viewWidth*zoom;
        float top = camera.viewPos.y + 0.5*camera.viewHeight*zoom;
        float bottom = camera.viewPos.y - 0.5*camera.viewHeight*zoom;
        
        
        
        // Blocks at nearest screen edge
        int ul[2], ur[2], bl[2], br[2];
        screen2block(left, top, ul);
        screen2block(right, top, ur);
        screen2block(left, bottom, bl);
        screen2block(right, bottom, br);
        
        // These are a really loose bound on the visible blocks but they are easy to calculate.
        // They give us something to iterate over that isn't all blocks in the world.
        int minx = min(min(min(ul[0],ur[0]),bl[0]),br[0])-1;
        int maxx = max(max(max(ul[0],ur[0]),bl[0]),br[0])+1;
        int miny = min(min(min(ul[1],ur[1]),bl[1]),br[1])-1;
        int maxy = max(max(max(ul[1],ur[1]),bl[1]),br[1])+1;
        
        MapChunk *chunk;
        GLuint texture;

        // Process any finished renders
        std::list<MapChunk*>::iterator it;
        for (it = renderers.begin(); it != renderers.end(); /* nothing here */ )
        {
            if ((*it)->renderIsDone())
            {
              renderers.erase(it++);
            }
            else
            {
                // Now we should check if any pending jobs are for
                // Chunks offscreen but honestly... why bother?
                ++it;
            }
        }
        
        int ind;
        
        // This block of insanity makes sure we are working with the right boundaries for every orientation.
        // Getting rid of it will cause repeating copies of the map to appear on diagonals but won't
        // break anything. I think its computational cost is reasonable. It runs once per frame.
        // It could be reduced if I could be bothered to store some of the result.
        //--------------------------------------
        
        
        int min_lim[2],max_lim[2];
        min_lim[0] = 0;
        min_lim[1] = 0;
        max_lim[0] = nmx-1;
        max_lim[1] = nmy-1;
        [self changeCoords:min_lim fromOrientation:0 toOrientation:orientation];
        [self changeCoords:max_lim fromOrientation:0 toOrientation:orientation];
        
        if (orientation == 2)
        {
            min_lim[0] = min_lim[0]-1;
            max_lim[0] = max_lim[0]-1;
        }
        if (orientation == 3)
        {
            min_lim[1] = min_lim[1]-1;
            max_lim[1] = max_lim[1]-1;
        }
        
        minx = max(min(min_lim[0],max_lim[0]),minx);
        maxx = min(max(min_lim[0],max_lim[0]),maxx);
        miny = max(min(min_lim[1],max_lim[1]),miny);
        maxy = min(max(min_lim[1],max_lim[1]),maxy);
        
        
        //--------------------------------------
        // The main rendering loop (because our draw order sucks for rendering)
        // This code is absolutely ridiculous but this is the gist of it:
        // Find where the user is looking in tile space. 
        // Request tiles draw working outward in concentric squares from that point.
        //--------------------------------------
        bool done = false;
        int cb[2];
        screen2block(camera.viewPos.x,camera.viewPos.y,cb);
        int cx = cb[0]+1;
        int cy = cb[1]+1;
        
        int rmin = 0;
        int rmax = max(abs(cy-miny), max(abs(maxy-cy), max(abs(cx-minx), abs(maxx-cx))));
        
        for(int r=rmin; r<=rmax; r++)
        {
            int i,j;
            j = cy+r;
            if(j >= miny && j <= maxy)
            {
                for(i=cx-r;i<=cx+r;i++)
                {// draw
                    if (orientation == 0)
                        ind = i + j*nmx;
                    else if (orientation == 1)
                        ind = j+((nmx-i-1)*nmx);
                    else if (orientation == 2)
                        ind = (nmx-i-1)+(nmy-j-1)*nmx;
                    else if (orientation == 3)
                        ind = (nmy-j-1) + i*nmx;
                    
                    if (ind > -1 && ind < nmx*nmy)
                    {
                        chunk = worldmap[ind];
                        if ([self blockIsVisibleX:(i) Y:(j)] && chunk->isVisible(left,right,top,bottom,zoom))
                        {
                            if (chunk->checkRenderer() == 0 && renderers.size()<MAX_SIMULTANEOUS_RENDERS)
                            {
                                chunk->startRenderer();
                                renderers.push_back(chunk);
                            }
                            else if (renderers.size()>=MAX_SIMULTANEOUS_RENDERS)
                            {
                                done = true;
                                break;
                            }
                        }
                    }
                }
            }
            
            
            
            if (done)
                break;
                
            i = cx+r;
            if(i >= minx && i <= maxx)
            {
                for(j=cy+r-1;j>cy-r;j--)
                {// draw
                    if (orientation == 0)
                        ind = i + j*nmx;
                    else if (orientation == 1)
                        ind = j+((nmx-i-1)*nmx);
                    else if (orientation == 2)
                        ind = (nmx-i-1)+(nmy-j-1)*nmx;
                    else if (orientation == 3)
                        ind = (nmy-j-1) + i*nmx;
                    
                    if (ind > -1 && ind < nmx*nmy)
                    {
                        chunk = worldmap[ind];
                        if ([self blockIsVisibleX:(i) Y:(j)] && chunk->isVisible(left,right,top,bottom,zoom))
                        {
                            if (chunk->checkRenderer() == 0 && renderers.size()<MAX_SIMULTANEOUS_RENDERS)
                            {
                                chunk->startRenderer();
                                renderers.push_back(chunk);
                            }
                            else if (renderers.size()>=MAX_SIMULTANEOUS_RENDERS)
                            {
                                done = true;
                                break;
                            }
                        }
                    }
                }
            }
            
            if (done)
                break;
            
            j = cy-r;
            if(j >= miny && j <= maxy)
            {
                for(i=cx+r;i>=cx-r;i--)
                {// draw
                    if (orientation == 0)
                        ind = i + j*nmx;
                    else if (orientation == 1)
                        ind = j+((nmx-i-1)*nmx);
                    else if (orientation == 2)
                        ind = (nmx-i-1)+(nmy-j-1)*nmx;
                    else if (orientation == 3)
                        ind = (nmy-j-1) + i*nmx;
                    
                    if (ind > -1 && ind < nmx*nmy)
                    {
                        chunk = worldmap[ind];
                        if ([self blockIsVisibleX:(i) Y:(j)] && chunk->isVisible(left,right,top,bottom,zoom))
                        {
                            if (chunk->checkRenderer() == 0 && renderers.size()<MAX_SIMULTANEOUS_RENDERS)
                            {
                                chunk->startRenderer();
                                renderers.push_back(chunk);
                            }
                            else if (renderers.size()>=MAX_SIMULTANEOUS_RENDERS)
                            {
                                done = true;
                                break;
                            }
                        }
                    }
                }
            }
            
            if (done)
                break;
            
            i = cx-r;
            if(i >= minx && i <= maxx)
            {
                for(j=cy-r-1;j<cy+r;j++)
                {// draw
                    if (orientation == 0)
                        ind = i + j*nmx;
                    else if (orientation == 1)
                        ind = j+((nmx-i-1)*nmx);
                    else if (orientation == 2)
                        ind = (nmx-i-1)+(nmy-j-1)*nmx;
                    else if (orientation == 3)
                        ind = (nmy-j-1) + i*nmx;
                    
                    if (ind > -1 && ind < nmx*nmy)
                    {
                        chunk = worldmap[ind];
                        if ([self blockIsVisibleX:(i) Y:(j)] && chunk->isVisible(left,right,top,bottom,zoom))
                        {
                            if (chunk->checkRenderer() == 0 && renderers.size()<MAX_SIMULTANEOUS_RENDERS)
                            {
                                chunk->startRenderer();
                                renderers.push_back(chunk);
                            }
                            else if (renderers.size()>=MAX_SIMULTANEOUS_RENDERS)
                            {
                                done = true;
                                break;
                            }
                        }
                    }
                }
            }
            
            if (done)
                break;
            
        }
        
        
        //--------------------------------------
        // The main drawing loop ( we need to draw in this order )
        //--------------------------------------
        int update_counter = 0;
        for(int j = miny; j<=maxy; j+=1)
        {
            for(int i = maxx; i>=minx; i-=1)
            {
                if (orientation == 0)
                    ind = i + j*nmx;
                else if (orientation == 1)
                    ind = j+((nmx-i-1)*nmx);
                else if (orientation == 2)
                    ind = (nmx-i-1)+(nmy-j-1)*nmx;
                else if (orientation == 3)
                    ind = (nmy-j-1) + i*nmx;
                
                if (ind > -1 && ind < nmx*nmy)
                {
                    chunk = worldmap[ind];
                    texture = chunk->getTexture(zoom,(userTimer==0 && update_counter<25), update_counter);
                    
                    if ([self blockIsVisibleX:(i) Y:(j)] && chunk->isVisible(left,right,top,bottom,zoom))
                    {
                        
                        /*
                        
                        if (chunk->checkRenderer() == 0 && renderers.size()<MAX_SIMULTANEOUS_RENDERS)
                        {
                            chunk->startRenderer();
                            renderers.push_back(chunk);
                        }
                        
                        */
                        
                        [self drawChunk: texture X:(i) Y:(j)]; // draw scene
                    }
                }
            }
        }
        //--------------------------------------
        
        /*
        
        //--------------------------------------
        // Lastly, the cleanup loop. Cleanup 25 mapchunks
        //--------------------------------------
        int cleanup_count = 25;
        for (int i = 0; i<cleanup_count; i++)
        {
            clean_x++;
            if (clean_x >= nmx)
            {
                clean_x = 0;
                clean_y++;
            }
            if (clean_y >= nmy)
                clean_y = 0;
            
            if (![self blockIsVisibleX:clean_x Y:clean_y])
            {
                if (orientation == 0)
                    ind = clean_x + clean_y*nmx;
                else if (orientation == 1)
                    ind = clean_y+((nmx-clean_x-1)*nmx);
                else if (orientation == 2)
                    ind = (nmx-clean_x-1)+(nmy-clean_y-1)*nmx;
                else if (orientation == 3)
                    ind = (nmy-clean_y-1) + clean_x*nmx;
                
                if (ind > -1 && ind < nmx*nmy)
                    worldmap[ind]->deleteAllTextures();
            }
                
        }
        */
        
    }
    else 
    {
        // Check if the processing task is done
        if(processing)
        {
            [self checkProcessingTask];
        }
        
        [self drawLoadMsg];
    }

    [[self openGLContext] flushBuffer];
	glReportError();
    
    drawnOnce = true;
}

// ---------------------------------

// set initial OpenGL state (current context is set)
// called after context is created
- (void) prepareOpenGL
{
    GLint swapInt = 1;
    [[self openGLContext] setValues:&swapInt forParameter:NSOpenGLCPSwapInterval]; // set to vbl sync

	// init GL stuff here
	glDisable(GL_DEPTH_TEST);
    glEnable(GL_BLEND);
    glBlendFunc(GL_ONE, GL_ONE_MINUS_SRC_ALPHA);
    
	//glShadeModel(GL_SMOOTH);    
	//glEnable(GL_CULL_FACE);
	//glFrontFace(GL_CCW);
	//glPolygonOffset (1.0f, 1.0f);
	
	glClearColor(0.0f, 0.0f, 0.0f, 1.0f);
    //[self resetView:Nil];

	// init fonts for use with strings
	NSFont * font =[NSFont fontWithName:@"Helvetica" size:12.0];
	stanStringAttrib = [[NSMutableDictionary dictionary] retain];
	[stanStringAttrib setObject:font forKey:NSFontAttributeName];
	[stanStringAttrib setObject:[NSColor whiteColor] forKey:NSForegroundColorAttributeName];
	[font release];
    
    NSString* rt_path = [ NSString stringWithFormat:@"%@/%s",[ [ NSBundle mainBundle ] resourcePath ],"rendering.png" ];
    renderingTexture = loadTexture(rt_path);
    rt_path = [ NSString stringWithFormat:@"%@/%s",[ [ NSBundle mainBundle ] resourcePath ],"begin.png" ];
    beginTexture = loadTexture(rt_path);
    rt_path = [ NSString stringWithFormat:@"%@/%s",[ [ NSBundle mainBundle ] resourcePath ],"rendering_selection.png" ];
    saveChunkTexture = loadTexture(rt_path);
    rt_path = [ NSString stringWithFormat:@"%@/%s",[ [ NSBundle mainBundle ] resourcePath ],"rendering_world.png" ];
    saveWorldTexture = loadTexture(rt_path);
    rt_path = [ NSString stringWithFormat:@"%@/%s",[ [ NSBundle mainBundle ] resourcePath ],"extracting_biome.png" ];
    biomeExtractTexture = loadTexture(rt_path);
    
    [self setupMapChunk];


}

// ---------------------------------

-(id) initWithFrame: (NSRect) frameRect
{
	NSOpenGLPixelFormat * pf = [MCMapOpenGLView basicPixelFormat];

	self = [super initWithFrame: frameRect pixelFormat: pf];
    return self;
}

// ---------------------------------

- (BOOL)acceptsFirstResponder
{
  return YES;
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)theApplication
{
    return YES;
}

// ---------------------------------

- (BOOL)becomeFirstResponder
{
  return  YES;
}

// ---------------------------------

- (BOOL)resignFirstResponder
{
  return YES;
}

// ---------------------------------

- (IBAction) openWorldFolder: (id) sender
{
    if (!processing)
    {
    NSOpenPanel *panel = [NSOpenPanel openPanel];
    [panel setCanChooseFiles:NO];
    [panel setCanChooseDirectories:YES];
    [panel setResolvesAliases:YES];
    [panel setAllowsMultipleSelection:NO];
    [panel setPrompt:@"Open World"];

    if ([panel runModal] == NSOKButton)
    {
        if ([[NSFileManager defaultManager] fileExistsAtPath:[NSString stringWithFormat:@"%@/level.dat",[panel filename]] isDirectory:nil])
        {
            current_world_path = [[panel filename] retain];
            
            if (worldLoaded)
                [self resetForNewWorld: NO];
                
            [self scanAndInitWorld:current_world_path newBounds:YES];
            [self resetView:Nil];
            [self setupMapChunk];
            
            worldLoaded = YES;
            [saveChunkMenuItem setEnabled:YES];
            [saveWorldMenuItem setEnabled:YES];
        }
    }
    }
}

- (IBAction) openWorld: (id) sender
{
    if (!processing)
    {
    // Check the index of the menu item. Cross-ref this with the mcWorlds NSArray which will have the path we need.
    NSString* new_world_path = [mcWorlds objectAtIndex:[worldsMenu indexOfItem:sender]];
    
    if (! [new_world_path isEqualToString:current_world_path])
        current_world_path = new_world_path;
    
    if (worldLoaded)
        [self resetForNewWorld:YES];
    
    [self scanAndInitWorld:current_world_path newBounds:YES];
    [self resetView:Nil];
    [self setupMapChunk];
    
    worldLoaded = YES;
    [saveChunkMenuItem setEnabled:YES];
    [saveWorldMenuItem setEnabled:YES];
    }
}

- (BOOL) createColorArrayFromTextFile:(NSString*)textpath colorArray:(MinecraftColors*)colors
{
    NSError** err = nil;
    NSString* colortxt = [NSString stringWithContentsOfFile:textpath encoding:NSASCIIStringEncoding error:err];

    if (err) {
            NSLog(@"Bad text file: %@", err);
            return NO;
            }
    
    NSArray* lines = [colortxt componentsSeparatedByString:@"\n"];
    
    for(NSString* line in lines)
    {
        NSScanner* scanner = [NSScanner scannerWithString:line];
        int row[6];
        bool goodline = true;
        for(int i=0;i<6;i++)
        {
            if (![scanner scanInt:row+i])
            {
                goodline = false;
                break;
            }
        }
        if (goodline && row[0]<MINECRAFT_TILE_COUNT && row[0]>=0)
        {
            colors->c[row[0]][0] = row[1];
            colors->c[row[0]][1] = row[2];
            colors->c[row[0]][2] = row[3];
            colors->c[row[0]][3] = row[4];
            colors->c[row[0]][4] = row[5];
        }
    }
    return YES;
}

- (BOOL) createColorArrayFromPng:(NSString*)loadpath colorArray:(MinecraftColors*)colors
{
    NSBitmapImageRep *theImage;
    int width, height, bytesPRow;
    unsigned char *fixedImageData;
    
    // Load the image into an NSBitmapImageRep
    theImage = [ NSBitmapImageRep imageRepWithContentsOfFile:loadpath ];
    if( theImage != nil )
    {
        // Get some key info on the texture that was just loaded.
        bytesPRow = [ theImage bytesPerRow ];
        width = [ theImage pixelsWide ];
        height = [ theImage pixelsHigh ];
        
        if (width == height && (height%16)==0)
        {
            // Convert the NSImage to a CGImage
            CGImageRef image = [theImage CGImage];
                        
            //Set up a Core Graphics context that's compatible with OpenGL's RGBA
            
            fixedImageData = (unsigned char*)calloc(width * 4, height);
            CGColorSpaceRef color_space = CGColorSpaceCreateDeviceRGB();
            CGContextRef myBitmapContext = CGBitmapContextCreate(
                             fixedImageData,                // pointer raw storage
                             width,                         // the width of the context
                             height,                        // the height of the context
                             8,                             // bits per pixel
                             width*4,                       // bytes per row
                             color_space,                   // what color space to use
                             kCGImageAlphaPremultipliedLast // the format of the alpha channel
                             );
            CGContextSetInterpolationQuality(myBitmapContext,kCGInterpolationNone);
            CGContextDrawImage(myBitmapContext, CGRectMake(0,0, width, height), image);
            
            
            int result = NSRunAlertPanel (@"Minecraft Compatibility Note",
                    @"Newer texture packs include gray grass and trees to allow biome-specific coloring. Press Fix Colors if you want these changed to green. Press Keep Gray if you plan on using biome coloring (or you are importing an old texture pack with green grass).",
                    @"Fix Colors",
                    @"Keep Gray", nil  );
            bool fixFoliage = false;
            if (result == NSAlertDefaultReturn)
                fixFoliage = true;
            
            // Raw RGBA image data is now in fixedImageData.
            // Do what you will
            extractcolors(fixedImageData,height/16,colors->c,fixFoliage);
            
            CGContextRelease(myBitmapContext);
            CGColorSpaceRelease(color_space);
            free(fixedImageData);
            
            return YES;
        }
    }
    return NO;
}

- (void) writeColorsFromArray:(MinecraftColors*)colors savePath:(NSString*)savepath
{
    // Create and allocate string
    NSMutableString *mutstr = [[NSMutableString alloc] init];
    
    // Header
    [mutstr appendFormat: @"#ID   R   G   B   A   Noise\n"];
    
    // All the entires
    for(int i = 0; i < MINECRAFT_TILE_COUNT; i++)
        [mutstr appendFormat:@"%i   %i   %i   %i   %i   %i\n", i, colors->c[i][0],colors->c[i][1],colors->c[i][2],colors->c[i][3], colors->c[i][4]];
    
    // Write to file
    [mutstr writeToFile:savepath atomically:YES encoding:NSASCIIStringEncoding error:Nil];
    
    // Deallocate string
    [mutstr release];
}

- (IBAction) createColorsTxt: (id) sender
{
    NSOpenPanel *panel = [NSOpenPanel openPanel];
    [panel setCanChooseFiles:YES];
    [panel setTitle:@"Select a terrain.png"];
    [panel setAllowedFileTypes:[NSArray arrayWithObjects:@"png",nil]];
    [panel setCanChooseDirectories:NO];
    [panel setResolvesAliases:YES];
    [panel setAllowsMultipleSelection:NO];
    [panel setPrompt:@"Select"];

    if ([panel runModal] == NSOKButton)
    {
    
        if ([[panel filename] hasSuffix: @".png"])
        {
            MinecraftColors colors;
            if([self createColorArrayFromPng:[panel filename] colorArray:&colors])
            {
                NSSavePanel *spanel = [NSSavePanel savePanel];
                [spanel setTitle:@"Save Custom Colors"];
                [spanel setAllowedFileTypes:[NSArray arrayWithObjects:@"txt",nil]];
                [spanel setPrompt:@"Save"];
                
                if ([spanel runModal] == NSOKButton)
                {
                    [self writeColorsFromArray:&colors savePath:[spanel filename]];
                }
            }
        }
    
    }
}

-(void) invalidateAllChunks
{
    // Clear the render queue
    renderers.clear();
    
    // Iterate over the whole map space invalidating every chunk.
    for(int j=0; j<nmy;j++)
    {
        for(int i=0;i<nmx;i++)
        {
            worldmap[i+j*nmx]->invalidate();
        }
    }
}

-(void) scanAndInitWorld:(NSString*)world_path newBounds:(BOOL)newBounds
{
    if (worldmap!=NULL)
    {   
        NSLog(@"Initializing world over existing data. This may cause a crash or a memory leak.");
        free(worldmap);
    }
    
    if (newBounds)
    {
        BOOL isDir=NO;
        NSArray *possibleRegions;
        NSFileManager *fileManager = [[NSFileManager alloc] init];
        
        if (dimension == 1)
        {
            world_path = [NSString stringWithFormat: @"%@/DIM-1/region", world_path];
        }
        else
        {
            world_path = [NSString stringWithFormat: @"%@/region", world_path];
        }
        
        if ([fileManager fileExistsAtPath:world_path isDirectory:&isDir] && isDir)
            [fileManager changeCurrentDirectoryPath:world_path];
        possibleRegions = [fileManager contentsOfDirectoryAtPath:world_path error:nil];
        
        int minX=0;
        int minY=0;
        int maxX=0;
        int maxY=0;
        
        hasContent.clear();
        
        NSString* entry;
        NSArray * regioncomponents;
        for (entry in possibleRegions)
        {
            if ([fileManager fileExistsAtPath:entry isDirectory:&isDir] && !isDir && [entry hasSuffix:@".mca"] )
            {
                
                regioncomponents = [[[entry componentsSeparatedByString:@"/"] lastObject] componentsSeparatedByString:@"."];
                
                if ([regioncomponents count]==4)
                {
                    int valX = [[regioncomponents objectAtIndex:1] integerValue]*32;
                    int valZ = [[regioncomponents objectAtIndex:2] integerValue]*32;
                    
                    for (int i=int(floor(float(valX)/8.0f)); i<int(floor(float(valX)/8.0f))+8; i++)
                    {
                        for (int j=int(floor(float(valZ)/8.0f)); j<int(floor(float(valZ)/8.0f))+8; j++)
                        {
                            hasContent.insert(std::make_pair(i,j));
                        }
                    }
                    
                    if (abs(valZ)<4096)
                    {
                        if (valZ < minY)
                            minY = valZ;
                        else if (valZ > maxY)
                            maxY = valZ;
                    }
                    if (abs(valX)<4096)
                    {
                        if (valX < minX)
                            minX = valX;
                        else if (valX > maxX)
                            maxX = valX;
                    }
                }
            }
        }

        [fileManager release];
        
        //maxX = maxX+1;
        //maxY = maxY+1;
        //minX = minX-8;
        //minY = minY-8;
        
        // Create the boundaries and initialize the map.
        
        nmx = floor(float(maxX)/8.0f)-floor(float(minX)/8.0f)+2;
        nmy = floor(float(maxY)/8.0f)-floor(float(minY)/8.0f)+2;
        
        nox = -floor(float(minX)/8.0f)-1; // If you're looking for chunk a,b, then map[((a+ox)/8)+((b+oy)/8)*mx]
        noy = -floor(float(minY)/8.0f)-1; // will contain the chunk you want.
        
        NSLog(@"World is %i by %i in 8-chunks. It spans from %i,%i to %i,%i",nmx,nmy,minX,minY,maxX,maxY);
    }

    worldmap = (MapChunk**)calloc(sizeof(MapChunk*),nmx*nmy);
    
    std::set< std::pair<int,int> >::iterator it;
    
    for(int j=0; j<nmy;j++)
    {
        for(int i=0;i<nmx;i++)
        {
            worldmap[i+j*nmx] = new MapChunk((i-nox)*8,(j-noy)*8);
            it = hasContent.find(std::make_pair((i-nox),(j-noy)));
            // This chunk is blank
            if (it == hasContent.end())
                worldmap[i+j*nmx]->setBlank();
        }
    }
    
    // If the user wants to show biomes for this level, turn them off and let the standard method turn them back on.
    if(showBiomes)
    {
        [self toggleUseBiomes:YES];
    }
}

- (void) changeCoords:(int*)coords fromOrientation:(int)fromOr toOrientation:(int)toOr
{
    int ax,ay;
    if (fromOr == 0)
    {
        ax = coords[0];
        ay = coords[1];
    }
    if (fromOr == 1)
    {
        ax = coords[1];
        ay = nmx-coords[0];
    }
    else if (fromOr==2)
    {
        ax = nmx-coords[0];
        ay = nmy-coords[1];
    }
    else if (fromOr==3)
    {
        ay = coords[0];
        ax = nmy-coords[1];
    }
    
    if (toOr==0)
    {
        coords[0] = ax;
        coords[1] = ay;
    }
    else if (toOr==1)
    {
        coords[0] = nmx-ay;
        coords[1] = ax;
    }
    else if (toOr==2)
    {
        coords[0] = nmx-ax;
        coords[1] = nmy-ay;
    }
    else if (toOr==3)
    {
        coords[0] = ay;
        coords[1] = nmy-ax;
    }
}

- (void) reorientCamera:(int)new_orientation
{
    // 0 = (x,y)
    // 1 = (y,-x)
    // 2 = (-x,-y)
    // 3 = (-y,x)
    
    // First, find out what block the camera is looking at in or=1 coords
    float bp[2];
    float ax,ay,bx,by;
    screen2blockf(camera.viewPos.x,camera.viewPos.y,bp);
    bp[0] = bp[0];
    bp[1] = bp[1];
    
    if (orientation == 0)
    {
        ax = bp[0];
        ay = bp[1];
    }
    if (orientation == 1)
    {
        ax = bp[1];
        ay = nmx-bp[0];
    }
    else if (orientation==2)
    {
        ax = nmx-bp[0];
        ay = nmy-bp[1];
    }
    else if (orientation==3)
    {
        ay = bp[0];
        ax = nmy-bp[1];
    }
    
    if (new_orientation==0)
    {
        bx = ax;
        by = ay;
    }
    else if (new_orientation==1)
    {
        bx = nmx-ay;
        by = ax;
    }
    else if (new_orientation==2)
    {
        bx = nmx-ax;
        by = nmy-ay;
    }
    else if (new_orientation==3)
    {
        bx = ay;
        by = nmy-ax;
    }
    
    float screenpos[2];
    block2screenf(bx,by,screenpos);
    

    camera.viewPos.x = screenpos[0];
    camera.viewPos.y = screenpos[1];
    

    [self updateProjection];
    [self setNeedsDisplay: YES];
    
    
}

- (IBAction) changeSaveFormat: (id) sender
{
    if ([imageFormatPopup indexOfSelectedItem] == 0)
        [currentsavepanel setAllowedFileTypes:[NSArray arrayWithObjects:@"png",nil]];
    else
        [currentsavepanel setAllowedFileTypes:[NSArray arrayWithObjects:@"bmp",nil]];
}

- (IBAction) saveWorld: (id) sender
{
if (!processing)
{
NSSavePanel *panel = [NSSavePanel savePanel];

    [panel setTitle:@"Save World Image"];
    [panel setAllowedFileTypes:[NSArray arrayWithObjects:@"png",nil]];
    [panel setPrompt:@"Save Image"];
    currentsavepanel = panel;
    [panel setAccessoryView:imageFormat];

    if ([panel runModal] == NSOKButton)
    {
        // Make the task and send it off
        processingTask = [[NSTask alloc] init];

        // Tell the task where to find mcmap (it's in the resource folder of the bundle!)
        [processingTask setLaunchPath: mcmap_path];

        // Reuse the chunk argument list and add the stuff we want
        NSMutableArray* these_settings = [NSMutableArray arrayWithArray:render_settings];
        if ([[panel filename] hasSuffix: @"png"])
            [these_settings addObject:  @"-png"];
        [these_settings addObject:  @"-file"];
        [these_settings addObject:  [panel filename]  ];
        
        [processingTask setArguments: these_settings];
        [processingTask launch];
        
        // Disable the use interface and throw up the save message
        processing = YES;
        saveWorld = YES;
    }
}
}

- (void) saveChunkRange:(NSString*)savepath minx:(int)minx maxx:(int)maxx miny:(int)miny maxy:(int)maxy 
{
    // Make the task and send it off
    processingTask = [[NSTask alloc] init];

    // Tell the task where to find mcmap (it's in the resource folder of the bundle!)
    [processingTask setLaunchPath: mcmap_path];

    // Reuse the chunk argument list and add the stuff we want
    NSMutableArray* these_settings = [NSMutableArray arrayWithArray:render_settings];
    [these_settings addObject:@"-from"];
    [these_settings addObject:[NSString stringWithFormat:@"%i",minx]];
    [these_settings addObject:[NSString stringWithFormat:@"%i",miny]];
    [these_settings addObject:@"-to"];
    [these_settings addObject:[NSString stringWithFormat:@"%i",maxx]];
    [these_settings addObject:[NSString stringWithFormat:@"%i",maxy]];
    
    if ([savepath hasSuffix: @"png"])
        [these_settings addObject:  @"-png"];
    [these_settings addObject:  @"-file"];
    [these_settings addObject:  savepath  ];
    
    [processingTask setArguments: these_settings];
    [processingTask launch];
}

- (IBAction) saveSliceSequence:(id)sender
{
if (!processing){
    if (worldLoaded)
    {
        NSSavePanel *panel = [NSSavePanel savePanel];

        [panel setTitle:@"Save Slice Sequence"];
        [panel setAllowedFileTypes:[NSArray arrayWithObjects:@"png",nil]];
        [panel setPrompt:@"Save Sequence"];
        currentsavepanel = panel;
        [panel setAccessoryView:imageFormat];

        if ([panel runModal] == NSOKButton)
        {

            // Find the proper bounds
            // Screen Edges
            float zoom = exp(zoom_level);
            float left = camera.viewPos.x - 0.5*camera.viewWidth*zoom;
            float right = camera.viewPos.x + 0.5*camera.viewWidth*zoom;
            float top = camera.viewPos.y + 0.5*camera.viewHeight*zoom;
            float bottom = camera.viewPos.y - 0.5*camera.viewHeight*zoom;
            // Blocks at nearest screen edge
            int ul[2], ur[2], bl[2], br[2];
            screen2block(left, top, ul);
            screen2block(right, top, ur);
            screen2block(left, bottom, bl);
            screen2block(right, bottom, br);
            
            // These are a really loose bound on the visible blocks but they are easy to calculate.
            // They give us something to iterate over that isn't all blocks in the world.
            
            int minx = min(min(min(ul[0],ur[0]),bl[0]),br[0]);
            int maxx = max(max(max(ul[0],ur[0]),bl[0]),br[0])+2;
            int miny = min(min(min(ul[1],ur[1]),bl[1]),br[1])+1;
            int maxy = max(max(max(ul[1],ur[1]),bl[1]),br[1])+2;
            
            ul[0] = minx;
            ul[1] = miny;
            br[0] = maxx;
            br[1] = maxy;
            
            [self changeCoords:ul fromOrientation:orientation toOrientation:0];
            [self changeCoords:br fromOrientation:orientation toOrientation:0];
            slice_minx = (min(ul[0],br[0])-nox)*8;
            slice_maxx = (max(ul[0],br[0])-nox)*8;
            slice_miny = (min(ul[1],br[1])-noy)*8;
            slice_maxy = (max(ul[1],br[1])-noy)*8;
            
            slice_basename = [[[panel filename] substringToIndex: [[panel filename] length]-4] retain];
            
            processing = YES;
            saveChunk = YES;
            saveSliceSequence = YES;
            maxdepth = 0;
            
            // Note we don't actually do anything here! The checkProcessingTask function takes care of the actual functionality.
            
            }
        }
    }
}

- (IBAction) saveChunk: (id) sender
{                                  
if (!processing){   
    NSSavePanel *panel = [NSSavePanel savePanel];

    [panel setTitle:@"Save Image"];
    [panel setAllowedFileTypes:[NSArray arrayWithObjects:@"png",nil]];
    [panel setPrompt:@"Save Image"];
    currentsavepanel = panel;
    [panel setAccessoryView:imageFormat];

    if ([panel runModal] == NSOKButton)
    {

        // Find the proper bounds
        // Screen Edges
        float zoom = exp(zoom_level);
        float left = camera.viewPos.x - 0.5*camera.viewWidth*zoom;
        float right = camera.viewPos.x + 0.5*camera.viewWidth*zoom;
        float top = camera.viewPos.y + 0.5*camera.viewHeight*zoom;
        float bottom = camera.viewPos.y - 0.5*camera.viewHeight*zoom;
        // Blocks at nearest screen edge
        int ul[2], ur[2], bl[2], br[2];
        screen2block(left, top, ul);
        screen2block(right, top, ur);
        screen2block(left, bottom, bl);
        screen2block(right, bottom, br);
        
        // These are a really loose bound on the visible blocks but they are easy to calculate.
        // They give us something to iterate over that isn't all blocks in the world.
        
        int minx = min(min(min(ul[0],ur[0]),bl[0]),br[0]);
        int maxx = max(max(max(ul[0],ur[0]),bl[0]),br[0])+2;
        int miny = min(min(min(ul[1],ur[1]),bl[1]),br[1])+1;
        int maxy = max(max(max(ul[1],ur[1]),bl[1]),br[1])+2;
        
        ul[0] = minx;
        ul[1] = miny;
        br[0] = maxx;
        br[1] = maxy;
        
        [self changeCoords:ul fromOrientation:orientation toOrientation:0];
        [self changeCoords:br fromOrientation:orientation toOrientation:0];
        minx = (min(ul[0],br[0])-nox)*8;
        maxx = (max(ul[0],br[0])-nox)*8;
        miny = (min(ul[1],br[1])-noy)*8;
        maxy = (max(ul[1],br[1])-noy)*8;
        

        // Disable the use interface and throw up the save message
        processing = YES;
        saveChunk = YES;
        
        [self saveChunkRange:[panel filename] minx:minx maxx:maxx miny:miny maxy:maxy];        
    }
}
}

- (void) checkProcessingTask
{
    if (processingTask==Nil || ![processingTask isRunning])
    {
        // Clean up the processing task
        if (processingTask != Nil)
        {
            [processingTask release];
            processingTask = Nil;
        }
        
        // If this was a slice in the slice sequence, queue the next slice if needed.
        if (saveSliceSequence && maxdepth < 256)
        {
            maxdepth++;
            [statusTextField setTitleWithMnemonic: [NSString stringWithFormat: @"&Saving Slice %i of 256",maxdepth]];
            [self setupMapChunk];
            [self saveChunkRange:[NSString stringWithFormat:@"%@_%i.png",slice_basename,maxdepth] minx:slice_minx maxx:slice_maxx miny:slice_miny maxy:slice_maxy];
        }
        else 
        {
            if (extractBiome)
                [self finishGenerateBiomes];
            if (saveSliceSequence)
                [slice_basename release];
            processing = NO;
            saveSliceSequence = NO;
            saveWorld = NO;   
            saveChunk = NO;
            extractBiome = NO;
        }
    }
}

- (IBAction) flushCache: (id) sender
{
    if (!processing && worldLoaded )
    {
        // Clear out the map variable without resetting the view.
        [self resetForNewWorld:NO];
        
        // Rescan the world folder and rebuild the map variable
        [self scanAndInitWorld:current_world_path newBounds:YES];
        
        // Just in case, re-assign the mapchunk statics
        [self setupMapChunk];
        
        // Tell the window it needs a redraw
        [self setNeedsDisplay: YES];
    }
}

- (void) resetForNewWorld:(BOOL)setView
{
    // This function basically: 
        // Unloads the map (if needed)
        // Empties the scratch folder
        // Resets view (if directed)

    if (worldmap != NULL)
    {
        for(int i=0;i<nmx;i++)
        {
            for(int j=0; j<nmy;j++)
            {
                delete (worldmap[i+j*nmx]);
            }
        }
        free(worldmap);
        worldmap = NULL;
    }
    
    renderers.clear();

    // Empty the scratch folder.
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
    if (setView)
        [self resetView:nil];
}

- (void) setupMapChunk
{
    NSString* orientation_string = @"-east";
    if (orientation == 0) 
        orientation_string = @"-east";
    else if (orientation == 1) 
        orientation_string = @"-north";
    else if (orientation == 2) 
        orientation_string = @"-west";
    else if (orientation == 3) 
        orientation_string = @"-south";
    
    render_settings = [NSMutableArray arrayWithObjects:    current_world_path,
                                                    orientation_string,
                                                    nil ];
    if (noise_level > 0)
    {
        [render_settings addObject: @"-noise"];
        [render_settings addObject: [NSString stringWithFormat: @"%i",noise_level]];
    }
    
    if (showBiomes && dimension == 0)
        [render_settings addObject: @"-biomes"];
    
    if (dimension == 1) {
        [render_settings addObject: @"-nether"];
    } else if (dimension == 2) {
        [render_settings addObject: @"-end"];
    }
    
    [render_settings addObject: @"-height"];
    [render_settings addObject: [NSString stringWithFormat: @"%i",maxdepth]];
    
    if (slowblending)
        [render_settings addObject: @"-blendall"];
    
    if (lighting_mode == DAY)
        [render_settings addObject: @"-skylight"];
    else if (lighting_mode == TORCHLIGHT)
        [render_settings addObject: @"-night"];
    else if (lighting_mode == NIGHT)
    {
        [render_settings addObject: @"-night"];
        [render_settings addObject: @"-skylight"];
    }
    else if (lighting_mode == CAVE)
        [render_settings addObject: @"-cave"];
    if (!default_colors)
    {
        [render_settings addObject: @"-colors"];
        [render_settings addObject: colors_path];
    }
                                                    
    MapChunk::setupClass(renderingTexture, mcmap_path, temp_dir, render_settings);
}

- (IBAction) setDimensionToNether:(id)sender
{
    switch (dimension)
    {
        case 0: // If default, switch to Nether
            dimension = 1;
            [netherMenuItem setState:NSOnState];
            break;
        case 1: // If Nether, switch to default
            dimension = 0;
            [netherMenuItem setState:NSOffState];
            break;
        case 2: // If End, switch to Nether
            dimension = 1;
            [netherMenuItem setState:NSOnState];
            [endMenuItem setState:NSOffState];
            break;
    }
    
    if (worldLoaded)
    {
        [self resetForNewWorld:NO];
        [self scanAndInitWorld:current_world_path newBounds:YES];
        [self resetView:Nil];
        [self setupMapChunk];
    }
}

- (IBAction) setDimensionToEnd:(id)sender
{
    switch (dimension)
    {
        case 0: // If default, switch to End
            dimension = 2;
            [endMenuItem setState:NSOnState];
            break;
        case 1: // If Nether, switch to End
            dimension = 2;
            [endMenuItem setState:NSOnState];
            [netherMenuItem setState:NSOffState];
            break;
        case 2: // If End, switch to default
            dimension = 0;
            [endMenuItem setState:NSOffState];
            break;
    }
    
    if (worldLoaded)
    {
        [self resetForNewWorld:NO];
        [self scanAndInitWorld:current_world_path newBounds:YES];
        [self resetView:Nil];
        [self setupMapChunk];
    }
}

- (void) loadRenderDefaults
{
    NSUserDefaults *defaults;
    defaults = [NSUserDefaults standardUserDefaults];
    
    // Check if the defaults exist by testing for the default colors key
    
    if ([defaults objectForKey: @"colorsPath"]==Nil)
        [self resetRenderDefaults];
    [defaults synchronize];
    
    if ([defaults objectForKey: @"colorsPath"]!=Nil)
        colors_path = [defaults objectForKey:@"colorsPath"];
    default_colors = [defaults boolForKey:@"isDefaultColors"];
    orientation = [defaults integerForKey:@"orientation"];
    lighting_mode = (LightingMode)[defaults integerForKey:@"lightingMode"];
    noise_level = [defaults integerForKey:@"noiseLevel"];
    showBiomes = [defaults boolForKey:@"showBiomes"];
    
    if (showBiomes)
        [showBiomesMenuItem setState:NSOnState];
    
    // Check if the specified color_path even exists
    BOOL colors_exist = [[NSFileManager defaultManager] fileExistsAtPath:colors_path];
    
    if (!colors_exist)
        NSLog(@"The default colors.txt is missing!");
    
    if (default_colors || !colors_exist)
    {
        // If the user either has default colors up or their specified colors don't exist...
        colors_path = @"placeholder";
        [self setColors: Nil];
        [self setColors: defaultcolorsMenuItem];
        [defaultcolorsMenuItem setState: NSOnState];
    }
    else
    {
        // If the file did exist and we want to use it, we need to figure out which item to check
        [self setColors: Nil];
        
        // Scan for which item to check based on color_path
        // Honestly, no one will notice and this is not an easy problem.
    }
    
    // Setup the orientation, lighting mode, and noise level menu checkmarks.
    [self resetOrientationMenu];
    [self resetLightingModeMenu];
    [self resetNoiseLevelMenu];
    
    // Mode changed. Reset everything.
    [self setupMapChunk];
    if (worldLoaded)
    {
        [self invalidateAllChunks];
    }
    
}

- (void) setMaxSimultaneousRenders:(int)count
{
    MAX_SIMULTANEOUS_RENDERS = count;
    NSUserDefaults *defaults;
    defaults = [NSUserDefaults standardUserDefaults];
    [defaults setInteger:count forKey:@"maxRenders"];
    [defaults synchronize];
}

- (int) getMaxSimultaneousRenders
{
    return MAX_SIMULTANEOUS_RENDERS;
}

- (void) setRenderDefaults
{
    NSUserDefaults *defaults;
    defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject:colors_path forKey:@"colorsPath"];
    [defaults setBool:default_colors forKey:@"isDefaultColors"];
    [defaults setInteger:orientation forKey:@"orientation"];
    [defaults setInteger:lighting_mode forKey:@"lightingMode"];
    [defaults setInteger: noise_level forKey:@"noiseLevel"];
    [defaults setBool: showBiomes forKey:@"showBiomes"];
    [defaults synchronize];
}
- (void) resetRenderDefaults
{
    NSUserDefaults *defaults;
    defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject:@"placeholder" forKey:@"colorsPath"];
    [defaults setBool:YES forKey:@"isDefaultColors"];
    [defaults setInteger:0 forKey:@"orientation"];
    [defaults setInteger:UNIFORM forKey:@"lightingMode"];
    [defaults setInteger:0 forKey:@"noiseLevel"];
    [defaults setBool: NO forKey:@"showBiomes"];
    [defaults synchronize];
}

- (void) rescanWorldsMenu
{
    BOOL isdir;
    BOOL isdir2;
    BOOL isdir3;
    
    // Clear out the worlds menu
    for(int i = ([worldsMenu numberOfItems]-1); i>-1; i--)
        [worldsMenu removeItemAtIndex:i];
    [mcWorlds removeAllObjects];
    
    // Scan the worlds folder
    NSFileManager* fm = [[[NSFileManager alloc] init] autorelease];
    NSString* worldspath = [@"~/Library/Application Support/minecraft/saves/" stringByExpandingTildeInPath];
    if ([fm fileExistsAtPath:worldspath isDirectory:&isdir] && isdir)
        [fm changeCurrentDirectoryPath:worldspath];
    NSArray* possibleWorlds = [fm contentsOfDirectoryAtPath:worldspath error:nil];
    NSMenuItem *worlditem;
    for(int i=0; i<[possibleWorlds count]; i++)
    {
        NSString* possibleWorld = [possibleWorlds objectAtIndex:i];
        
        if(     [fm fileExistsAtPath:possibleWorld isDirectory:&isdir] && isdir 
            &&  [fm fileExistsAtPath:[NSString stringWithFormat:@"%@/region",possibleWorld] isDirectory:&isdir2] && isdir2
            &&  [fm fileExistsAtPath:[NSString stringWithFormat:@"%@/level.dat",possibleWorld] isDirectory:&isdir3] && !isdir3 )
        {
            [mcWorlds addObject:[NSString stringWithFormat:@"%@/%@",worldspath,possibleWorld]];
            worlditem = [[NSMenuItem alloc] initWithTitle:[[possibleWorld componentsSeparatedByString:@"/"] lastObject] action:@selector(openWorld:) keyEquivalent:@""]; 
            [worlditem setTarget:self];
            [worldsMenu addItem:worlditem];
        }
    }
}

- (void) rescanColorsMenu
{
    NSMenuItem *coloritem;
        
    // Clear out the colors menu
    int total_items = [colorsMenu numberOfItems];
    for (int i=(total_items-1); i>0; i--)
    {
            coloritem = [colorsMenu itemAtIndex:i];
            [colorsMenu removeItemAtIndex:i];
            if (![coloritem isSeparatorItem])
                [coloritem release];
    }
    
    // Fill the colors menu.
    NSFileManager* fm = [[[NSFileManager alloc] init] autorelease];
    NSDirectoryEnumerator* en = [fm enumeratorAtPath:[ NSString stringWithFormat:@"%@/Colors/",[ [ NSBundle mainBundle ] resourcePath ]]];    
    NSError* err = nil;
    NSString* file;
    
    // Place the Default colors option
    coloritem = [[NSMenuItem alloc] initWithTitle:@"Default Colors" action:@selector(setColors:) keyEquivalent:@""]; 
    defaultcolorsMenuItem = coloritem;
    [coloritem setTarget:self];
    [colorsMenu addItem:coloritem];
    
    bool any = false;
    while (file = [en nextObject]) 
    {
        if([file hasSuffix:@".txt"])
        {
            if (!any)
            {
                [colorsMenu addItem:[NSMenuItem separatorItem]];
                any = true;
            }
            coloritem = [[NSMenuItem alloc] initWithTitle:[file substringToIndex:[file length] - 4] action:@selector(setColors:) keyEquivalent:@""]; 
            [coloritem setTag:1];
            [coloritem setTarget:self];
            [colorsMenu addItem:coloritem];
        }
        
        if (err) {
            NSLog(@"Color set moved: %@", err);
        }
    }
    
    err = nil;
    en = [fm enumeratorAtPath:[@"~/Library/Application Support/MCMap Live/" stringByExpandingTildeInPath]];
    
    any = false;
    while (file = [en nextObject]) 
    {
        if([file hasSuffix:@".txt"])
        {
            if (!any)
            {
                [colorsMenu addItem:[NSMenuItem separatorItem]];
                any = true;
            }
            
            coloritem = [[NSMenuItem alloc] initWithTitle:[file substringToIndex:[file length] - 4] action:@selector(setColors:) keyEquivalent:@""]; 
            [coloritem setTag:2];
            [coloritem setTarget:self];
            [colorsMenu addItem:coloritem];

        }
        
        if (err) {
            NSLog(@"Color set moved: %@", err);
        }
    }
    
    [colorsMenu addItem:[NSMenuItem separatorItem]];
    
    // Place the Import Color Set item
    //coloritem = [[NSMenuItem alloc] initWithTitle:@"Import Color Set..." action:@selector(setColors:) keyEquivalent:@""]; 
    //defaultcolorsMenuItem = coloritem;
    //[coloritem setTarget:self];
    //[colorsMenu addItem:coloritem];
    
    // Place the Try Colors item
    coloritem = [[NSMenuItem alloc] initWithTitle:@"Try Color Set..." action:@selector(setColors:) keyEquivalent:@""]; 
    customcolorsMenuItem = coloritem;
    [coloritem setTarget:self];
    [colorsMenu addItem:coloritem];
}

- (void) awakeFromNib
{
    //[NSApp setDelegate:self];

    // Default Settings
	show_players = 1;
	

    
    // Setup the paths we need to know
    mcmap_path = [ NSString stringWithFormat:@"%@/%s",[ [ NSBundle mainBundle ] resourcePath ],"mcmap" ];
    temp_dir = @"/tmp/mcmap/";
    default_colors = YES;
    mcWorlds = [[NSMutableArray alloc] init];
    
    [self rescanColorsMenu];
    [self rescanWorldsMenu];

    // We should update our drawing whenever a task complete notification comes in
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(chunkDidRender:) name:NSTaskDidTerminateNotification object:nil];

	// start animation timer	
	timer = [NSTimer timerWithTimeInterval:(1.0f/20.0f) target:self selector:@selector(animationTimer:) userInfo:nil repeats:YES];
	[[NSRunLoop currentRunLoop] addTimer:timer forMode:NSDefaultRunLoopMode];
	[[NSRunLoop currentRunLoop] addTimer:timer forMode:NSEventTrackingRunLoopMode]; // ensure timer fires during resize

    // So why both the timer to poll and the notifications?
    
    // Well, 10.6 often ignores NSTask notifications and 10.5 often ignores timers.
    // So who cares, they're both light weight, and they both only _request_ a redraw.


    // And LASTLY, load the user defaults:
    [self loadRenderDefaults];
    
    /*
    NSUserDefaults *defaults;
    defaults = [NSUserDefaults standardUserDefaults];
    MAX_SIMULTANEOUS_RENDERS = [defaults integerForKey:@"maxRenders"];
    if (MAX_SIMULTANEOUS_RENDERS == 0)
        [self setMaxSimultaneousRenders:4];
        
    */
    
}

- (void)chunkDidRender:(NSNotification *)aNotification
{
    //NSLog(@"Chunk complete");
    [self setNeedsDisplay: YES];
}

@end

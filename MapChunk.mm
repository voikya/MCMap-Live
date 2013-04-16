/*
 *  MapChunk.mm
 *  MCMap Live
 *
 *  Created by DK on 10/13/10.
 *
 */

#include "MapChunk.h"

GLuint MapChunk::loadingTexture; // The OpenGL id of the texture for that wireframe block.
NSString* MapChunk::mcmap_path; // The location of the mcmap binary
NSString* MapChunk::temp_path; // Where to put and look for the bitmaps
NSArray* MapChunk::render_settings; // colors.txt, lighting mode, facing direction, 

int getBaseLod(float zoom)
{
    if (zoom > 32)
        return 5;
    else if (zoom > 16)
        return 4;
    else if (zoom > 8)
        return 3;
    else if (zoom > 4)
        return 2;
    else if (zoom > 2)
        return 1;
    else
        return 0;
}

// Setup all the class vars
MapChunk::MapChunk(int bx, int by)
{
    x = bx;
    y = by;
    for(int i=0; i<6;i++)
        texture[i] = 0;
    onDisk = false;
    isBlank = false;
    blankChecked = false;
    renderer = Nil;
    needsRender = true;
    invalid = false;
}

// Make sure the renderer is done and cleaned up, delete all textures, delete files on disk.
MapChunk::~MapChunk()
{
    // Make sure renderer is done and deallocate it if it exists.
    
    // Delete textures from VRAM
    deleteAllTextures();
    
    /*
    if (renderer != Nil)
    {
        [renderer waitUntilExit];
        [renderer release];
    }
    */
    
    // Delete on disk too
}

void MapChunk::setBlank()
{
    isBlank = true;
    blankChecked = true;
}

void MapChunk::reset()
{
    // It's far easier to invalidate the texture before reset, since that code
    // knows how to deal with the mid-render situations.
    invalidate();
    deleteAllTextures();
    onDisk = false;
    // isBlank = false; // A blank chunk is forever blank, from any angle, for any reason.
    // blankChecked = false;
    renderer = Nil;
    needsRender = true;
    invalid = false;
}

NSString* MapChunk::getFilename()
{
    return [NSString stringWithFormat:@"%@%@", temp_path, [NSString stringWithFormat:@"chunk_%i_%i.png",x,y]];
}

// Load this texture from disk place it in the appropriate LOD slots
bool MapChunk::loadTextureFromDisk(int minLOD, int maxLOD)
{
    NSBitmapImageRep *theImage;
    int width, height, dest_width, dest_height, bytesPRow;
    unsigned char *fixedImageData;
    
    // Load the image into an NSBitmapImageRep
    theImage = [ NSBitmapImageRep imageRepWithContentsOfFile:getFilename() ];
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
        CGColorSpaceRef color_space = CGColorSpaceCreateDeviceRGB();
        
        for (int lod = minLOD; lod<=maxLOD; lod++)
        {
            // Does this texture even need to be loaded?
            if ((texture[lod] == 0) && (!isBlank))
            {
                //Set up a Core Graphics context that's compatible with OpenGL's RGBA
                dest_width = 512 / pow(2,lod);
                dest_height = 512 / pow(2,lod);
                fixedImageData = (unsigned char*)calloc(dest_width * 4, dest_height);
                CGContextRef myBitmapContext = CGBitmapContextCreate(
                                                     fixedImageData,                // pointer raw storage
                                                     dest_width,                         // the width of the context
                                                     dest_height,                        // the height of the context
                                                     8,                             // bits per pixel
                                                     dest_width*4,                       // bytes per row
                                                     color_space,                   // what color space to use
                                                     kCGImageAlphaPremultipliedLast // the format of the alpha channel
                                                     );
                // Ok, so this shit is weird. The exported images are 522x522, so there's these bullshit 10 pixels that need to be trimmed off.
                //CGContextSetInterpolationQuality(myBitmapContext,kCGInterpolationNone);
                CGContextDrawImage(myBitmapContext, CGRectMake(-5.0f/ pow(2,lod),-5.0f/ pow(2,lod),float(width)/pow(2,lod),float(height)/pow(2,lod)), image);
                
                /*
                if (!blankChecked)
                {

                    for(int j=0;j<dest_height;j++)
                        {
                        for(int i=0;i<(dest_width*4);i++)
                        {
                            if (fixedImageData[i+(j*dest_width*4)] != 0)
                            {
                                blankChecked = true;
                                isBlank = false;
                                break;
                            }
                        }
                        if (blankChecked)
                            break;
                    }
                    if (!blankChecked)
                    {
                        blankChecked = true;
                        isBlank = true;
                    }
                }
                */
                
                if (!isBlank)
                {
                    glEnable(GL_TEXTURE_2D);
                    glGenTextures(1,texture+lod);
                    glBindTexture(GL_TEXTURE_2D, texture[lod]);
                    glTexParameteri( GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE );
                    glTexParameteri( GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE );
                    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
                    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
                    glTexImage2D(GL_TEXTURE_2D, 0, 4, dest_width, dest_height, 0, GL_RGBA, GL_UNSIGNED_BYTE, fixedImageData);
                }
                // Release the stuff we allocated
                CGContextRelease(myBitmapContext);
                free(fixedImageData);
            }
        }
        // Release the rest
        CGColorSpaceRelease(color_space);
        //CGImageRelease(masked_image);
    } else {
        // The image was not found, which is really weird.
        // This shouldn't happen unless mcmap breaks...
        NSLog(@"File not found: %@",getFilename());
        return false;
    }
    return true;
}

// Try to change the LOD by reading out a texture and scaling it. Fall back to loadTexture to upres.
bool MapChunk::loadTextureFromVRAM(int minLOD, int maxLOD)
{
    // Find lowest LOD.
    int i;
    for (i=0;i<6;i++)
    {
        if (texture[i] != 0)
            break;
    }
    if (i > minLOD)
        return false;
    
    // There is a LOD available in VRAM that's good enough for what we need.
    // Load it into an array.
    
    int width = 512/pow(2,i);
    int height = 512/pow(2,i);
    
    unsigned char *image = (unsigned char*)calloc(width * 4, height);
    glBindTexture(GL_TEXTURE_2D, texture[i]);
    glGetTexImage( GL_TEXTURE_2D, 0, GL_RGBA, GL_UNSIGNED_BYTE, image );
    
    // Create a data provider from which we can make a CGImage
    // Arguments are: Callback parameter pointer, data pointer, data size, and callback function pointer.
    // Clearly we are not using the callback here.
    CGDataProviderRef imageProvider = CGDataProviderCreateWithData( NULL, image, 512/pow(2,i) * 4 * 512/pow(2,i), NULL);
    CGColorSpaceRef color_space = CGColorSpaceCreateDeviceRGB();
    CGImageRef imageCG = CGImageCreate (
                                           width,           //size_t width,
                                           height,          //size_t height,
                                           8,               //size_t bitsPerComponent,
                                           32,              //size_t bitsPerPixel,
                                           4*width,         //size_t bytesPerRow, 
                                           color_space,     //CGColorSpaceRef colorspace,
                                           kCGImageAlphaPremultipliedLast, //CGBitmapInfo bitmapInfo,
                                           imageProvider,   //CGDataProviderRef provider,
                                           NULL,            //const CGFloat decode[],
                                           true,            //bool shouldInterpolate,
                                           kCGRenderingIntentDefault   //CGColorRenderingIntent intent
                                                                            );
    
    // Now we have a CGImage ripped straight from the VRAM which we can shrink and load into a texture of its own!
    for (int lod = i; lod<=maxLOD; lod++)
    {   
        // Make sure this texture even needs to be loaded.
        if (texture[lod] == 0)
        {
            //Set up a Core Graphics context that's compatible with OpenGL's RGBA
            int dest_width = 512 / pow(2,lod);
            int dest_height = 512 / pow(2,lod);
            unsigned char* fixedImageData = (unsigned char*)calloc(dest_width * 4, dest_height);
            CGContextRef myBitmapContext = CGBitmapContextCreate(
                             fixedImageData,                // pointer raw storage
                             dest_width,                         // the width of the context
                             dest_height,                        // the height of the context
                             8,                             // bits per pixel
                             dest_width*4,                       // bytes per row
                             color_space,                   // what color space to use
                             kCGImageAlphaPremultipliedLast // the format of the alpha channel
                             );
            // This turns on nearest neightbor for mipmaps
            //CGContextSetInterpolationQuality(myBitmapContext,kCGInterpolationNone);
            CGContextDrawImage(myBitmapContext, CGRectMake(0,0, dest_width, dest_height), imageCG);
            
            glEnable(GL_TEXTURE_2D);
            glGenTextures(1,texture+lod);
            glBindTexture(GL_TEXTURE_2D, texture[lod]);
            glTexParameteri( GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE );
            glTexParameteri( GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE );
            glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
            glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
            glTexImage2D(GL_TEXTURE_2D, 0, 4, dest_width, dest_height, 0, GL_RGBA, GL_UNSIGNED_BYTE, fixedImageData);
            
            // Release the stuff we allocated
            CGContextRelease(myBitmapContext);
            free(fixedImageData);
        }
    }

    CGColorSpaceRelease(color_space);
    CGImageRelease(imageCG);
    CGDataProviderRelease (imageProvider);
    free(image);
    
    return true;
} 

// Remove all the textures from VRAM
void MapChunk::deleteAllTextures()
{
    // Release the textures from OpenGL
    for(int i=0; i<6;i++)
    {
        if (texture[i] != 0)
        {
            glDeleteTextures(1,texture+i);
            texture[i] = 0;
        }
    }
}

// Remove textures from VRAM
void MapChunk::deleteTextures(int minLOD,int maxLOD)
{
    // Release the textures from OpenGL
    for(int i=minLOD; i<=maxLOD;i++)
    {
        if (texture[i] != 0)
        {
            glDeleteTextures(1,texture+i);
            texture[i] = 0;
        }
    }
}

// Remove the render from disk. This resets onDisk.
void MapChunk::deleteOnDisk()
{
    [[NSFileManager defaultManager] removeItemAtPath:getFilename() error:nil];
}

// Keep everything but mark the texture as invalid. Get ready to be rendered again.
void MapChunk::invalidate()
{
    // Trivial case: the texture is blank
    if (isBlank)
        return; // Nothing to do
    
    // Special case: the renderer is running right now
    if (renderer!=Nil) // If the texture was already invalid, this is fine too.
    {
        [renderer terminate];
        //[renderer waitUntilExit];
        [renderer release];
        renderer = Nil;
    }
    
    // Put the object in a state where it will re-render.
    onDisk = false;
    needsRender = true;
    invalid = true; // Lets the draw code know to use only VRAM 
                    // (and reset VRAM once the texture is available on disk)
}

// Return the appropriate texture ID for this block based on zoom. Don't do any LOD changes or load from disk if canUpdate is false.
GLuint MapChunk::getTexture(float zoom, bool canUpdate, int &update_counter)
{
    // If the texture is blank, return zero. The view will know not to draw anything.
    if (isBlank)
        return 0;
    
    // If the texture isn't on disk yet, stop.
    // Unless we're invalid in which case check the VRAM for
    // possibly acceptable data.
    //if (!onDisk)
    //    return loadingTexture;
    
    // If the texture is invalid but done rendering, clear it from VRAM.
    if (invalid && onDisk && canUpdate)
    {
        deleteAllTextures();
        invalid = false;
    }
    
    int lod = getBaseLod(zoom);
    
    // If the texture is not available in our zoom level...
    if (texture[lod] == 0)
    {
        // Try to load it from a higher-res texture already loaded (which we should probably delete!)
        if (loadTextureFromVRAM(lod,lod))
        {   
            // Delete the higher res copies.
            deleteTextures(0,lod-1);
            update_counter++;
            return texture[lod];
        }
        
        // If we can update, load what we need from disk.
        if (canUpdate && onDisk && !invalid)
        {   
             if (!loadTextureFromDisk(lod,lod))
             {
                // If we failed to load from disk for some reason, uh... oh no.
                NSLog(@"Bad state in MapChunk. Marking chunk as invalid.");
                invalidate();
                return loadingTexture;
            }
            else 
            {
                // Alright, the texture loaded from disk. Return it.
                update_counter = update_counter+5;
                return texture[lod];
            }
        }
        else
        {
            // OK, so we don't have the textures we need and we can't update.
            // Are there any textures we can use at all even if they're invalid or low res?
            for(int i=0;i<6;i++)
            {
                if(texture[i] != 0)
                    return texture[i];
            }
            
            // Ok, nothing at all is available.
            return loadingTexture;
        }
    }
    else 
    {
        return texture[lod];
    }

    // And then the catch-all, should any unhandled case arrise.
    return loadingTexture;
}

// Create the NSTask needed to render this block's texture and launch it.
void MapChunk::startRenderer()
{
    if (!onDisk && renderer == Nil)
    {
        needsRender = false;
        // Now we should fire off an event to render the chunk we need.
        // Make a new NSTask and throw it on the renderers dictionary.
        renderer = [[NSTask alloc] init];
        
        // Tell the task where to find mcmap (it's in the resource folder of the bundle!)
        [renderer setLaunchPath:mcmap_path];
        
        // Create the arguments and add the file path to it.
        NSMutableArray* these_settings = [NSMutableArray arrayWithArray:render_settings];
        [these_settings addObject:  @"-from"];
        [these_settings addObject:  [NSString stringWithFormat:@"%i",x]];
        [these_settings addObject:  [NSString stringWithFormat:@"%i",y]];
        [these_settings addObject:  @"-to"];
        [these_settings addObject:  [NSString stringWithFormat:@"%i",x+7]];
        [these_settings addObject:  [NSString stringWithFormat:@"%i",y+7]];
        [these_settings addObject:  @"-png"];
        [these_settings addObject:  @"-file"];
        [these_settings addObject:  getFilename()  ];
        
        // Setup the renderer
        [renderer setArguments: these_settings];
        // Make certain output goes to null
//      [renderer setStandardOutput: [NSFileHandle fileHandleWithNullDevice]];
//		[renderer setStandardError: [NSFileHandle fileHandleWithNullDevice]];

        
        
        // And launch it
        [renderer launch];
    }
}

bool MapChunk::renderIsDone()
{
    if ([renderer isRunning])
        return false;
    
    onDisk = true;
    [renderer release];
    renderer = Nil;
    return true;
}

// If the NSTask is done, set onDisk and return true. Else, return false.
int MapChunk::checkRenderer()
{
    if (needsRender)
        return 0;
    return 1;
}

// Returns true if the chunk is visible onscreen and needs to be drawn. If isBlank, then is always false.
bool MapChunk::isVisible(float left, float right, float top, float bottom, float zoom)
{
    if (isBlank)
        return false;
        
    // Perform real checks here eventually
    return true;
    
    /*
    
    - (BOOL) blockIsVisibleX:(int)bx Y:(int)by
{
    // Check each corner of the block and make sure its screen position
    float ul[2], ur[2], bl[2], br[2];
    float zoom = exp(zoom_level);
    float blocksize = 522;
    
    // Screen Edges
    float left = camera.viewPos.x - (0.5*camera.viewWidth+blocksize)*zoom;
    float right = camera.viewPos.x + (0.5*camera.viewWidth+blocksize)*zoom;
    float top = camera.viewPos.y + (0.5*camera.viewHeight+blocksize)*zoom;
    float bottom = camera.viewPos.y - (0.5*camera.viewHeight+blocksize)*zoom;
    
    block2screen(bx,by,ul);
    block2screen(bx+8,by,ur);
    block2screen(bx,by+8,bl);
    block2screen(bx+8,by+8,br);
    
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
    
    */
    
    
} 

// Setup the class with the strings and values it needs to function.
void MapChunk::setupClass(GLuint loadingTexture, NSString *mcmap_path, NSString *temp_path, NSArray *render_settings)
{
    MapChunk::loadingTexture = loadingTexture;
    MapChunk::mcmap_path = [mcmap_path retain];
    MapChunk::temp_path = [temp_path retain];
    MapChunk::render_settings = [render_settings retain];
}


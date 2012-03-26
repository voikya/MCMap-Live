/*
 *  MapChunk.h
 *  MCMap Live
 *
 *  Created by DK on 10/13/10.
 *
 */

#include <OpenGL/OpenGL.h>
#include <OpenGL/gl.h>
#include <OpenGL/glu.h>
#include <OpenGL/glext.h>
#import <ApplicationServices/ApplicationServices.h>

class MapChunk
{
    private:
        static GLuint loadingTexture; // The OpenGL id of the texture for that wireframe block.
        static NSString* mcmap_path; // The location of the mcmap binary
        static NSString* temp_path; // Where to put and look for the bitmaps
        static NSArray* render_settings; // colors.txt, lighting mode, facing direction, 

        bool loadTextureFromDisk(int minLOD, int maxLOD); // Load this texture from disk place it in the appropriate LOD slots
        bool loadTextureFromVRAM(int minLOD, int maxLOD); // Try to change the LOD by reading out a texture and scaling it. Fall back to loadTexture to upres.
        void deleteTextures(int minLOD, int maxLOD); // Remove all the textures from VRAM
        void deleteOnDisk(); // Remove the render from disk. This resets onDisk.
        NSString* getFilename(); // Get the filename of the on-disk texture
        
        int x,y;
        GLuint texture[6];
        bool onDisk;    // The texture has been rendered and is on the disk
        bool blankChecked;   // The texture is totally blank and need not be rendered
        bool isBlank;   // The texture is totally blank and need not be rendered
        NSTask* renderer;
        bool needsRender;
        bool invalid;

    public:
        MapChunk(int bx, int by); // Setup with a temp texture, init variables.
        ~MapChunk(); // Make sure the renderer is done and cleaned up, delete all textures, delete files on disk.
        static void setupClass(GLuint, NSString*, NSString*, NSArray*); // Setup the class with the strings and values it needs to function.
        GLuint getTexture(float zoom, bool canUpdate, int &update_counter); // Return the appropriate texture ID for this block based on zoom. Don't do any LOD changes or load from disk if canUpdate is false.
        void startRenderer(); // Create the NSTask needed to render this block's texture and launch it.
        int checkRenderer(); // 0 = Needs running, 1 = running, 2 = done
        void deleteAllTextures(); // Remove all the textures from VRAM
        bool isVisible(float left, float right, float top, float bottom, float zoom); // Returns true if the chunk is visible onscreen and needs to be drawn. If isBlank, then is always false.
        bool renderIsDone();
        void invalidate(); // Keep everything but mark the texture as invalid. Get ready to be rendered again.
        void reset(); // Delete the textures out of memory and act like a new, unrendered chunk.
        void setBlank();
};
/*
 *  extractcolors.h
 *  MCMap Live
 *
 *  Created by DK on 10/18/10.
 *
 */


// This beast of an array maps block IDs to tile locations in terrain.png
// The tile x and tile y are 0-index. A value of -1,-1 means no tile exists
// Extra alpha multiplier is there for textures that are shared and might need to
// be lighter for one use than another.
//                                  { tile x, tile y, extra alpha multiplier)
const int special_sauce[MINECRAFT_TILE_COUNT][3] = 
                                 {  {	-1,	-1,	255	},	// AIR 0
                                    {	1,	0,	255	},	// STONE 1
                                    {	0,	0,	255	},	// GRASS 2
                                    {	2,	0,	255	},	// DIRT 3
                                    {	0,	1,	255	},	// COBBLESTONE 4
                                    {	4,	0,	255	},	// WOOD 5
                                    {	15,	0,	255	},	// SAPLING 6
                                    {	1,	1,	255	},	// BEDROCK 7
                                    {	15,	12,	255	},	// WATER 8
                                    {	15,	12,	255	},	// STILLWATER 9
                                    {	15,	14,	255	},	// LAVA 10
                                    {	15,	14,	255	},	// STILLLAVA 11
                                    {	2,	1,	255	},	// SAND 12
                                    {	3,	1,	255	},	// GRAVEL 13
                                    {	0,	2,	255 },	// GOLDORE 14
                                    {	1,	2,	255	},	// IRONORE 15
                                    {	2,	2,	255	},	// COALORE 16
                                    {	4,	1,	255	},	// TREE 17
                                    {	5,	3,	255	},	// LEAVES 18
                                    {	0,	3,	255	},	// SPONGE 19
                                    {	1,	3,	0.2*255	},	// GLASS 20
                                    {	0,	10,	255	},	// LAPIS LAZULI ORE
                                    {	0,	9,	255	},	// LAPIS LAZULI BLOCK
                                    {	13,	2,	255	},	// DISPENSER
                                    {	0,	12,	255	},	// SANDSTONE
                                    {	10,	4,	255	},	// NOTE BLOCK
                                    {	-1,	-1,	255	},	
                                    {	-1,	-1,	255	},	
                                    {	-1,	-1,	255	},	
                                    {	-1,	-1,	255	},	
                                    {	-1,	-1,	255	},	
                                    {	-1,	-1,	255	},	
                                    {	-1,	-1,	255	},	
                                    {	-1,	-1,	255	},	
                                    {	-1,	-1,	255	},	
                                    {	0,	4,	255	},	// WHITE WOOL 35
                                    {	-1,	-1,	255	},	
                                    {	13,	0,	255	},	// FLOWER 37
                                    {	12,	0,	255	},	// ROSE 38
                                    {	13,	1,	255	},	// BROWNMUSHROOM 39
                                    {	12,	1,	255	},	// REDMUSHROOM 40
                                    {	7,	2,	255	},	// GOLDBLOCK 41
                                    {	6,	2,	255	},	// IRONBLOCK 42
                                    {	5,	0,	255	},	// DOUBLE 43
                                    {	5,	0,	255	},	// STAIR 44
                                    {	7,	0,	255	},	// BRICKBLOCK 45
                                    {	8,	0,	255	},	// TNT 46
                                    {	3,	2,	255	},	// BOOKSHELF 47
                                    {	4,	2,	255	},	// MOSSY 48
                                    {	5,	2,	255	},	// OBSIDIAN 49
                                    {	0,	5,	255	},	// TORCH 50
                                    {	15,	15,	0.3*255	},	// FIRE 51
                                    {	1,	4,	255	},	// MOB 52
                                    {	4,	0,	255	},	// WOODSTAIRS 53
                                    {	11,	1,	255	},	// CHEST 54
                                    {	4,	6,	255	},	// REDSTONE 55
                                    {	2,	3,	255	},	// DIAMONDORE 56
                                    {	8,	2,	255	},	// DIAMONDBLOCK 57
                                    {	12,	3,	255	},	// WORKBENCH 58
                                    {	15,	5,	255	},	// CROP 59
                                    {	7,	5,	255	},	// SOIL 60
                                    {	12,	2,	255	},	// FURNACE 61
                                    {	13,	3,	255 },	// LITFURNACE 62
                                    {	0,	0,	255	},	// SIGNPOST 63
                                    {	1,	6,	255	},	// WOODDOORBLOCK 64
                                    {	3,	5,	255	},	// LADDER 65
                                    {	0,	8,	255	},	// RAILS 66
                                    {	0,	1,	255	},	// STONESTAIRS 67
                                    {	4,	0,	255	},	// SIGNTOP 68
                                    {	3,	6,	255	},	// LEVER 69
                                    {	0,	6,	255	},	// ROCKPLATE 70
                                    {	2,	6,	255	},	// IRONDOOR 71
                                    {	4,	0,	255	},	// WOODPLATE 72
                                    {	3,	3,	255	},	// REDSTONEORE1 73
                                    {	3,	3,	255	},	// REDSTONEORE2 74
                                    {	3,	7,	255	},	// REDSTONETORCH1 75
                                    {	3,	6,	255	},	// REDSTONETORCH2 76
                                    {	2,	6,	0.1*255	},	// BUTTON 77
                                    {	2,	4,	255	},	// SNOW 78
                                    {	3,	4,	255	},	// ICE 79
                                    {	2,	4,	255	},	// SNOWBLOCK 80
                                    {	6,	4,	255	},	// CACTUS 81
                                    {	8,	4,	255	},	// CLAYBLOCK 82
                                    {	9,	4,	255	},	// REEDBLOCK 83
                                    {	10,	4,	255	},	// JUKEBOX 84
                                    {	5,	1,	0.6*255	},	// FENCE 85
                                    {   6,  7,  255   },  // PUMPKIN 86
                                    {   7,  6,  255   },  // BLOODSTONE 87
                                    {   8,  6,  255   },  // SLOW SAND 88
                                    {   9,  6,  255   },  // LIGHTSTONE 89
                                    {   14, 0,  255   },  // PORTAL 90
                                    {   8,  7,  255   },  // GLOWING PUMPKIN 91
                                    {   9,  7,  255   },  // CAKE 92
                                    {	-1,	-1,	255	},
                                    {	-1,	-1,	255	},	
                                    {	-1,	-1,	255	},	
                                    {	-1,	-1,	255	},	
                                    {	-1,	-1,	255	},	
                                    {	-1,	-1,	255	},	
                                    {	-1,	-1,	255	},	
                                    {	-1,	-1,	255	},	
                                    {	-1,	-1,	255	},	
                                    {	-1,	-1,	255	},	
                                    {	-1,	-1,	255	},	
                                    {	-1,	-1,	255	},	
                                    {	-1,	-1,	255	},	
                                    {	-1,	-1,	255	},	
                                    {	-1,	-1,	255	},	
                                    {	-1,	-1,	255	},	
                                    {	-1,	-1,	255	},	
                                    {	-1,	-1,	255	},	
                                    {	-1,	-1,	255	},	
                                    {	-1,	-1,	255	},	
                                    {	-1,	-1,	255	},	
                                    {	-1,	-1,	255	},	
                                    {	-1,	-1,	255	},	
                                    {	-1,	-1,	255	},	
                                    {	-1,	-1,	255	},	
                                    {	-1,	-1,	255	},	
                                    {	-1,	-1,	255	},	
                                    {	-1,	-1,	255	},	
                                    {	-1,	-1,	255	},	
                                    {	-1,	-1,	255	},	
                                    {	-1,	-1,	255	},	
                                    {	-1,	-1,	255	},	
                                    {	-1,	-1,	255	},	
                                    {	-1,	-1,	255	},	
                                    {	-1,	-1,	255	},	
                                    {	-1,	-1,	255	},	
                                    {	-1,	-1,	255	},	
                                    {	-1,	-1,	255	},	
                                    {	-1,	-1,	255	},	
                                    {	-1,	-1,	255	},	
                                    {	-1,	-1,	255	},	
                                    {	-1,	-1,	255	},	
                                    {	-1,	-1,	255	},	
                                    {	-1,	-1,	255	},	
                                    {	-1,	-1,	255	},	
                                    {	-1,	-1,	255	},	
                                    {	-1,	-1,	255	},	
                                    {	-1,	-1,	255	},	
                                    {	-1,	-1,	255	},	
                                    {	-1,	-1,	255	},	
                                    {	-1,	-1,	255	},	
                                    {	-1,	-1,	255	},	
                                    {	-1,	-1,	255	},	
                                    {	-1,	-1,	255	},	
                                    {	-1,	-1,	255	},	
                                    {	-1,	-1,	255	},	
                                    {	-1,	-1,	255	},	
                                    {	-1,	-1,	255	},	
                                    {	-1,	-1,	255	},	
                                    {	-1,	-1,	255	},	
                                    {	-1,	-1,	255	},	
                                    {	-1,	-1,	255	},	
                                    {	-1,	-1,	255	},	
                                    {	-1,	-1,	255	},	
                                    {	-1,	-1,	255	},	
                                    {	-1,	-1,	255	},	
                                    {	-1,	-1,	255	},	
                                    {	-1,	-1,	255	},	
                                    {	-1,	-1,	255	},	
                                    {	-1,	-1,	255	},	
                                    {	-1,	-1,	255	},	
                                    {	-1,	-1,	255	},	
                                    {	-1,	-1,	255	},	
                                    {	-1,	-1,	255	},	
                                    {	-1,	-1,	255	},	
                                    {	-1,	-1,	255	},	
                                    {	-1,	-1,	255	},	
                                    {	-1,	-1,	255	},	
                                    {	-1,	-1,	255	},	
                                    {	-1,	-1,	255	},	
                                    {	-1,	-1,	255	},	
                                    {	-1,	-1,	255	},	
                                    {	-1,	-1,	255	},	
                                    {	-1,	-1,	255	},	
                                    {	-1,	-1,	255	},	
                                    {	-1,	-1,	255	},	
                                    {	-1,	-1,	255	},	
                                    {	-1,	-1,	255	},	
                                    {	-1,	-1,	255	},	
                                    {	-1,	-1,	255	},	
                                    {	-1,	-1,	255	},	
                                    {	-1,	-1,	255	},	
                                    {	-1,	-1,	255	},	
                                    {	-1,	-1,	255	},	
                                    {	-1,	-1,	255	},	
                                    {	-1,	-1,	255	},	
                                    {	-1,	-1,	255	},	
                                    {	-1,	-1,	255	},	
                                    {	-1,	-1,	255	},	
                                    {	-1,	-1,	255	},	
                                    {	-1,	-1,	255	},	
                                    {	-1,	-1,	255	},	
                                    {	-1,	-1,	255	},	
                                    {	-1,	-1,	255	},	
                                    {	-1,	-1,	255	},	
                                    {	-1,	-1,	255	},	
                                    {	-1,	-1,	255	},	
                                    {	-1,	-1,	255	},	
                                    {	-1,	-1,	255	},	
                                    {	-1,	-1,	255	},	
                                    {	-1,	-1,	255	},	
                                    {	-1,	-1,	255	},	
                                    {	-1,	-1,	255	},	
                                    {	-1,	-1,	255	},	
                                    {	-1,	-1,	255	},	
                                    {	-1,	-1,	255	},	
                                    {	-1,	-1,	255	},	
                                    {	-1,	-1,	255	},	
                                    {	-1,	-1,	255	},	
                                    {	-1,	-1,	255	},	
                                    {	-1,	-1,	255	},	
                                    {	-1,	-1,	255	},	
                                    {	-1,	-1,	255	},	
                                    {	-1,	-1,	255	},	
                                    {	-1,	-1,	255	},	
                                    {	-1,	-1,	255	},	
                                    {	-1,	-1,	255	},	
                                    {	-1,	-1,	255	},	
                                    {	-1,	-1,	255	},	
                                    {	-1,	-1,	255	},	
                                    {	-1,	-1,	255	},	
                                    {	-1,	-1,	255	},	
                                    {	-1,	-1,	255	},	
                                    {	-1,	-1,	255	},	
                                    {	-1,	-1,	255	},	
                                    {	-1,	-1,	255	},	
                                    {	-1,	-1,	255	},	
                                    {	-1,	-1,	255	},	
                                    {	-1,	-1,	255	},	
                                    {	-1,	-1,	255	},	
                                    // NOT OFFICIAL BLOCK IDS. MCMAP USE ONLY
                                    {	 9,	11,	255	}, // Sandstone half step
                                    {	 4,	 0,	255	}, // Wooden half step
                                    {	 0,	 1,	255	}, // Cooblestone half step
                                    {	 4,	 8,	255	}, // Pine leaves (should be darker, more green)
                                    {	 4,	 3,	255	}, // Birch leaves (should be lighter)
                                    {	 4,	 7,	255	}, // Pine trees get remapped here
                                    {	 5,	 7,	255	}, // Birches get remapped here	
                                    {	 2,	13,	255	},	// Orange Wool - 240  
                                    {	 2,	12,	255	},	// Magenta Wool - 241
                                    {	 2,	11,	255	},	// Light Blue Wool - 242
                                    {	 2,	10,	255	},	// Yellow Wool - 243
                                    {	 2,	 9,	255	},	// Light Green Wool - 244
                                    {	 2,	 8,	255	},	// Pink Wool - 245
                                    {	 2,	 7,	255	},	// Dark Grey Wool - 246
                                    {	 1,	14,	255	},	// Gray Wool - 247
                                    {	 1,	13,	255	},	// Cyan Wool - 248
                                    {	 1,	12,	255	},	// Purple Wool - 249
                                    {	 1,	11,	255	},	// Blue Wool - 250
                                    {	 1,	10,	255	},	// Brown Wool - 251
                                    {	 1,	 9,	255	},  // Dark Green Wool - 252               
                                    {	 1,	 8,	255	},	// Red Wool - 253
                                    {	 1,	 7,	255	},	// Black Wool - 254
                                    {	-1,	-1,	255	}   
                                                            };
                                    
void getTileRGBA(unsigned char *textures, int tilesize, int x, int y, int &r, int &g, int &b, int &a, int &noise)
{
    r = 0;
    g = 0;
    b = 0;
    a = 0;
    noise = 0;
    
    if (x == -1)
        return;
    
    int n = tilesize*tilesize;
    int bytesperrow = 16*tilesize*4;
    
    int sx = x*tilesize*4;
    int sy = y*tilesize;
    
    for(int j=sy; j<(sy+tilesize); j++)
    {
        for(int i=sx; i<(sx+tilesize*4); i=i+4)
        {
            // If the pixel is entirely transparent
            if (textures[i+3+j*(bytesperrow)] == 0)
            {   
                n--;
            }
            else
            {
                r=r+textures[i+j*(bytesperrow)];
                g=g+textures[i+1+j*(bytesperrow)];
                b=b+textures[i+2+j*(bytesperrow)];
                a=a+textures[i+3+j*(bytesperrow)];
            }
            
        }
    }
    
    double var = 0;
    
    if (n>0)
    {
        r=r/n;
        g=g/n;
        b=b/n;
        a=a/n;
    
        for(int j=sy; j<(sy+tilesize); j++)
        {
            for(int i=sx; i<(sx+tilesize*4); i=i+4)
            {
                // If the pixel is entirely transparent
                if (textures[i+3+j*(bytesperrow)] != 0)
                {
                    var = var + (pow(textures[i+j*(bytesperrow)]-r,2) + pow(textures[i+1+j*(bytesperrow)]-b,2) + pow(textures[i+2+j*(bytesperrow)]-g,2))/(3*n);
                }
                
            }
        }
            
        noise = int(8 * var / ((n*n-1)/12) );
        if (noise > 255)
            noise = 255;
    }
    
}

void extractcolors(unsigned char *textures, int tilesize, int (*colors)[5], bool fixFoliage )
{
    
    for(int i=0; i<MINECRAFT_TILE_COUNT; i++)
    {
        getTileRGBA(textures, tilesize, special_sauce[i][0],special_sauce[i][1],colors[i][0],colors[i][1],colors[i][2],colors[i][3],colors[i][4]);
        colors[i][3] = float(colors[i][3])*(float(special_sauce[i][2])/255.0f);
        
        if (fixFoliage)
        {
            if (i==2 || i==18 || i==236 || i==237 || i==238 ||i==239) // grass and leaf temporary fix
            {
                colors[i][0] = float(colors[i][0]) * 0.2f;
                colors[i][2] = float(colors[i][0]) * 0.2f;
            }
        }
    }
}


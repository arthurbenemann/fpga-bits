//----------------------------------------------
//				graphics.c
// 	Draw Graphics on video
// 	Arthur Bemann 06/05/2011
//-----------------------------------------------
//
//	Description:
//	Draw geometric shapes on the video buffer
//	
//  Current :
//  dots			06/05/2011
//	lines			06/05/2011
//  filled squares	11/05/2011
//-----------------------------------------------
//	
//	Requeriments:
//	VGA.h
//
//-----------------------------------------------

#include "VGA.h"				// Video Buffer prototype

//------------------- FUNCTIONS -------------------------

//------------ plotDot ------------------
// light up one pixel on the cord. passed
// as arg.
void plotDot(unsigned x, unsigned y, unsigned color)
{
	if( (x<HRES) && (y<VRES) )				// Test if dot is on the screen
	{
		if(color)
			VH[ (VRES-1-y)*lineSize + (x>>4)] |=
				0x8000 >>(x&0x000F) ;
		else
			VH[ (VRES-1-y)*lineSize + (x>>4)] &=
				~(0x8000 >>(x&0x000F)) ;
	}
}

//------------ readDot ------------------
// Return if the pixel in cordinates is on
// call readDotA to check a pixel on the Active Buffer
// call readDotH to check a pixel on the Hidden Buffer
// for off the screen check it returns false
int readDotA(unsigned x, unsigned y)
{
	if( (x<HRES) && (y<VRES) )				// Test if dot is on the screen
		return VA[(VRES-1-y)*lineSize+(x>>4)]&(0x8000>>(x&0x000F));
	else
		return 0;						

}
int readDotH(unsigned x, unsigned y)
{
	if( (x<HRES) && (y<VRES) )				// Test if dot is on the screen
		return VH[(VRES-1-y)*lineSize+(x>>4)]&(0x8000>>(x&0x000F));
	else
		return 0;						

}

//-------------- plotSquare -------------
//plot ortogonal squares on the video buffer
// filled or unfilled
void plotSquare( int x0, int y0, int x1, int y1,unsigned filled,unsigned color)
{
	int t,y;

	// swap ends
    if (x0 > x1) 
	    { t = x0; x0 = x1; x1 = t; }
    if (y0 > y1) 
	    { t = y0; y0 = y1; y1 = t; }  

	if(filled)
	{	//fill full square with dots
		for(; x0<=x1; x0++)
			for(y=y0; y<=y1; y++)
				plotDot(x0,y,color);
	}
	else
	{	// plot just the board of a square
		plotLine(x0,y0,x0,y1,color);
		plotLine(x0,y0,x1,y0,color);
		plotLine(x1,y1,x0,y1,color);	
		plotLine(x1,y1,x1,y0,color);
	}
}

//-------------- plotLine ---------------	
// Plots a line betwen two points
// Bresenham line algorithm    (wikipedia)
#define abs( a)     (((a)> 0) ? (a) : -(a))
void plotLine( int x0, int y0, int x1, int y1,unsigned color)
{
     int steep, t ;
     int deltax, deltay, error;
     int x, y;
     int ystep;

     steep = ( abs(y1 - y0) > abs(x1 - x0));
     
     if ( steep )
     { // swap x and y
         t = x0; x0 = y0; y0 = t;
         t = x1; x1 = y1; y1 = t;
     }
     if (x0 > x1) 
     {  // swap ends
         t = x0; x0 = x1; x1 = t;
         t = y0; y0 = y1; y1 = t;
     }
     
     deltax = x1 - x0;
     deltay = abs(y1 - y0);
     error = 0;
     y = y0;
     
     if (y0 < y1) ystep = 1; else ystep = -1;
     for (x = x0; x <= x1; x++)
     {
         if ( steep) plotDot(y,x,color); else plotDot(x,y,color);
         error += deltay;
         if ( (error<<1) >= deltax)
         {
             y += ystep;
             error -= deltax;
         } // if 
     } // for
} // line 

//------------ plotCircle -------------------
// Plots a circle
// Midpoint circle algorithm	(wikipedia)
void plotCircle(int x0, int y0, int radius, int color)
{
  int f = 1 - radius;
  int ddF_x = 1;
  int ddF_y = -2 * radius;
  int x = 0;
  int y = radius;
 
  plotDot(x0, y0 + radius,color);
  plotDot(x0, y0 - radius,color);
  plotDot(x0 + radius, y0,color);
  plotDot(x0 - radius, y0,color);
 
  while(x < y)
  {
    // ddF_x == 2 * x + 1;
    // ddF_y == -2 * y;
    // f == x*x + y*y - radius*radius + 2*x - y + 1;
    if(f >= 0) 
    {
      y--;
      ddF_y += 2;
      f += ddF_y;
    }
    x++;
    ddF_x += 2;
    f += ddF_x;    
    plotDot(x0 + x, y0 + y,color);
    plotDot(x0 - x, y0 + y,color);
    plotDot(x0 + x, y0 - y,color);
    plotDot(x0 - x, y0 - y,color);
    plotDot(x0 + y, y0 + x,color);
    plotDot(x0 - y, y0 + x,color);
    plotDot(x0 + y, y0 - x,color);
    plotDot(x0 - y, y0 - x,color);
  }
}

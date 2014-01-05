/*

    This file is part of the Aduino Piano Squealer.

    Arduino Piano Squealer is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    Arduino Piano Squealer is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with Arduino Piano Squealer.  If not, see <http://www.gnu.org/licenses/>.

    Copyright 2008, 2009 Marc Nostromo	

*/

#include <avr/interrupt.h>
#include "SynthData.h"


// Oscillator internal variable

bool oscRunning=false ;
float oscPosition=0 ;
float oscSpeed=0 ;
const prog_uint8_t *oscDataStart=0 ;
int oscDataLen=0 ;

fixed oscFCut=i2fp(1) ;
fixed oscFRes=0 ;
fixed oscFMix=0 ;

float oscLoopStart=0.5 ;
float oscLoopWidth=1.0 ;

fixed ampValue=i2fp(1);

fixed fltHeight=0 ;
fixed fltSpeed=0 ;
fixed fltDelay=0 ;

fixed outValue=0 ; // output for release

// Oscillator external parameters
int oscShapeParam=0 ;
float oscFrequencyParam=0 ;

fixed clipFPlus=0 ;
fixed clipFMinus=0 ;

// Wave shape data
int oscShapeCount=6 ;

const prog_uint8_t *oscShapeTable[]= {
   sineTable,
   boy1Table,
   triTable,
   noizTable,
   casioTable,
   squareTable
} ;

int oscShapeLength[]= {
  0x100,
  0x12,
  0x100,
  0x2AD,
  0x244,
  0x100
} ;

#define DRIVER_SAMPLERATE 15625.0f

void SE_SetFrequency(float frequency) {
   if (frequency==0) {
      oscFrequencyParam=0 ;
      oscRunning=false ;
   }else {
     oscRunning=true ;
     oscFrequencyParam=frequency ;
     oscSpeed=(frequency*oscDataLen)/DRIVER_SAMPLERATE ; 
  }
} ;

void SE_SetNote(int note) {
  float freq=261.6255653006f ; //C3
  float freqFactor=(pow(2.0,(note-12)/12.0)) ;  
  SE_SetFrequency(freq*freqFactor) ;
} ;

void updateLoopPoints() {
  int len=oscShapeLength[oscShapeParam] ;
  int o1=len*oscLoopStart ;
  int o2=len*oscLoopWidth ;
  if (o1+o2>len) o2=len-o1 ;

  oscDataStart=oscShapeTable[oscShapeParam]+o1 ;
  oscDataLen=o2 ;
  SE_SetFrequency(oscFrequencyParam) ;
}

void SE_SetShape(float shape) {
  int newShape=shape*oscShapeCount-0.01 ;
  if (newShape==oscShapeParam) return ;

  oscShapeParam=newShape ;
  updateLoopPoints() ;
  oscPosition=0;
} ;

void SE_SetStart(float start) {
  oscLoopStart=start ;
  updateLoopPoints() ;
}

void SE_SetWidth(float w) {
  oscLoopWidth=w ;
  updateLoopPoints() ;
}


void SE_SetFilterCut(float cut) {
  oscFCut=fl2fp(cut*cut) ;
};

void SE_SetFilterMix(float mix) {
  oscFMix=fl2fp(mix) ;
};

void SE_SetAmp(float amp) {
  ampValue=fl2fp(amp) ;
};

void SE_SetOutput(float out) {
  outValue=fl2fp(out) ;
};

void SE_SetFilterRes(float res) {
  float tmpRes=(1-res) ;
  oscFRes=fl2fp(1-tmpRes*tmpRes*tmpRes) ;
};

void SynthEngine_Setup() {
  oscShapeParam=0 ;
  oscFrequencyParam=0 ;
  SE_SetNote(0) ;
  SE_SetShape(0.9) ;
  clipFPlus=i2fp(16-FIXED_SHIFT) ;
  clipFMinus=-clipFPlus ;
}


// variables for oscillators

uint16_t index = 0;        // index for wave lookup (the upper 8 bits of the accumulator)
fixed osc =0;        // oscillator output
uint8_t rawOsc=0 ;

// ProcessSample:
//
// returns a unsigned 16 bit value
// to be sent to the DAC. This routine
// is called for every sample
//

uint16_t SynthEngine_ProcessSample() {

	// Return 0 if we don't run
	
	if (!oscRunning) return 0x8000 ;
  
	// calculate new position inside the
	// current wavetable. 

	oscPosition +=oscSpeed ;  // add in pith, the higher the number, the faster it rolls over, the more cycles per second
  index=((int)oscPosition) ;
    
  if (index>=oscDataLen) {
    oscPosition-=oscDataLen ;
    index-=oscDataLen ;
  }

  memcpy_P(&rawOsc,&oscDataStart[index],1);

  osc=(rawOsc-0x80)<<(FIXED_SHIFT-8+4) ;

  osc=fp_mul(osc,ampValue) ;    
  fixed lpin =fp_mul(osc,FP_ONE-oscFMix) ;
  fixed hpin = -fp_mul(osc,oscFMix) ;
							
//  fixed difr = fp_sub(osc,fltHeight);
  fixed difr = fp_sub(lpin,fltHeight);


  fltSpeed = fp_mul(fltSpeed,oscFRes);		//mul by res, it's some kind of inertia. caution to feedback

  fltSpeed = fp_add(fltSpeed,fp_mul(difr,oscFCut)); //mul by cutoff, less cutoff = no sound, so it's better not be 0.

  
  
  fltHeight += fltSpeed ;
  fltHeight+=fltDelay-hpin ;
  

  osc=fltHeight ;
  
  if (fltHeight>clipFPlus) {
   fltHeight=clipFPlus ;
  } else if (fltHeight<clipFMinus){
    fltHeight=clipFMinus ;
  }
  
  fltDelay=hpin ;
  
  osc=fp_mul(osc,outValue) ;
 
  osc<<=2 ;

  return osc+0x8000;   // sample format for DAC is 12 bit, left justified
}

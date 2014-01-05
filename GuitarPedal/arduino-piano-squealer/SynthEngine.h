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

#ifndef _SYNTH_ENGINE_H_
#define _SYNTH_ENGINE_H_


#include <inttypes.h>
#include "fixed.h"

extern fixed maxSpeed ;

void SynthEngine_Setup() ;
uint16_t SynthEngine_ProcessSample() ;

void SE_SetShape(float) ;
void SE_SetFrequency(float frequency) ;
void SE_SetNote(int note) ; // -1 to kill note
void SE_SetStart(float) ;
void SE_SetWidth(float) ;

//void SE_SetLoop(float center,float size) ;
void SE_SetAmp(float) ;
void SE_SetFilterCut(float) ;
void SE_SetFilterRes(float) ;
void SE_SetFilterMix(float) ;
void SE_SetOutput(float) ;

#endif

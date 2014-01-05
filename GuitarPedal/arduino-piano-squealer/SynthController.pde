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

#include "SynthController.h"
#include "SynthEngine.h"

uint32_t lastButtons=0 ;
uint16_t lastC1=0x1000;
uint16_t lastC2=0x1000;
uint16_t lastC3=0x1000;

int page=0 ;
int pageCount=3 ;

float ampEnvelope=1 ;

typedef void (*ControllerFunction) (float);

enum ControllerParamStatus {
  CPS_INACTIVE=0,
  CPS_UPDATE,
  CPS_ENVUP,
  CPS_ENVDOWN
} ;

enum ControllerParameters {
  CP_WAVE_SHAPE=0,
  CP_WAVE_START,
  CP_WAVE_LOOP,
  CP_FILTER_MIX,
  CP_FILTER_CUT,
  CP_FILTER_RES,
  CP_OUT_GAIN,
  CP_LAST
} ;

struct params {
  ControllerParamStatus status_ ;
  ControllerFunction update_ ;
  float envelope_ ;
  float current_ ;
  float target_ ;
  float speed_ ;
};

struct patch {
  float release_ ;
  int transpose_ ;
} ;

struct params controllerParams[CP_LAST] ;
struct patch controllerPatch ;

void SC_SetParam(int which,float value,bool reset=false) {
  struct params *current=controllerParams+which ;
  current->current_=value ;
  if ((current->status_==CPS_INACTIVE)||(reset)) {
    current->status_=CPS_UPDATE;
    current->envelope_=0 ;  
  }
} ;

void SC_SetEnvelope(int which,float target,float time) {

  struct params *current=controllerParams+which ;
  if (time<0.001) {
    current->envelope_=target ;
    current->status_=CPS_UPDATE ;
  } else {
    current->target_=target ;
    if (target<current->envelope_) {
      float sp=(current->envelope_-target)/time/200.0 ;
      current->speed_=sp ;
      current->status_=CPS_ENVDOWN ;
    } else {
      float sp=(target-current->envelope_)/time/200.0 ;
      current->speed_=sp ;
      current->status_=CPS_ENVUP ;
    }
  }
} ;

void SynthController_ProcessEnvelopes()   {
  struct params *current=controllerParams ;
  for (int i=0;i<CP_LAST;i++) {
    if (current->status_!=CPS_INACTIVE) {
      float value=current->current_+current->envelope_ ;
      if (value>1.0) value=1.0 ;
      if (value<0) value=0.0 ;
      current->update_(value) ;
      switch(current->status_) {
        case CPS_UPDATE:
          current->status_==CPS_INACTIVE ;
          break ;
        case CPS_ENVUP:
          current->envelope_+=current->speed_ ;
          if (current->envelope_>current->target_) {
            current->envelope_=current->target_ ;
            current->status_=CPS_UPDATE ;
          }
          break ;
        case CPS_ENVDOWN:
          current->envelope_-=current->speed_ ;
          if (current->envelope_<current->target_) {
            current->envelope_=current->target_ ;
            current->status_=CPS_UPDATE ;
          }
          break ;
      }
    } ;
    current++ ;
  }
};  

void SynthController_Setup() {

  SynthEngine_Setup() ;

  controllerPatch.release_=0 ;
  controllerPatch.transpose_=0 ;
  
  struct params *current=controllerParams ;
  
  for (int i=0;i<CP_LAST;i++) {
    switch(i) {
      case CP_WAVE_SHAPE:
        current->current_=0 ;
        current->update_=SE_SetShape ;
        break ;
      case CP_WAVE_START:
        current->current_=0 ;
        current->update_=SE_SetStart ;
        break ;
      case CP_WAVE_LOOP:
        current->current_=1 ;
        current->update_=SE_SetWidth ;
        break ;
      case CP_FILTER_MIX:
        current->current_=0 ;
        current->update_=SE_SetFilterMix ;
        break ;
      case CP_FILTER_CUT:
        current->current_=1.0 ;
        current->update_=SE_SetFilterCut ;
        break ;
      case CP_FILTER_RES:
        current->current_=0 ;
        current->update_=SE_SetFilterRes ;
        break ;
      case CP_OUT_GAIN:
        current->current_=1 ;
        current->update_=SE_SetOutput ;
        break ;
      default:
        current->update_=0 ;
        break ;      
    }
    if (current->update_) {
      current->update_(current->current_) ;
    }
    current->status_=CPS_INACTIVE ;
    current->envelope_=0 ;
    current++ ;
  }
  SC_SetParam(CP_OUT_GAIN,0.0,true) ;
} ;


void SynthController_Trigger(uint32_t buttons,uint16_t c1,uint16_t c2,uint16_t c3,uint16_t c4) {

  if (lastButtons==0) {
     lastButtons=buttons ;
     return ;
  } 
  if (lastButtons!=buttons) {
    int note=-1000 ;
    for (int i = 0; i < 23; i++){
      if ( !((buttons >> i) & 1)){    // check status of each bit in the buttons variable, if it is 0, then a button  is down
        note=i ;
        break;   // leave the loop if a button was down
      } 
    }
    lastButtons=buttons ;    
    if (note>=-999) {
        SE_SetNote(note+controllerPatch.transpose_*12) ;
        SC_SetParam(CP_OUT_GAIN,1.0,true) ;
    } else {
        SC_SetEnvelope(CP_OUT_GAIN,-1.0,controllerPatch.release_) ;
    }
    if (!((buttons >> 23) & 1)) {
      page++ ;
      if (page>=pageCount) {
        page=0 ;
      }  
    }  
  }
  
  switch(page) {
   case 0:
    if (c1!=lastC1) {
      SC_SetParam(CP_WAVE_SHAPE,c1/float(0x400));      
      lastC1=c1;
    }
    if (c2!=lastC2) {
      controllerPatch.transpose_=c2/float(0x80)-4 ;      
      lastC2=c2;
    }
    if (c3!=lastC3) {
      controllerPatch.release_=c3/float(0x800) ;
      lastC3=c3;
    }
    break ;
   case 1:
    if (c1!=lastC1) {
      SC_SetParam(CP_FILTER_MIX,c1/float(0x400));      
      lastC1=c1;
    }
    if (c2!=lastC2) {
      SC_SetParam(CP_FILTER_CUT,c2/float(0x400));      
      lastC2=c2;
    }
    if (c3!=lastC3) {
      SC_SetParam(CP_FILTER_RES,c3/float(0x400));      
      lastC3=c3;
    }
    case 2:
    if (c2!=lastC2) {
      SC_SetParam(CP_WAVE_START,c2/float(0x400));      
      lastC2=c2;
    }
    if (c3!=lastC3) {
      SC_SetParam(CP_WAVE_LOOP,c3/float(0x400));      
      lastC3=c3;
    }   
    break ;
  }

//  if (c1!=lastC1) {
//    SE_SetAmp(c1/float(0x40)) ;
//    lastC1=c1;
//  }

}

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

// Setup API

void setup(){

  // Setup the arduino hardware, interrupts,etc..
  
  Hardware_Setup() ;

  // Initialises the synth parameters
  
  SynthController_Setup() ;
  
}

// Loop API

void loop(void)
{
  while(millis() % 5);  // Wait while we got time

  SynthController_ProcessEnvelopes() ;
  
  // Read the piano button state
  
  uint32_t buttons=Hardware_ReadButton() ;

  // Process all external controls
  
  SynthController_Trigger(buttons,analogRead(0),analogRead(1),analogRead(2),analogRead(3)) ;

  while(millis() % 5==0);  // Wait in case we got too fast
}


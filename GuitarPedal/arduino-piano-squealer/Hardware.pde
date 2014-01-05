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

#include "Hardware.h"
#include "HardwareData.h"

//
//
// Hardware Setup
//
//

extern uint16_t SynthEngine_ProcessSample() ;

void Hardware_Setup()
{

  //Timer2 setup  This is the audio rate timer, fires an interrupt at 15625 Hz sampling rate

  TIMSK2 = 1<<OCIE2A;  // interrupt enable audio timer
  OCR2A = 127;
  TCCR2A = 2;               // CTC mode, counts up to 127 then resets
  TCCR2B = 0<<CS22 | 1<<CS21 | 0<<CS20;   // different for atmega8 (no 'B' i think)
    
  SPCR = 0x50;   // set up SPI port
  SPSR = 0x01;
  DDRB |= 0x2E;       // PB output for DAC CS, and SPI port
  PORTB |= (1<<1);   // CS high
  
  sei();			// global interrupt enable
  
  // configure pins for multiplexer
  pinMode(MUX_SEL_A, OUTPUT);  // these are the select pins
  pinMode(MUX_SEL_B, OUTPUT);
  pinMode(MUX_SEL_C, OUTPUT);
  
  
  pinMode(MUX_OUT_0, INPUT);
  pinMode(MUX_OUT_1, INPUT);
  pinMode(MUX_OUT_2, INPUT);

  digitalWrite(MUX_SEL_A, 1);   // multiplexer outputs, 8 each
  digitalWrite(MUX_SEL_B, 1);
  digitalWrite(MUX_SEL_C, 1);

  //flash led
  pinMode(PP_LED, OUTPUT);
  digitalWrite(PP_LED, 1);
  delay(100);
  digitalWrite(PP_LED, 0);
  delay(100);
  digitalWrite(PP_LED, 1);
  delay(100);
  digitalWrite(PP_LED, 0);

  Serial.begin(9600);
  Serial.println("hello");
  Serial.println("welcome to synthesizer");

}

//
//
// Returns piano button state
//
//

unsigned char frameCount=0 ;
unsigned char flip=0 ;
unsigned char pCount=0 ;
unsigned char led=0 ;
extern int page ;

uint32_t Hardware_ReadButton() {

  frameCount++ ;

  if (frameCount%15==0) {
    led=flip=1-flip ;
    if (led==1) {
      if (pCount>page) {
        led=0 ;
      }
      pCount++ ;
      if (pCount>5) pCount=0 ;
    }
    digitalWrite(PP_LED, led);
    frameCount=0 ;
  }
  // this funcion reads the buttons and stores their states in the global 'buttons' variable
// this 32 bit number holds the states of the 24 buttons, 1 bit per button

  uint32_t  buttons = 0;
  int i;
  for (i = 0; i < 8; i++){
    digitalWrite(MUX_SEL_A, i & 1);
    digitalWrite(MUX_SEL_B, (i >> 1) & 1);
    digitalWrite(MUX_SEL_C, (i >> 2) & 1);
    buttons |= digitalRead(MUX_OUT_2) << i;  
  }
  buttons <<= 8;
  for (i = 0; i < 8; i++){
    digitalWrite(MUX_SEL_A, i & 1);
    digitalWrite(MUX_SEL_B, (i >> 1) & 1);
    digitalWrite(MUX_SEL_C, (i >> 2) & 1);
    buttons |= digitalRead(MUX_OUT_1) << i;
  }
  buttons <<= 8;
  for (i = 0; i < 8; i++){
    digitalWrite(MUX_SEL_A, i & 1);
    digitalWrite(MUX_SEL_B, (i >> 1) & 1);
    digitalWrite(MUX_SEL_C, (i >> 2) & 1);
    buttons |= digitalRead(MUX_OUT_0) << i;   
  }
  buttons |= 0x1000000;  // for the 25th button
  
  // uncomment these two lines to use the 25th button, if the board is modified so button connects to PC 3
 // if (!(PINC & 0x8))      
  //  buttons &= ~0x1000000;  

  return buttons ;
};

//
// Timer 2 interrupt routine calling the synth engine for every sample
//

// the two bytes that go to the DAC over SPI
uint8_t dacSPI0;
uint8_t dacSPI1;

// timer 2 is audio interrupt timer
ISR(TIMER2_COMPA_vect) {

  OCR2A = 127;
  
  PORTB &= ~(1<<1); // Frame sync low for SPI (making it low here so that we can measure lenght of interrupt with scope)
 
  uint16_t sample= SynthEngine_ProcessSample() ;
  
  // format sample for SPI port
  dacSPI0 = sample >> 8;
  dacSPI0 >>= 4;
  dacSPI0 |= 0x30;
  dacSPI1 = sample >> 4;

  // transmit value out the SPI port
  PORTB &= ~(1<<1); // Frame sync low
  SPDR = dacSPI0;
  while (!(SPSR & (1<<SPIF)));
  SPDR = dacSPI1;
  while (!(SPSR & (1<<SPIF)));
  PORTB |= (1<<1); // Frame sync high
}


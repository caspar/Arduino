/* Arduino Audio Loopback Test
 *
 * Arduino Realtime Audio Processing
 * 2 ADC 8-Bit Mode
 * analog input 1 is used to sample the audio signal
 * analog input 0 is used to control an audio effect
 * PWM DAC with Timer2 as analog output
 
 
 
 * KHM 2008 /  Martin Nawrath
 * Kunsthochschule fuer Medien Koeln
 * Academy of Media Arts Cologne
 
 */


#define cbi(sfr, bit) (_SFR_BYTE(sfr) &= ~_BV(bit))
#define sbi(sfr, bit) (_SFR_BYTE(sfr) |= _BV(bit))


int ledPin = 13;                 // LED connected to digital pin 13
int testPin = 7;


boolean div32;
boolean div16;
// interrupt variables accessed globally
volatile boolean f_sample;
volatile byte badc0;
volatile byte badc1;
volatile byte ibb;

int ii;


int icnt;
int cnt2;

float pi = 3.141592;
float dx ;
float fd ;
float fcnt;
int iw;
byte bb;

byte dd[512];  // Audio Memory Array 8-Bit


void setup()
{
  pinMode(ledPin, OUTPUT);      // sets the digital pin as output
  pinMode(testPin, OUTPUT);
  Serial.begin(57600);        // connect to the serial port
  Serial.println("Arduino Audio");


  fill_sinewave();        // load memory with sine table


    // set adc prescaler  to 64 for 19kHz sampling frequency
  cbi(ADCSRA, ADPS2);
  sbi(ADCSRA, ADPS1);
  sbi(ADCSRA, ADPS0);




  sbi(ADMUX,ADLAR);  // 8-Bit ADC in ADCH Register
  sbi(ADMUX,REFS0);  // VCC Reference
  cbi(ADMUX,REFS1);
  cbi(ADMUX,MUX0);   // Set Input Multiplexer to Channel 0
  cbi(ADMUX,MUX1);
  cbi(ADMUX,MUX2);
  cbi(ADMUX,MUX3);


  // Timer2 PWM Mode set to fast PWM 
  cbi (TCCR2A, COM2A0);
  sbi (TCCR2A, COM2A1);
  sbi (TCCR2A, WGM20);
  sbi (TCCR2A, WGM21);

  cbi (TCCR2B, WGM22);




  // Timer2 Clock Prescaler to : 1 
  sbi (TCCR2B, CS20);
  cbi (TCCR2B, CS21);
  cbi (TCCR2B, CS22);

  // Timer2 PWM Port Enable
  sbi(DDRB,3);                    // set digital pin 11 to output

  //cli();                         // disable interrupts to avoid distortion
  cbi (TIMSK0,TOIE0);              // disable Timer0 !!! delay is off now
  sbi (TIMSK2,TOIE2);              // enable Timer2 Interrupt


}



void loop()
{

  while (!f_sample) {        // wait for Sample Value from ADC
  }                          // Cycle 15625 KHz = 64uSec 

  PORTD = PORTD  | 128;      // Test Output on pin 7
  f_sample=false;            // reset Flag

  badc1=dd[icnt];            // get the buffervalue on indexposition

  icnt++;                    // increment index
  icnt=icnt + badc0;         // Variable frequency with potentiometer
  icnt = icnt & 511;         // limit index 0..511

    cnt2++;                  // let the led blink about every second
  if (cnt2 >= 15){
    
    icnt=0;
    PORTB = PORTB ^ 32;      // toggle LED on pin 11

  }

  OCR2A=badc1;               // Sample Value to PWM Output

  PORTD = PORTD  ^ 128;      // Test Output on pin 7


} // loop
//******************************************************************
void fill_sinewave(){
  dx=2 * pi / 512;                    // fill the 512 byte bufferarry
  for (iw = 0; iw <= 511; iw++){      // with  50 periods sinewawe
    fd= 127*sin(fcnt);                // fundamental tone
    fcnt=fcnt+dx;                     // in the range of 0 to 2xpi  and 1/512 increments
    bb=127+fd;                        // add dc offset to sinewawe 
    dd[iw]=bb;                        // write value into array

  }
}


//******************************************************************
// Timer2 Interrupt Service at 62.5 KHz
// here the audio and pot signal is sampled in a rate of:  16Mhz / 256 / 2 / 2 = 15625 Hz
// runtime : xxxx microseconds
ISR(TIMER2_OVF_vect) {

  PORTB = PORTB  | 1 ;

  div32=!div32;                            // divide timer2 frequency / 2 to 31.25kHz
  if (div32){ 
    div16=!div16;  // 
    if (div16) {                       // sample channel 0 and 1 alternately so each channel is sampled with 15.6kHz
      badc0=ADCH;                    // get ADC channel 0
      sbi(ADMUX,MUX0);               // set multiplexer to channel 1
    }
    else
    {
      badc1=ADCH;                    // get ADC channel 1
      cbi(ADMUX,MUX0);               // set multiplexer to channel 0
      f_sample=true;
    }
    ibb++; 
    ibb--; 
    ibb++; 
    ibb--;    // short delay before start conversion
    sbi(ADCSRA,ADSC);              // start next conversion
  }

}

#include "Shrike.h"
ShrikeFlash shrike;

// Correlation input pins (RP2040 side of internal bus)
const int corr_pins[6] = {0, 1, 2, 3, 15, 14};  // corr_0 to corr_5
const int latch_pin = 17;                          

void setup() {
    Serial.begin(115200);
    while (!Serial && millis() < 3000);

    // Flash the FPGA first
    Serial.println("Flashing FPGA...");
    shrike.begin();
    shrike.flash("/FPGA_bitstream_MCU.bin");
    Serial.println("FPGA running. Reading correlation...");

    // Set up input pins
    for (int i = 0; i < 6; i++) {
        pinMode(corr_pins[i], INPUT);
    }
    pinMode(latch_pin, INPUT);
}

int last_latch = 0;

void loop() {
    int latch = digitalRead(latch_pin);
    
    if (latch != last_latch) {
        last_latch = latch;
        
        // Read 6 bit correlation value
        int score = 0;
        for (int i = 0; i < 6; i++) {
            score |= (digitalRead(corr_pins[i]) << i);
        }
        
        float normalised = (score / 63.0 - 0.5) * 2.0;
        Serial.println(normalised, 3);  

        
    }
}
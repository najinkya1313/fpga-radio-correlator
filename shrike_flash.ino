#include "Shrike.h"
ShrikeFlash shrike;

const int corr_pins[6] = {0, 1, 2, 3, 15, 14};
const int integration_windows = 256;
long int sum = 0;
int count = 0;

void setup() {
    Serial.begin(115200);
    while (!Serial && millis() < 3000);
    Serial.println("Flashing FPGA...");
    shrike.begin();
    shrike.flash("/FPGA_bitstream_MCU.bin");
    Serial.println("FPGA running.");
    for (int i = 0; i < 6; i++) {
        pinMode(corr_pins[i], INPUT);
    }
}

void loop() {
    int score = 0;
    for (int i = 0; i < 6; i++) {
        score |= (digitalRead(corr_pins[i]) << i);
    }
    sum += score;
    count++;
    if (count >= integration_windows) {
        Serial.println(sum);
        sum = 0;
        count = 0;
    }
    delay(2);
}

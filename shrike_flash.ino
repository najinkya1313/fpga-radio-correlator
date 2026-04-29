#include "Shrike.h"
#include "hardware/gpio.h"
ShrikeFlash shrike;

const int xnor_pin = 0;  // RP2040 pin 0 = FPGA GPIO6

void setup() {
    Serial.begin(115200);
    while (!Serial && millis() < 3000);
    Serial.println("Flashing FPGA...");
    shrike.begin();
    shrike.flash("/FPGA_bitstream_MCU.bin");
    Serial.println("FPGA running.");
    gpio_init(xnor_pin);
    gpio_set_dir(xnor_pin, GPIO_IN);
}

void loop() {
    long count = 0;
    unsigned long start = millis();
    while (millis() - start < 1000) {
        if (gpio_get(xnor_pin)) count++;
    }
    Serial.println(count);
}

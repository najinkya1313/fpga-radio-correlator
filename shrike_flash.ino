#include "Shrike.h"
#include "hardware/gpio.h"
#include "hardware/structs/sio.h"
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
    for (long i = 0; i < 8388608; i++) {
        count += (sio_hw->gpio_in >> xnor_pin) & 1u;
        // Wait ~120ns for next FPGA sample (15 × 8ns = 120ns)
        __asm volatile ("nop\nnop\nnop\nnop\nnop\n"
                        "nop\nnop\nnop\nnop\nnop\n"
                        "nop\nnop\nnop\nnop\nnop\n");
    }
    Serial.println((float)count / 8388608.0f, 6);
}

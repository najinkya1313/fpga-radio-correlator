# fpga-radio-correlator


**FPGA-based 1-bit digital correlator for radio interferometry**

A two-element radio interferometer built around the Vicharak Shrike Lite FPGA board and two commercial dish TV antennas, designed for solar observations at 11.2 GHz. This project replicates the experiment described in [Gireesh et al. (2021)](https://doi.org/10.1007/s11207-021-01871-9) from the Indian Institute of Astrophysics, Gauribidanur, which demonstrated successful radio interferometric observations of the Sun using off-the-shelf Ku-band dish antennas.

---

## Background

A radio interferometer measures the correlation between signals received at two spatially separated antennas. When a radio source (like the Sun) is in view, the signals at the two antennas reach at different times. This delay is due to the time it takes for a wavefront to travel from one antenna to the other. By correlating these two signals, you can extract information about the angular size and brightness of the source that a single antenna cannot provide.

This project implements the correlator digitally on an FPGA. The analog signal from each antenna's LNB (Low Noise Block) is amplified and downconverted to ~10 MHz, passed through a precision comparator (AD790JN) that converts it to a 1-bit digital signal (0 or 1), and then fed into the FPGA. The FPGA has two  D-type flip flop samplers and an XNOR gate for correlating the signals. The correlation output is accumulated over a 65536-cycle window and the resulting correlation counts are sent to a host PC via the onboard RP2040 microcontroller over USB.

This is the same architecture used in the IIA experiment, where they describe it as a "1-bit digital correlator assembled with simple digital logic circuits." Here, all of that logic lives inside the FPGA.

---

## FPGA Design

The correlator is implemented in Verilog (`main.v`) and consists of:

- **Input DFFs** — two D flip-flops that sample `ant_a` and `ant_b` on each rising clock edge
- **XNOR gate** — outputs 1 when both inputs agree, 0 when they differ
- **Accumulator** — a 17-bit counter that sums XNOR outputs over 65536 clock cycles
- **Output latch** — every 65536 cycles (~1.3 ms at 50 MHz), the top 6 bits of the accumulator are latched and `latch_out` toggles to signal new data
- **LED blinker** — a 25-bit counter drives the onboard LED at ~1.5 Hz as a visual heartbeat

The 6-bit correlation output represents a score from 0 to 63:
- **63** → perfect correlation (signals in phase)
- **32** → uncorrelated (orthogonal or different frequencies)
- **0** → anti-correlated (signals 180° out of phase)

The normalised correlation used for fringe visibility is:

```
normalised = (score / 63.0 - 0.5) × 2.0
```

This maps the output to the range [-1, +1] centred at 0 for uncorrelated signals.


## Flashing and Running

### 1. Generate the bitstream
Open `main.v` in GO Configure Software Hub, synthesise, map IO pins as per the table above, and generate the bitstream. The output file is `FPGA_bitstream_MCU.bin` located in `ffpga/build/bitstream/`.

### 2. Upload to Shrike
- Place `FPGA_bitstream_MCU.bin` in the `data/` folder of the Arduino sketch
- Open the Arduino sketch in Arduino IDE
- Upload the sketch via **Upload**
- Then upload the bitstream via **Tools → Pico LittleFS Data Upload**

The FPGA will be automatically flashed from RP2040 flash memory on every power-up.

### 3. Reading correlation output
Open Arduino Serial Monitor at **115200 baud**. Correlation scores print as normalised values (-1 to +1) every time a new window completes.

### 4. Live plot on PC
Run the Python script to see a live plot of the correlation counts.

Note: Update the serial port in `plot.py` to match your system (`/dev/tty.usbmodemXXXX` on Mac, `COMx` on Windows).

---

## Science Goals

### Fringe visibility
As the Sun drifts through the antenna beam (drift scan mode), the correlation output oscillates giving rise to interference fringes. Fringe visibility is measured as:

$$V = \frac{P_{max} - P_{min}}{P_{max} + P_{min}}$$

where P_max and P_min are the maximum and minimum normalised correlation values observed during the transit.

### Angular diameter measurement
By varying the baseline length between the two dishes and measuring fringe visibility at each length, the angular diameter of the Sun can be estimated from the first null of the visibility curve:

$$\theta = \frac{1.22 \lambda}{d_{null}}$$

At 11.2 GHz (λ = 2.68 cm), the first null is expected around **d ≈ 3.4 m** for the Sun's angular diameter of ~33 arcminutes.

### Calibration
Geostationary Ku-band satellites (visible over India: INSAT 3A, 4A etc.) are used as gain calibrators. Their EIRP is known and stable, so daily measurements of the satellite signal before and after solar observations allow correction for receiver gain drift — the same technique used in the IIA experiment.

---

## Reference

Gireesh, G.V.S., Kathiravan, C., Barve, I.V., Ramesh, R. (2021).
*Radio Interferometric Observations of the Sun Using Commercial Dish TV Antennas.*
Solar Physics, 296, 121.
https://doi.org/10.1007/s11207-021-01871-9

---

## License

MIT License.

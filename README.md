# fpga-radio-correlator

**FPGA-based 1-bit digital correlator for radio interferometry**

A two-element radio interferometer built around the Vicharak Shrike Lite FPGA board and two commercial dish TV antennas, designed for solar observations at 11.2 GHz. This project replicates the experiment described in [Gireesh et al. (2021)](https://doi.org/10.1007/s11207-021-01871-9) from the Indian Institute of Astrophysics, Gauribidanur, which demonstrated successful radio interferometric observations of the Sun using off-the-shelf Ku-band dish antennas.

---

## Background

A radio interferometer measures the correlation between signals received at two spatially separated antennas. When a radio source (like the Sun) is in view, the signals at the two antennas arrive at different times due to the geometric delay as the wavefront travels from one antenna to the other. By correlating these two signals, you can extract information about the angular size and brightness of the source that a single antenna cannot provide.

This project implements the correlator digitally on an FPGA. The analog signal from each antenna's LNB (Low Noise Block) is downconverted to a 10 MHz IF signal, passed through a precision comparator (AD790JN) that converts it to a 1-bit digital signal (0 or 1), and then fed into the FPGA. The FPGA samples both channels synchronously, computes their XNOR (1-bit correlation), and outputs the raw result on a single GPIO pin. The RP2040 microcontroller accumulates this output in software over ~8.3 million samples and reports the correlation fraction to a host PC over USB.

---

## Signal Chain

```
Ku-band sky signal (10.7–12.75 GHz)
        │
        ▼
[Ku-band LNB]
  Internal LO: 9.75 GHz (low band) / 10.60 GHz (high band)
  Output IF:   950–2150 MHz L-band
  Gain:        55 dB  |  Noise figure: 0.3 dB
        │
        ▼
[Bias Tee (12 V)]
        │
        ▼
[Bandpass Filter @ 1420 MHz]
        │
        ▼
[Low Noise Amplifier @ 1420 MHz]
        │
        ▼
[Mixer × Local Oscillator @ 1.41 GHz]  →  1420 - 1410 = 10 MHz IF
        │
        ▼
[Bandpass Filter @ 10 MHz, ~2 MHz bandwidth]
        │
        ▼
[Amplifier]
        │
        ▼
[AD790JN Precision Comparator]  →  1-bit digitised signal
        │
        ▼
[FPGA — Shrike Lite — XNOR Correlator]  →  single XNOR output pin
        │
        ▼
[RP2040 — 23-bit counter — USB Serial to PC]
```

---

## FPGA Design

The correlator is implemented in Verilog (`main.v`) and consists of four stages:

### Stage 1 — Clock Divider (50 MHz → ~8.33 MHz effective)

The ForgeFPGA SLG47910V internal oscillator runs at 50 MHz via the dedicated `OSC_CLK` IOB. A 3-bit counter generates a `sample_en` pulse every 6 clock cycles, giving an effective sample rate of:

```
50 MHz / 6 = 8.33 MHz effective sample rate
Sample period = 120 ns
```

All sampling and XNOR logic gates on `sample_en` rather than using a divided clock — this avoids derived clock routing violations in the placer and keeps the design in a single clock domain.

### Stage 2 — Input D Flip-Flops

Two D flip-flops sample `ant_a` and `ant_b` on every `sample_en` pulse i.e. at 8.33 MHz. Both channels are captured at exactly the same clock edge, providing synchronous sampling essential for coherent correlation.

### Stage 3 — XNOR Gate

A registered XNOR gate compares the two sampled bits on every `sample_en` pulse:

- **Output = 1** when both channels agree (correlated signal present)
- **Output = 0** when channels disagree (uncorrelated signal)

Implemented as `~(dff_a ^ dff_b)` registered into `xnor_reg` — one LUT in the FPGA fabric.

### Stage 4 — Direct Output

The registered XNOR result is driven directly onto a single GPIO pin (`xnor_out`) to the RP2040. There is no accumulator or window logic in the FPGA. All accumulation is handled in software on the RP2040. This keeps the FPGA design minimal and moves flexibility into software.

### LED Heartbeat

A 28-bit counter running on the full 50 MHz clock drives the onboard LED at approximately **0.2 Hz** (one blink every ~5 seconds) as a visual indicator that the FPGA is running.

---

## IO Pin Assignments

Configured in the ForgeFPGA Workshop IO Planner. Only essential signals are assigned, all other GPIOs are left unconnected. 

Pin assignments are made in the I/O planner of the Forge FPGA workshop. The GPIOxy_IN/GPIOxy_OUT/GPIOxy_OE pins correspond to the physical Fxy labels on the board. These pins can be configured as input/output pins in the I/O planner. Each output pin needs to be enabled by setting the output enable pins (OE pins) as high. The Shrike-Lite board also features an 8-bit interconnect bus between the FPGA and the RP2040. We use one of these interconnect pins to send the raw correlation counts to the RP2040 for integration. Refer to the [Shrike-Lite Pin Outs](https://vicharak-in.github.io/shrike/shrike_pinouts.html) for more details.

### FPGA GPIO → Physical Pin Mapping

| Signal | Direction | GPIO | Physical PIN | OE | Notes |
|---|---|---|---|---|---|
| `clk_in` | Input | OSC_CLK IOB | — | — | Internal 50 MHz oscillator — assign to OSC_CLK IOB row in IO Planner |
| `osc_en` | Output | OSC_EN IOB | — | — | Tied HIGH — assign to OSC_EN IOB row in IO Planner |
| `ant_a` | Input | GPIO1 | F1 | 0 | 1-bit signal from Comparator A output |
| `ant_b` | Input | GPIO2 | F2 | 0 | 1-bit signal from Comparator B output |
| `xnor_out` | Output | GPIO6 | F6 | 1 | Raw XNOR result → RP2040 GPIO 0 |
| `xnor_oe` | Output | GPIO6 OE |--| — | Output enable — tied HIGH |
| `led` | Output | GPIO16 | F16 | 1 | Onboard LED heartbeat |
| `led_en` | Output | GPIO16 OE | -- | — | Output enable — tied HIGH |

### RP2040 GPIO Mapping

| RP2040 GPIO (Arduino) | Connected to | Notes |
|---|---|---|
| GPIO 0 | FPGA GPIO6 (`xnor_out`) | Single correlation bit, read via `sio_hw->gpio_in`.
---

## Comparator Front-End — AD790JN

Each antenna channel uses an AD790JN precision comparator to digitise the 10 MHz IF signal.

### Comparator Pin Connections

| Pin | Name | Connect To | Notes |
|---|---|---|---|
| 1 | +VS | +5V | Decouple with 100nF to GND |
| 2 | +IN | Signal via 1.5nF cap | AC coupled RF input |
| 3 | −IN | DC offset voltage | Measure DC at +IN with multimeter, set −IN to match |
| 4 | −VS | −5V | Decouple with 100nF to GND |
| 5 | LATCH | +5V via 510Ω | Keep HIGH — transparent mode. Never ground |
| 6 | GROUND | GND | Must share common ground with FPGA board |
| 7 | OUTPUT | Voltage divider → FPGA GPIO | 5V output divided to 3.11V safe for 3.3V FPGA GPIO |
| 8 | VLOGIC | +5V | Decouple with 100nF to GND |

### Output Voltage Divider

The AD790 output swings to VLOGIC (5V) but the Shrike-Lite GPIOs are 3.3V maximum. A resistor divider brings the HIGH level to a safe 3.11V:

```
AD790 OUTPUT ──[2kΩ]──┬──── FPGA GPIO (ant_a or ant_b)
                      │
                   [3.3kΩ]
                      │
                     GND

V_out = 5V × 3300 / (2000 + 3300) = 3.11V ✓
```

### DC Offset Calibration

After AC coupling the RF signal via the 1.5nF capacitor on +IN, measure the DC voltage at +IN with a multimeter. Set −IN to that exact reading. This ensures the comparator threshold sits at the signal's DC midpoint, giving clean zero crossings on every RF cycle.

With the comparator switching correctly, Pin 7 (OUTPUT) reads approximately **1.65V** on a multimeter — the meter averages the rapid 0V/5V switching at 10 MHz to the midpoint.

---

## Flashing and Running

Refer to the [Bitstream-generation tutorial](https://vicharak-in.github.io/shrike/generating_your_first_bitstream.html) and [FPGA-flashing tutorial](https://vicharak-in.github.io/shrike/getting_started.html) by Shrike for more detailed instructions.

### 1. Generate the bitstream

Open `main.v` in GO Configure Software Hub (ForgeFPGA Workshop):

1. Paste the Verilog into the FPGA Editor
2. Run **Synthesise** — check messages panel for errors
3. Run **Place & Route**
4. Assign IO pins in the **IO Planner** as per the table above
5. Run **Generate Bitstream**
6. Output: `FPGA_bitstream_MCU.bin` in `ffpga/build/bitstream/`

### 2. Upload to Shrike

- Place `FPGA_bitstream_MCU.bin` in the `data/` folder of the Arduino sketch
- Open the Arduino sketch in Arduino IDE
- Select board: **Raspberry Pi Pico** (Earle Philhower package)
- Select **Flash Size** with filesystem (e.g. `2MB (Sketch: 1MB, FS: 1MB)`)
- Upload the sketch via **Upload**
- Upload the bitstream via **Tools → Pico LittleFS Data Upload**

The RP2040 automatically flashes the FPGA bitstream from LittleFS on every power-up.

### 3. Reading correlation output

Open Arduino Serial Monitor at **115200 baud**. Each line prints a correlation fraction after ~1 second of integration:

```
0.734521
0.731842
0.729103
```

Output range:

| Value | Meaning |
|---|---|
| ~1.0 | Perfect correlation — identical signals (e.g. power splitter test) |
| ~0.5 | Noise floor — uncorrelated independent signals |
| ~0.0 | Anti-correlated — signals 180° out of phase |

### 4. Live plot on PC

```bash
python plot.py
```

Update the serial port in `plot.py` to match your system (`/dev/tty.usbmodemXXXX` on Mac/Linux, `COMx` on Windows).

---

## Integration Time and Sampling

### Effective Sample Rate

```
FPGA clock:      50 MHz
Clock divider:   ÷ 6  (counter resets at 5, fires sample_en on 0)
Effective rate:  8.33 MHz
Sample period:   120 ns
```

### RP2040 Accumulation

The RP2040 reads the XNOR pin 8,388,608 times (2²³) with a 15-NOP delay between reads to match the FPGA sample period:

```cpp
__asm volatile ("nop\nnop\nnop\nnop\nnop\n"
                "nop\nnop\nnop\nnop\nnop\n"
                "nop\nnop\nnop\nnop\nnop\n");
```

```
15 NOPs × 8 ns (125 MHz RP2040) = 120 ns delay per read
8,388,608 samples × 120 ns     = ~1.006 seconds per integration window
```

The NOP delay ensures each read captures a genuinely independent FPGA output sample rather than oversampling the same value multiple times between XNOR updates.

### Output Formula

```
raw output  = count / 8,388,608        →  range: 0.0 to 1.0
normalised  = (raw - 0.5) × 2.0       →  range: -1.0 to +1.0
```

---

## Nyquist and Bandpass Sampling

| Parameter | Value |
|---|---|
| Effective sample rate | 8.33 MHz |
| Signal bandwidth | ~2 MHz centred at 10 MHz IF |
| Nyquist minimum | 4 MHz (2 × bandwidth) |
| Oversampling margin | 2.08× |

The 10 MHz IF signal aliases to baseband when sampled at 8.33 MHz. Both channels alias identically so the correlation between them is fully preserved through the aliasing process — this is intentional bandpass sampling, the same technique used in many professional radio astronomy backends.

---

## Science Goals

### Fringe visibility

As the Sun drifts through the antenna beam (drift scan mode), the correlation output oscillates giving rise to interference fringes. Fringe visibility is measured as:

$$V = \frac{P_{max} - P_{min}}{P_{max} + P_{min}}$$

where P_max and P_min are the maximum and minimum correlation values observed during the transit.

### Angular diameter measurement

By varying the baseline length between the two dishes and measuring fringe visibility at each length, the angular diameter of the Sun can be estimated from the first null of the visibility curve:

$$\theta = \frac{1.22 \lambda}{d_{null}}$$

At 11.2 GHz (λ = 2.68 cm), the first null is expected around **d ≈ 3.4 m** for the Sun's angular diameter of ~33 arcminutes.

### Calibration

Geostationary Ku-band satellites visible over India (INSAT 3A, 4A etc.) are used as gain calibrators. Their EIRP is known and stable, so daily measurements of the satellite signal before and after solar observations allow correction for receiver gain drift — the same technique used in the IIA experiment.

---

## Reference

Gireesh, G.V.S., Kathiravan, C., Barve, I.V., Ramesh, R. (2021).
*Radio Interferometric Observations of the Sun Using Commercial Dish TV Antennas.*
Solar Physics, 296, 121.
https://doi.org/10.1007/s11207-021-01871-9

---

## License

MIT License.

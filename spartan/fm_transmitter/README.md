
# FM transmitter

This is a FPGA only based FM transmitter. By toggling a GPIO at the correct frequency a FM signal in the radio range can be generated, attaching a piece o wire is enough for emiting the signal to close by sources. DO NOT use this for extended periods as it interferes with standardized radio bands. It makes you think about EMI when designing with high speed signals.

Based on the work described at http://hamsterworks.co.nz/mediawiki/index.php/FM_SOS.

![img_20160226_165218](https://cloud.githubusercontent.com/assets/3289118/13369429/7af6dc4e-dca9-11e5-8961-51e5125a5b39.jpg)

## Operation
An overflowing counter provides a way to do a fractional division (*2.70327* in this case) of a high speed clock (*256 MHz*). This doesn't generate  a waveform that has that exact frequency, but one that averages out to that frequency. By changing the division ratio the frequency can be modulated. Apart from that this transmitter is simply using the blockRAM to store an audio waveform that's used as input. Check the reference above for more information on the FM modulator.

![image](https://cloud.githubusercontent.com/assets/3289118/13369637/f9c72180-dcab-11e5-82f3-b806c77411cb.png)

Here is an RTL view to give a sense of the transmitter circuitry. It's tricky section is a 32 adder looping into itself in one of the inputs, the top bit i the output.
![image](https://cloud.githubusercontent.com/assets/3289118/13369134/4616e792-dca6-11e5-9182-287bf67830de.png)

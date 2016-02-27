# SoftCore

Objective: Run a simple software on a soft core in the FPGA. Since Xilinx offers the [microblaze](http://www.xilinx.com/products/design-tools/microblaze.html) core on their IP generator that seemed like a good option. The software is now running a simple ["Hello World"](https://github.com/arthurbenemann/fpga-bits/blob/master/softcore/firmware/hello_world/src/helloworld.c) program, which prints some characters on the serial port and blinks the LEDs.
![img_20160226_203152-animation](https://cloud.githubusercontent.com/assets/3289118/13370796/2518a34c-dcc8-11e5-9930-662fb11474d1.gif)

![image](https://cloud.githubusercontent.com/assets/3289118/13370694/742dce2a-dcc4-11e5-8093-cb2421c236a0.png)

## Instructions
 It's best to follow the instructions on the references bellow, but be aware that you will require the [Vivado WebPACK and SDK](http://www.xilinx.com/support/download.html) in addition to the Xilinx ISE tool. The setup of the enviroment is cumbersome, but it runs quickly after that.

## References
http://ece.wpi.edu/~rjduck/Microblaze%20MCS%20Tutorial%20v5.pdf
http://jimselectronicsblog.blogspot.com/2014/03/implementing-microblaze-mcs-on-papilio.html

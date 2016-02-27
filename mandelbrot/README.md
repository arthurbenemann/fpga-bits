# VGA Mandelbrot generator
Objective: Generate a Mandelbrot set on the VGA interface on the highest resolution achievable.

Refer for [wikipedia](https://en.wikipedia.org/wiki/Mandelbrot_set) for a description of a mandelbrot set, sufice to say it's a nice fractal. Generating it requires a significant amount of computation.

To make it easier there is no RAM being used, and every pixel is generated on the fly. The benefit is that it guarantees a 60Hz (the VGA interface used is 800x600@60Hz) update rate no matter what, the downside is there is only 25 ns to calculate each pixel.

Using the DSP slices of the FPGA eases the process, with the complex number multiplier ip it's even simpler. The way that the processing pipeline is working is a bit messed up but overall the code should be readable

## Log
* 02/05/2016 - Fixed issue with carry bit, adjusted color palette
https://github.com/arthurbenemann/fpga-bits/commit/2602ee35af7b9463a9511dff745c37a8582c4eea
![img_20160225_212413-2](https://cloud.githubusercontent.com/assets/3289118/13343976/961f4036-dc06-11e5-865b-ac19dabbe47d.jpg)

* 02/25/2016 - increased clock to 200MHz, improved pipeline https://github.com/arthurbenemann/fpga-bits/commit/419e1b55ede8eafb9513e2de4ab0315f6ebe454a   ![img_20160225_165922](https://cloud.githubusercontent.com/assets/3289118/13342682/ea7f1d3a-dbf8-11e5-9ca5-b5478bc63855.jpg)

* 02/24/2016 - fixed problems with overflow, escape threshold, and added a color palette https://github.com/arthurbenemann/fpga-bits/commit/eb16559aef5e0deebe4bbc7332032b6793cef298 ![img_20160224_181208-2](https://cloud.githubusercontent.com/assets/3289118/13307768/9c59a8fe-db22-11e5-86a4-e3e03902f5e6.jpg)

* 02/24/2016 - first mandelbrot like image
https://github.com/arthurbenemann/fpga-bits/commit/4998a43cf4c13f5e02f9a34a7f6d8dfd2982f961 ![img_20160224_161835-2](https://cloud.githubusercontent.com/assets/3289118/13305827/2900dac6-db13-11e5-9b01-e997bb9530b5.jpg)

## References
http://hamsterworks.co.nz/mediawiki/index.php/DSPfract

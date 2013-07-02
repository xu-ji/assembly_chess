assembly_chess
==============

An assembler for assembling a fully working bare metal assembly chess game 
for the Raspberry Pi. 

Created by Xu Ji, Bora Mollamustafaoglu, Gun Pinyo (Imperial College London) 
{xj1112, bm1212, gp1712}@imperial.ac.uk 


The assembler, dcd_gen program and chess game were created as part of 
our first year C project. Feel free to check out our report, which was submitted
as part of the assessment, and the slides used in the formal presentation, both 
included in this repo. A brief demo of the game can be found here: 
www.youtube.com/watch?v=-03bouPsfEQ

The programs directory contains the assembly programs and assembler binary, and 
the src directory contains dcd_gen.  

To set up the chess game on your own Pi, you will need to first go into the 
programs directory and "make chess", which will use the assembler to assemble the 
chess game. The binary file kernel.img, which is created in the programs 
directory during the make, can then be loaded onto your SD card and inserted 
into the Pi. 

Your SD card should have been formatted and freshly installed with Raspbian OS. 
You should then overwrite it by replacing kernel.img inside the boot partition 
with the kernel.img you just created.

In addition to a Pi and an SD card you will also need a screen which can be 
connected to the Pi using a HDMI cable, and six momentary push buttons wired up 
to the GPIO pins of the Pi in the following fashion:

GPIO18 = left
GPIO23 = up
GPIO4 = down
GPIO17 = right
GPIO22 = select
GPIO27 = reset (restarts the game) 

For this setup we also used a breadboard, 6 10K Ohm resistors, 6 1K Ohm resistors 
and several male-female and male-male jumper wires.
  

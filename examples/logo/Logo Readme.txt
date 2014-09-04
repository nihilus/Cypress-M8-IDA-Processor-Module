***** 637xx Logo Firmware Readme *****

2/16/2000


This release has three files 

* 637xx.inc
* USB.inc
* 637logo.asm

637xx.inc contains the register addresses and bit 
constants for the CY7C637xx series of microcontrollers.

USB.inc contains constants from the USB specification,
mostly from Chapter 9.

637logo.asm is the main file that handles endpoint 0 and 1.
This firmware enumerates as a HID mouse and sends mouse
movement to the host every time it gets an IN on endpoint 1.
If you turn on mouse cursor trails, you should see USB
being drawn on the screen.

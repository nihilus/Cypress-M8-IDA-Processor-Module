***** 637xx Mouse Firmware Readme *****

2/16/2000


This release has three files 

* 637xx.inc
* USB.inc
* mouse.asm

637xx.inc contains the register addresses and bit 
constants for the CY7C637xx series of microcontrollers.

USB.inc contains constants from the USB specification,
mostly from Chapter 9.

Mouse.asm is the main file that handles endpoint 0 and 1, 
mouse optics, mouse buttons, suspend and remote wakeup.  
The firmware enumerates as a HID mouse and runs standard
mouse buttons and optics.

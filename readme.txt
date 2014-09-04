Cypress enCoRe M8 A/B Processor Module for IDA 6.1

This module allows you to disassemble firmware dumps for Cypress' enCoRe M8 A/B MCU using IDA 6.1
The M8B core is commonly used inside older low-speed USB devices (eg. Rainbow/SafeNet SuperPro, UltraPro, iKey, ...)
To install this module copy the file 'm8b.cfg' to <IDA61>\cfg and 'm8b.w32' to <IDA61>\procs
The processor type name is 'Cypress enCoRe/M8 USB:m8b'
At the moment only CY7C63722, CY7C63723 and CY7C63743 are supported.
But you can easily add new MCUs by editing the configuration file 'm8b.cfg'

If you need a 64bit version of this module you'll have to recompile it yourself!
Copy the 'm8b' folder to <IDA61SDK>\module and open the solution with Visual Studio 2005.
You'll probably need to change the path to IDA 6.1 inside the custom build step!

Features:
- All I/O ports are mapped to the XTRN segment and have cross-references
- The module will try to decode I/O port values
- Simple JACC jump-tables are recognized
- The location of both stack pointers (DSP,PSP) will be marked inside the RAM segment
- You can also modify the config file to insert additional RAM markers (see 'alias' keyword)

I've also included some additional stuff for easily getting started:
- Cypress' cyasm.exe and user manual
- CY7C637xx data sheet
- two example files from the CY3644 development kit

zementmischer (2012-09-10)

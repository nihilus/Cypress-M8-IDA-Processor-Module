
; processor registers
port0:				equ	00h
port1:				equ	01h
port2:				equ	02h

port0_int:			equ	04h
port1_int:			equ	05h
port0_int_polarity:	equ	06h
port1_int_polarity:	equ	07h

port0_mode0:		equ	0Ah
port0_mode1:		equ	0Bh
port1_mode0:		equ	0Ch
port1_mode1:		equ	0Dh

usb_address:		equ	10h
ep0_count:			equ	11h
ep0_mode:			equ	12h
ep1_count:			equ	13h
ep1_mode:			equ	14h
ep2_count:			equ	15h
ep2_mode:			equ	16h
usb_status:			equ	1Fh

global_int:			equ	20h
endpoint_int:		equ	21h
timer_lsb:			equ	24h
timer_msb:			equ	25h
watchdog:			equ	26h

capturea_rising:	equ	40h
capturea_falling:	equ	41h
captureb_rising:	equ	42h
captureb_falling:	equ	43h
capture_config:		equ	44h
capture_status:		equ	45h

spi_data:			equ	60h
spi_control:		equ	61h

clock_config:		equ	F8h
control:			equ	FFh

; Port 2 Data Register 0x02 bit assignments
SCLK:				equ	20h
DPLUS:				equ	20h
SDATA:				equ	10h
DMINUS:				equ	10h
XTALIN:				equ	02h
VREG:				equ	01h

; USB Port status and control register 0x1F bit assignments
PS2_PULLUP:			equ	80h
VREG_ENABLE:		equ	40h
USB_PS2_MODE:		equ	20h
BUS_ACTIVITY:		equ	08h
CONTROL2:			equ	04h
CONTROL1:			equ	02h
CONTROL0:			equ	01h

NOT_FORCING:		equ	00h
FORCE_K:			equ	01h
FORCE_J:			equ	02h
FORCE_SE0:			equ	03h
FORCEBOTH_LOW:		equ	40h
FORCESDATA_LOW:		equ	05h
FORCESCLK_LOW:		equ	06h
FORCE_HIZ:			equ	07h

; USB Device Address Registers 0x10 bit assignments
ADDRESS_ENABLE:		equ	80h
ADDRESS_MASK:		equ	7Fh

; USB Device EP0 Mode Register 0x12
EP0_SETUP:			equ	80h
EP0_IN:				equ	40h
EP0_OUT:			equ	20h
EP0_ACK:			equ	10h
MODE_MASK:			equ	0Fh

; USB Device Endpoint Mode Registers 0x14, 0x16
EP_STALL:			equ	80h
EP_ACK:				equ	10h

; USB Device Counter Registers 0x11, 0x13, 0x15
DATA_TOGGLE:		equ	80h
DATA_VALID:			equ	40h
BYTE_COUNT:			equ	0Fh

;Capture Timers Configuration Register 0x44
FIRST_EDGE_HOLD:	equ	80h
PRESCALE:			equ	70h
PRESCALE2:			equ	40h
PRESCALE1:			equ	20h
PRESCALE0:			equ	10h
CAPTUREB_FALL_INT:	equ	08h
CAPTUREB_RISE_INT:	equ	04h
CAPTUREA_FALL_INT:	equ	02h
CAPTUREA_RISE_INT:	equ	01h

;Capture Timers Status Register 0x45
CAPTUREB_FALL_EVENT:	equ	08h
CAPTUREB_RISE_EVENT:	equ	04h
CAPTUREA_FALL_EVENT:	equ	02h
CAPTUREA_RISE_EVENT:	equ	01h

;Processor Status and Control Register 0xFF
IRQ_PENDING:		equ	80h
WDR:				equ	40h
USB_RESET:			equ	20h
POR_RESET:			equ	10h
SUSPEND:			equ	08h
INT_ENABLE_SENSE:	equ	04h
RUN:				equ	01h

; global interrupt enable register 0x20 bit assignments
WAKEUP_INT:			equ	80h
GPIO_INT:			equ	40h
CAPTUREB_INT:		equ	20h
CAPTUREA_INT:		equ	10h
SPI_INT:			equ	08h
1MS_INT:			equ	04h
128US_INT:			equ	02h
USB_RESET_INT:		equ	01h

; USB Endpoint Interrupt Enable Register 0x21 bit assignments
EP2_INT:			equ	04h
EP1_INT:			equ	02h
EP0_INT:			equ	01h

; SPI Control Register 0x61 bit assignments
TCMP:				equ	80h
TBF:				equ	40h
MODE1:				equ	20h
MODE0:				equ	10h
CPOL:				equ 08h
CPHA:				equ 04h
SCK_SELECT1:		equ 02h
SCK_SELECT0:		equ	01h	

; Clock Configuration Register 0xF8 bit assignments
EXT_DELAY:			equ	80h
WAKEUP_ADJUST2:		equ	40h
WAKEUP_ADJUST1:		equ	20h
WAKEUP_ADJUST0:		equ	10h
LVR_ENABLE:			equ	08h
INTERNAL_CLK:		equ	02h
EXTERNAL_CLK:		equ	01h

; USB register mode encoding
DISABLE:			equ	00h
NAK_IN_OUT:			equ	01h
STATUS_OUT_ONLY:	equ	02h
STALL_IN_OUT:		equ	03h
IGNORE_IN_OUT:		equ	04h
ISOCHRONOUS_OUT:	equ	05h
STATUS_IN_ONLY:		equ	06h
ISOCHRONOUS_IN:		equ	07h
NAK_OUT:			equ	08h
ACK_OUT:			equ	09h
NAK_OUT_STATUS_IN:	equ	0Ah
ACK_OUT_NAK_IN:		equ	0Bh
NAK_IN:				equ	0Ch
ACK_IN:				equ	0Dh
NAK_IN_STATUS_OUT:	equ	0Eh
ACK_IN_STATUS_OUT:	equ	0Fh


SET:				equ	FFh
CLEAR:				equ	00h
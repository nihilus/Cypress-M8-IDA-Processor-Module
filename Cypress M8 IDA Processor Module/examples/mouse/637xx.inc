;**************************************
; Processor specific definitions

ep2_dmabuff:				equ	E8h
ep2_dmabuff0:				equ	ep2_dmabuff+0
ep2_dmabuff1:				equ	ep2_dmabuff+1
ep2_dmabuff2:				equ	ep2_dmabuff+2
ep2_dmabuff3:				equ	ep2_dmabuff+3
ep2_dmabuff4:				equ	ep2_dmabuff+4
ep2_dmabuff5:				equ	ep2_dmabuff+5
ep2_dmabuff6:				equ	ep2_dmabuff+6
ep2_dmabuff7:				equ	ep2_dmabuff+7

ep1_dmabuff:				equ	F0h
ep1_dmabuff0:				equ	ep1_dmabuff+0
ep1_dmabuff1:				equ	ep1_dmabuff+1
ep1_dmabuff2:				equ	ep1_dmabuff+2
ep1_dmabuff3:				equ	ep1_dmabuff+3
ep1_dmabuff4:				equ	ep1_dmabuff+4
ep1_dmabuff5:				equ	ep1_dmabuff+5
ep1_dmabuff6:				equ	ep1_dmabuff+6
ep1_dmabuff7:				equ	ep1_dmabuff+7

ep0_dmabuff:				equ	F8h
ep0_dmabuff0:				equ	ep0_dmabuff+0
ep0_dmabuff1:				equ	ep0_dmabuff+1
ep0_dmabuff2:				equ	ep0_dmabuff+2
ep0_dmabuff3:				equ	ep0_dmabuff+3
ep0_dmabuff4:				equ	ep0_dmabuff+4
ep0_dmabuff5:				equ	ep0_dmabuff+5
ep0_dmabuff6:				equ	ep0_dmabuff+6
ep0_dmabuff7:				equ	ep0_dmabuff+7



;**************************************
; register definitions

port0:								equ	00h ; GPIO data port 0
port1:								equ	01h ; GPIO data port 1
port2:								equ	02h ; GPIO data port 2
	SCLK:					equ	20h
	DPLUS:					equ	20h
	SDATA:					equ	10h
	DMINUS:					equ	10h
	XTALIN:					equ	02h
	VREG:					equ	01h

port0_int:							equ	04h ; Interrupt enable for Port 0
port1_int:							equ	05h ; Interrupt enable for Port 1
port0_int_polarity:					equ	06h ; Interrupt polarity for Port 0
port1_int_polarity:					equ	07h ; Interrupt polarity for Port 1

port0_mode0:						equ	0Ah ; Mode Configuration 0 for Port 0
port0_mode1:						equ	0Bh ; Mode Configuration 1 for Port 0
port1_mode0:						equ	0Ch ; Mode Configuration 0 for Port 1
port1_mode1:						equ	0Dh ; Mode Configuration 1 for Port 1

usb_address:						equ	10h ; USB device address
	ADDRESS_ENABLE:			equ	80h
	ADDRESS_MASK:			equ	7Fh

ep0_count:							equ	11h	; Endpoint 0 counter
	DATA_TOGGLE:			equ	80h
	DATA_VALID:				equ	40h
	BYTE_COUNT:				equ	0Fh
ep0_mode:							equ	12h ; Endpoint 0 configuration
	EP0_SETUP:				equ	80h
	EP0_IN:					equ	40h
	EP0_OUT:				equ	20h
	EP0_ACK:				equ	10h
	MODE_MASK:				equ	0Fh
ep1_count:							equ	13h ; Endpoint 1 counter
ep1_mode:							equ	14h ; Endpoint 1 configuration
ep2_count:							equ	15h ; Endpoint 2 counter
ep2_mode:							equ	16h ; Endpoint 2 configuration
	EP_STALL:				equ	80h
	EP_ACK:					equ	10h

usb_status:							equ	1Fh ; USB upstream status and control
	PS2_PULLUP:				equ	80h
	VREG_ENABLE:			equ	40h
	USB_PS2_MODE:			equ	20h
	BUS_ACTIVITY:			equ	08h
	CONTROL2:				equ	04h
	CONTROL1:				equ	02h
	CONTROL0:				equ	01h

	NOT_FORCING:			equ	00h
	FORCE_K:				equ	01h
	FORCE_J:				equ	02h
	FORCE_SE0:				equ	03h
	FORCEBOTH_LOW:			equ	04h
	FORCESDATA_LOW:			equ	05h
	FORCESCLK_LOW:			equ	06h
	FORCE_HIZ:				equ	07h

global_int:							equ	20h ; Global interrupt enable
	WAKEUP_INT:				equ	80h
	GPIO_INT:				equ	40h
	CAPTUREB_INT:			equ	20h
	CAPTUREA_INT:			equ	10h
	SPI_INT:				equ	08h
	1MS_INT:				equ	04h
	128US_INT:				equ	02h
	USB_RESET_INT:			equ	01h

endpoint_int:						equ	21h ; USB endpoint interrupt enable
	EP2_INT:				equ	04h
	EP1_INT:				equ	02h
	EP0_INT:				equ	01h

timer_lsb:							equ	24h ; Lower eight bits of timer
timer_msb:							equ	25h ; Upper six bits of timer
watchdog:							equ	26h ; Clear watchdog Timer

capturea_rising:					equ	40h ; Capture timer A rising register
capturea_falling:					equ	41h ; Capture timer A falling register
captureb_rising:					equ	42h ; Capture timer B rising register
captureb_falling:					equ	43h ; Capture timer B falling register
capture_config:						equ	44h ; Capture timer configuration register
	FIRST_EDGE_HOLD:		equ	80h
	PRESCALE:				equ	70h
	PRESCALE2:				equ	40h
	PRESCALE1:				equ	20h
	PRESCALE0:				equ	10h
	CAPTUREB_FALL_INT:		equ	08h
	CAPTUREB_RISE_INT:		equ	04h
	CAPTUREA_FALL_INT:		equ	02h
	CAPTUREA_RISE_INT:		equ	01h
capture_status:						equ	45h ; Capture timer status register
	CAPTUREB_FALL_EVENT:	equ	08h
	CAPTUREB_RISE_EVENT:	equ	04h
	CAPTUREA_FALL_EVENT:	equ	02h
	CAPTUREA_RISE_EVENT:	equ	01h

spi_data:							equ	60h	; SPI data register
spi_control:						equ	61h	; SPI configuration register
	TCMP:					equ	80h
	TBF:					equ	40h
	MODE1:					equ	20h
	MODE0:					equ	10h
	CPOL:					equ 08h
	CPHA:					equ 04h
	SCK_SELECT1:			equ 02h
	SCK_SELECT0:			equ	01h	

clock_config:						equ	F8h ; Internal/external oscillator configuration
	EXT_DELAY:				equ	80h
	WAKEUP_ADJUST2:			equ	40h
	WAKEUP_ADJUST1:			equ	20h
	WAKEUP_ADJUST0:			equ	10h
	LVR_DISABLE:			equ	08h
	PRECISION_CLK:			equ 04h
	INTERNAL_CLK:			equ	02h
	EXTERNAL_CLK:			equ	01h

control:							equ	FFh ; Processor status and control
	IRQ_PENDING:			equ	80h
	WATCHDOG_RESET:			equ	40h
	USB_RESET:				equ	20h
	POWERON_RESET:			equ	10h
	SUSPEND:				equ	08h
	INTERRUPT_MASK:			equ	04h
	SINGLE_STEP:			equ	02h
	RUN:					equ	01h


;**************************************
; USB mode encoding

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


;**************************************
; general use constants

SET:				equ	FFh
CLEAR:				equ	00h
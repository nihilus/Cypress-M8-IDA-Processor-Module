
;**********************************************************
; USB Descriptor and Request constants
;	source p172,,175 USB specification
;**********************************************************


;	Characterists of bmRequest Value
;
; D7	Data xfer direction
;	0 = Host to device
;	1 = Device to host
;
; D6..5	Type
;	0 = Standard
;	1 = Class
;	2 = Vendor
;	3 = Reserved
;
; D4..0	Recipient
;	0 = Device
;	1 = Interface
;	2 = Endpoint
;	3 = Other
;	4..31 = Reserved


;***** bmRequestType
HOSTTODEVICE:			equ	00h
DEVICETOHOST:			equ	80h

STANDARD_TYPE:			equ	00h
CLASS_TYPE:				equ	20h
VENDOR_TYPE:			equ	40h
RESERVED_TYPE:			equ	60h

DEVICE_RECIPIENT:		equ	00h
INTERFACE_RECIPIENT:	equ	01h
ENDPOINT_RECIPIENT:		equ	02h
OTHER_RECIPIENT:		equ	03h

;***** bRequest
GET_STATUS:				equ	00h
CLEAR_FEATURE:			equ	01h
SET_FEATURE:			equ	03h
SET_ADDRESS:			equ	05h
GET_DESCRIPTOR:			equ	06h
SET_DESCRIPTOR:			equ	07h
GET_CONFIGURATION:		equ	08h
SET_CONFIGURATION:		equ	09h
GET_INTERFACE:			equ	0Ah
SET_INTERFACE:			equ	0Bh
SYNCH_FRAME:			equ	0Ch

;***** Descriptor Types
DEVICE:					equ	01h
CONFIGURATION:			equ	02h
STRING:					equ	03h
INTERFACE:				equ	04h
ENDPOINT:				equ	05h

;***** Feature Selectors
DEVICE_REMOTE_WAKEUP:	equ	01h
ENDPOINT_STALL:			equ	00h

;***** HID Class Request Types
GET_REPORT:				equ	01h
GET_IDLE:				equ	02h
GET_PROTOCOL:			equ	03h
SET_REPORT:				equ	09h
SET_IDLE:				equ	0Ah
SET_PROTOCOL:			equ	0Bh
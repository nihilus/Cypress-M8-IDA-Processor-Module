;******************************************************
;
;	file: 637xx USB logo firmware
;	Date: 02/16/2000
;	Description: This code draw the USB logo using 
;				a mouse cursor on your monitor.  Turn
;				on mouse trails to see the logo.
;	Target: Cypress CY7C63743
;
;
;	Overview:  There is only one task handled by this
;				firmware, and that is USB.
;
;	USB
;		At bus reset the USB interface is re-initialized,
;		and the firmware soft reboots.  We are then able to
;		handle the standard chapter nine requests on 
;		endpoint zero (the control endpoint).  After this
;		device enumerates as a HID mouse on the USB, the
;		requests come to endpoint one (the data endpoint).
;		Endpoint one is used to send mouse displacement and
;		button status information.  In this case we don't
;		send any button information, just the displacement
;		information to make it appear as though we are moving
;		the mouse in a pattern drawing out the letters
;		U-S-B.  In order to see this, it is best to turn on
;		the mouse cursor trails if you are running MS Windows.	
;
;	Pin Connections
;
;			 -------------------
;			| P0[0]		P0[4]	|
;			| P0[1]		P0[5]	|
;			| P0[2]		P0[6]	|
;			| P0[3] 	P0[7]	|
;			| P1[0]		P1[1]	|	
;			| P1[2]		P1[3]	|
;			| P1[4]		P1[5]	|
;			| P1[6]		P1[7]	|
;	GND		| VSS		D+/SCLK	|	USB D+ / PS2 SCLK
;	GND		| VPP		D-/SDATA|	USB D- / PS2 SDATA
;	PULLUP	| VREG		VCC		|	+5
;			| XTALIN	XTALOUT	|
;			 -------------------
;
; Revisions:
;			2-16-2000	SEA		Creation
;
;**********************************************************
;
;		Copyright 2000 Cypress Semiconductor
;	This code is provided by Cypress as a reference.  Cypress 
;	makes no claims or warranties to this firmware's 
;	suitability for any application. 
;
;********************************************************** 

;**************** assembler directives ***************** 

	CPU	63743

	XPAGEON

	INCLUDE	"637xx.inc"
	INCLUDE "USB.inc"

ep1_dmabuff:			equ	F0h
ep1_dmabuff0:			equ	ep1_dmabuff+0
ep1_dmabuff1:			equ	ep1_dmabuff+1
ep1_dmabuff2:			equ	ep1_dmabuff+2
ep1_dmabuff3:			equ	ep1_dmabuff+3
ep1_dmabuff4:			equ	ep1_dmabuff+4
ep1_dmabuff5:			equ	ep1_dmabuff+5
ep1_dmabuff6:			equ	ep1_dmabuff+6
ep1_dmabuff7:			equ	ep1_dmabuff+7

ep0_dmabuff:			equ	F8h
ep0_dmabuff0:			equ	ep0_dmabuff+0
ep0_dmabuff1:			equ	ep0_dmabuff+1
ep0_dmabuff2:			equ	ep0_dmabuff+2
ep0_dmabuff3:			equ	ep0_dmabuff+3
ep0_dmabuff4:			equ	ep0_dmabuff+4
ep0_dmabuff5:			equ	ep0_dmabuff+5
ep0_dmabuff6:			equ	ep0_dmabuff+6
ep0_dmabuff7:			equ	ep0_dmabuff+7

bmRequestType:			equ	ep0_dmabuff0
bRequest:				equ	ep0_dmabuff1
wValuelo:				equ	ep0_dmabuff2
wValuehi:				equ	ep0_dmabuff3
wIndexlo:				equ	ep0_dmabuff4
wIndexhi:				equ	ep0_dmabuff5
wLengthlo:				equ	ep0_dmabuff6
wLengthhi:				equ	ep0_dmabuff7


; DATA MEMORY VARIABLES
;
suspend_count:			equ	20h		; counter for suspend/resume
ep1_data_toggle:		equ	21h		; data toggle for INs on endpoint one
ep0_data_toggle: 		equ	22h		; data toggle for INs on endpoint zero
data_start:				equ	23h		; address of request response data, as an offset
data_count:				equ	24h		; number of bytes to send back to the host
maximum_data_count:		equ	25h		; request response size
ep0_in_machine:			equ	26h		
ep0_in_flag:			equ	27h
configuration:			equ	28h
ep1_stall:				equ	29h
idle:					equ	2Ah
protocol:				equ	2Bh
temp:					equ	2Ch		; temporary register
event_machine:			equ	2Dh
pending_data:			equ	2Eh
int_temp:				equ	2Fh
idle_timer:				equ	30h
idle_prescaler:			equ	31h
logo_index:				equ	32h
ep0_transtype:			equ	33h

; STATE MACHINE CONSTANTS
;EP0 IN TRANSACTIONS
EP0_IN_IDLE:			equ	00h
CONTROL_READ_DATA:		equ	02h
NO_DATA_STATUS:			equ	04h
EP0_IN_STALL:			equ	06h

; FLAG CONSTANTS
;EP0 NO-DATA CONTROL FLAGS
ADDRESS_CHANGE_PENDING:	equ	00h
NO_CHANGE_PENDING:		equ	02h

; RESPONSE SIZES
DEVICE_STATUS_LENGTH:		equ	2
DEVICE_CONFIG_LENGTH:		equ	1
ENDPOINT_STALL_LENGTH:		equ 2
INTERFACE_STATUS_LENGTH:	equ 2
INTERFACE_ALTERNATE_LENGTH:	equ	1
INTERFACE_PROTOCOL_LENGTH:	equ	1

NO_EVENT_PENDING:			equ	00h
EVENT_PENDING:				equ	02h

;***** TRANSACTION TYPES

TRANS_NONE:						equ	00h
TRANS_CONTROL_READ:				equ	02h
TRANS_CONTROL_WRITE:			equ	04h
TRANS_NO_DATA_CONTROL:			equ	06h


;*************** interrupt vector table ****************

ORG 00h			

jmp	reset				; reset vector		

jmp	bus_reset			; bus reset interrupt

jmp	error				; 128us interrupt

jmp	1ms_timer			; 1.024ms interrupt

jmp	endpoint0			; endpoint 0 interrupt

jmp	endpoint1			; endpoint 1 interrupt

jmp	error				; endpoint 2 interrupt

jmp	error				; reserved

jmp	error				; Capture timer A interrupt Vector

jmp	error				; Capture timer B interrupt Vector

jmp	error				; GPIO interrupt vector

jmp	error				; Wake-up interrupt vector 


;************** program listing ************************

ORG  1Ah
error: halt

;*******************************************************
;
;	Interrupt handler: reset
;	Purpose: The program jumps to this routine when
;		 the microcontroller has a power on reset.
;
;*******************************************************

reset:
	; set for use with external oscillator
	mov		A, (LVR_ENABLE | EXTERNAL_CLK)	
	iowr	clock_config

	; setup data memory stack pointer
	mov		A, 68h
	swap	A, dsp		

	; clear variables
	mov		A, 00h		
	mov		[ep0_in_machine], A		; clear ep0 state machine
	mov		[configuration], A
	mov		[ep1_stall], A
	mov		[idle], A
	mov		[suspend_count], A
	mov		[ep1_dmabuff0], A
	mov		[ep1_dmabuff1], A
	mov		[ep1_dmabuff2], A
	mov		[int_temp], A
	mov		[idle_timer], A
	mov		[idle_prescaler], A
	mov		[event_machine], A
	mov		[logo_index], A
	mov		[ep0_transtype], A

	mov		A, 01h
	mov		[protocol], A

		; enable global interrupts
	mov		A, (1MS_INT | USB_RESET_INT)
	iowr 	global_int

	; enable endpoint  0 interrupt
	mov 	A, EP0_INT			
	iowr 	endpoint_int

	; enable USB address for endpoint 0
	mov		A, ADDRESS_ENABLE
	iowr	usb_address

	; enable all interrupts
	ei

	; enable USB pullup resistor
	mov		A, VREG_ENABLE  
	iowr	usb_status

task_loop:

	mov		A, [event_machine]
	jacc	event_machine_jumptable
		no_event_pending:
			; if not configured then skip data transfer
			mov		A, [configuration]
			cmp		A, 01h
			jnz		no_event_task
			; if stalled then skip data transfer
			mov		A, [ep1_stall]
			cmp		A, FFh
			jz		no_event_task
			
			;read logo data
			mov		A, [logo_index]			
			index	logo_table				; get X offset
			mov		[ep1_dmabuff1], A
			inc		[logo_index]
			mov		A, [logo_index]
			index	logo_table				; get Y offset
			mov		[ep1_dmabuff2], A
			inc		[logo_index]
			mov		A, [logo_index]
			cmp		A, 6Eh					; check if at end of table
			jnz		no_table_reset
			mov		A, 00h
			mov		[logo_index], A
			no_table_reset:

			mov		A, 03h				; set endpoint 1 to send 3 bytes
			or		A, [ep1_data_toggle]
			iowr	ep1_count
			mov		A, ACK_IN			; set to ack on endpoint 1
			iowr	ep1_mode	

			mov		A, EVENT_PENDING	; clear pending events
			mov		[event_machine], A 

		event_task_done:
	
	no_event_task:


	jmp task_loop


;*******************************************************
;
;	Interrupt handler: bus_reset
;	Purpose: The program jumps to this routine when
;		 the microcontroller has a bus reset.
;
;*******************************************************

bus_reset:
	mov		A, STALL_IN_OUT			; set to STALL INs&OUTs
	iowr	ep0_mode

	mov		A, ADDRESS_ENABLE		; enable USB address 0
	iowr	usb_address
	mov		A, DISABLE				; disable endpoint1
	iowr	ep1_mode

	mov		A, 00h					; reset program stack pointer
	mov		psp,a	

	jmp		reset


;*******************************************************
;
;	Interrupt: 1ms_clear_control
;	Purpose: Every 1ms this interrupt handler clears
;		the watchdog timer.
;
;*******************************************************

1ms_timer:
	push A

	; clear watchdog timer
	iowr watchdog

	; check for no bus activity/usb suspend
  1ms_suspend_timer:
	iord	usb_status				; read bus activity bit
	and		A, BUS_ACTIVITY			; mask off activity bit
	jnz		bus_activity
			
	inc		[suspend_count]			; increment suspend counter
	mov		A, [suspend_count]
	cmp		A, 04h					; if no bus activity for 3-4ms,
	jz		usb_suspend				; then go into low power suspend
	jmp		ms_timer_done

 	usb_suspend:

		; enable wakeup timer

		mov		A, (USB_RESET_INT)
		iowr 	global_int

  		iord	control
  		or		A, SUSPEND			; set suspend bit
 		ei
 		iowr	control
 		nop

		; look for bus activity, if none go back into suspend
		iord	usb_status
		and		A, BUS_ACTIVITY
		jz		usb_suspend		

		; re-enable interrupts
		mov		A, (1MS_INT | USB_RESET_INT)
		iowr 	global_int


	bus_activity:
		mov		A, 00h				; reset suspend counter
		mov		[suspend_count], A
		iord	usb_status
		and		A, ~BUS_ACTIVITY	; clear bus activity bit
		iowr	usb_status


	ms_timer_done:
		pop A
		reti

;*******************************************************
;
;	Interrupt: endpoint0
;	Purpose: Usb control endpoint handler.  This interrupt
;			handler formulates responses to SETUP and 
;			CONTROL READ, and NO-DATA CONTROL transactions. 
;
;	Jump table entry formulation for bmRequestType and bRequest
;
;	1. Add high and low nibbles of bmRequestType.
;	2. Put result into high nibble of A.
;	3. Mask off bits [6:4].
;	4. Add bRequest to A.
;	5. Double value of A (jmp is two bytes).
;
;*******************************************************

endpoint0:
	push	X
	push	A

	iord	ep0_mode
	and		A, EP0_ACK
	jz		ep0_done

	iord	ep0_mode
	asl		A
	jc		ep0_setup_received
	asl		A
	jc		ep0_in_received
	asl		A
	jc		ep0_out_received
  ep0_done:
	pop		A
	pop		X
	reti

	ep0_setup_received:
 		mov		A, NAK_IN_OUT				; clear setup bit to enable
		iowr	ep0_mode					; writes to EP0 DMA buffer


		mov		A, [bmRequestType]			; compact bmRequestType into 5 bit field
		and		A, E3h						; clear bits 4-3-2, these unused for our purposes
		push	A							; store value
		asr		A							; move bits 7-6-5 into 4-3-2's place
		asr		A
		asr		A
		mov		[int_temp], A				; store shifted value
		pop		A							; get original value
		or		A, [int_temp]				; or the two to get the 5-bit field
		and		A, 1Fh						; clear bits 7-6-5 (asr wraps bit7)
		asl		A							; shift to index jumptable
		jacc	bmRequestType_jumptable		; jump to handle bmRequestType


		h2d_std_device:
			mov		A, [bRequest]
			asl		A
			jacc	h2d_std_device_jumptable

		h2d_std_interface:	
			mov		A, [bRequest]
			asl		A
			jacc	h2d_std_interface_jumptable

		h2d_std_endpoint:
			mov		A, [bRequest]
			asl		A
			jacc	h2d_std_endpoint_jumptable

		d2h_std_device:
			mov		A, [bRequest]
			asl		A
			jacc	d2h_std_device_jumptable

		d2h_std_interface:
			mov		A, [bRequest]
			asl		A
			jacc	d2h_std_interface_jumptable

		d2h_std_endpoint:
			mov		A, [bRequest]
			asl		A
			jacc	d2h_std_endpoint_jumptable


	;;************ DEVICE REQUESTS **************

	set_device_address:						; SET ADDRESS
		mov		A, ADDRESS_CHANGE_PENDING	; set flag to indicate we
		mov		[ep0_in_flag], A			; need to change address on
		mov		A, [wValuelo]
		mov		[pending_data], A
		jmp		initialize_no_data_control

	set_device_configuration:				; SET CONFIGURATION
		mov		A, [wValuelo]
		cmp		A, 01h
		jz		configure_device
		unconfigure_device:					; set device as unconfigured
			mov		[configuration], A
			mov		A, DISABLE				; disable endpoint 1
			iowr	ep1_mode
			mov 	A, EP0_INT				; turn off endpoint 1 interrupts
			iowr 	endpoint_int
			jmp		set_device_configuration_done
		configure_device:					; set device as configured
			mov		[configuration], A

			mov		A, [ep1_stall]			; if endpoint 1 is stalled
			and		A, FFh
			jz		ep1_nak_in_out
				mov		A, STALL_IN_OUT		; set endpoint 1 mode to stall
				iowr	ep1_mode
				jmp		ep1_set_int
			ep1_nak_in_out:
				mov		A, NAK_IN_OUT		; otherwise set it to NAK in/out
				iowr	ep1_mode
			ep1_set_int:
			mov 	A, EP0_INT | EP1_INT	; enable endpoint 1 interrupts		
			iowr 	endpoint_int
			mov		A, 00h
			mov		[ep1_data_toggle], A	; reset the data toggle
			mov		[ep1_dmabuff0], A		; reset endpoint 1 fifo values
			mov		[ep1_dmabuff1], A
			mov		[ep1_dmabuff2], A
			set_device_configuration_done:
			mov		A, NO_CHANGE_PENDING
			mov		[ep0_in_flag], A
			jmp		initialize_no_data_control


	get_device_status:						; GET STATUS
		mov		A, DEVICE_STATUS_LENGTH
		mov		[maximum_data_count], A
		mov		A, (device_status_wakeup_disabled - control_read_table)
		mov		[data_start], A
		jmp		initialize_control_read
		

	get_device_descriptor:					; GET DESCRIPTOR
		mov		A, [wValuehi]
		asl		A
		jacc	get_device_descriptor_jumptable

		send_device_descriptor:
			mov		A, 00h					; get device descriptor length
			index	device_desc_table
			mov		[maximum_data_count], A
			mov		A, (device_desc_table - control_read_table)
			mov		[data_start], A
			jmp		initialize_control_read

		send_configuration_descriptor:
			mov		A, 02h
   			index	config_desc_table:
			mov		[maximum_data_count], A
			mov		A, (config_desc_table - control_read_table)
			mov		[data_start], A
			jmp		initialize_control_read

		send_string_descriptor:
			mov		A, [wValuelo]
			asl		A
			jacc	string_jumptable:

			language_string:
				mov		A, 00h
				index	ilanguage_string
				mov		[maximum_data_count], A
				mov		A, (ilanguage_string - control_read_table)
				mov		[data_start], A
				jmp		initialize_control_read

			manufacturer_string:
				mov		A, 00h
				index	imanufacturer_string
				mov		[maximum_data_count], A
				mov		A, (imanufacturer_string - control_read_table)
				mov		[data_start], A
				jmp		initialize_control_read

			product_string:
				mov		A, 00h
				index	iproduct_string
				mov		[maximum_data_count], A
				mov		A, (iproduct_string - control_read_table)
				mov		[data_start], A
				jmp		initialize_control_read

			serial_string:
				mov		A, 00h
				index	iserialnumber_string
				mov		[maximum_data_count], A
				mov		A, (iserialnumber_string - control_read_table)
				mov		[data_start], A
				jmp		initialize_control_read

			configuration_string:
				mov		A, 00h
				index	iconfiguration_string
				mov		[maximum_data_count], A
				mov		A, (iconfiguration_string - control_read_table)
				mov		[data_start], A
				jmp		initialize_control_read

		send_interface_descriptor:
			mov		A, 00h					; get interface descriptor length
			index	interface_desc_table 
			mov		[maximum_data_count], A
			mov		A, (interface_desc_table - control_read_table)
			mov		[data_start], A
			jmp		initialize_control_read

		send_endpoint_descriptor:
			mov		A, 00h					; get endpoint descriptor length
			index	endpoint_desc_table
			mov		[maximum_data_count], A
			mov		A, (endpoint_desc_table - control_read_table)
			mov		[data_start], A
			jmp		initialize_control_read


		get_device_configuration:			; GET CONFIGURATION
			mov		A, DEVICE_CONFIG_LENGTH
			mov		[maximum_data_count], A
			mov		A, [configuration]		; test configuration status
			and		A, FFh
			jz		device_unconfigured
			device_configured:				; send configured status
				mov		A, (device_configured_table - control_read_table)
				mov		[data_start], A
				jmp		initialize_control_read
			device_unconfigured:				; send unconfigured status
				mov		A, (device_unconfigured_table - control_read_table)
				mov		[data_start], A
				jmp		initialize_control_read


	;;************ INTERFACE REQUESTS ***********

	set_interface_interface:				; SET INTERFACE
		mov		A, [wValuelo]
		cmp		A, 00h						; there are no alternate interfaces
		jz		alternate_supported			; for this device
		alternate_not_supported:			; if the host requests any other
			jmp		request_not_supported	; alternate than 0, stall.	
		alternate_supported:
			mov		A, NO_CHANGE_PENDING
			mov		[ep0_in_flag], A
			jmp		initialize_no_data_control


	get_interface_status:					; GET STATUS
		mov		A, INTERFACE_STATUS_LENGTH
		mov		[maximum_data_count], A
		mov		A, (interface_status_table - control_read_table)
		mov		[data_start], A
		jmp		initialize_control_read
		

	get_interface_interface:				; GET INTERFACE
		mov		A, INTERFACE_ALTERNATE_LENGTH
		mov		[maximum_data_count], A
		mov		A, (interface_alternate_table - control_read_table)
		mov		[data_start], A
		jmp		initialize_control_read


	set_interface_idle:						; SET IDLE
		mov		A, [wValuehi]				; test if new idle time 
		cmp		A, 00h						; disables idle timer
		jz		idle_timer_disable

		mov		A, [idle_timer]				; test if less than 4ms left
		cmp		A, 01h
		jz		set_idle_last_not_expired

		mov		A, [wValuehi]				; test if time left less than
		sub		A, [idle_timer]				; new idle value
		jnc		set_idle_new_timer_less

		jmp		set_idle_normal

		idle_timer_disable:
			mov		[idle], A				; disable idle timer
			jmp		set_idle_done

		set_idle_last_not_expired:
			mov		A, EVENT_PENDING		; send report immediately
			mov		[event_machine], A
			mov		A, 00h					; reset idle prescaler
			mov		[idle_prescaler], A
			mov		A, [wValuehi]			; set new idle value
			mov		[idle_timer], A
			mov		[idle], A
			jmp		set_idle_done

		set_idle_new_timer_less:			
			mov		A, 00h
			mov		[idle_prescaler], A		; reset idle prescaler
			mov		A, [wValuehi]
			mov		[idle_timer], A			; update idle time value
			mov		[idle], A
			jmp		set_idle_done

		set_idle_normal:
			mov		A, 00h					; reset idle prescaler
			mov		[idle_prescaler], A
			mov		A, [wValuehi]			; update idle time value
			mov		[idle_timer], A
			mov		[idle], A

		set_idle_done:
			mov		A, NO_CHANGE_PENDING	; respond with no-data control
			mov		[ep0_in_flag], A		; transaction
			jmp		initialize_no_data_control


	set_interface_protocol:					; SET PROTOCOL
		mov		A, [wValuelo]
		mov		[protocol], A				; set protocol value
		mov		A, NO_CHANGE_PENDING
		mov		[ep0_in_flag], A			; respond with no-data control
		jmp		initialize_no_data_control	; transaction


	get_interface_report:					; GET REPORT
		mov		A, DATA_TOGGLE				; set data toggle to DATA ONE
		mov		[ep0_data_toggle], A
		mov		A, NAK_IN_OUT				; clear setup bit to write to
		iowr	ep0_mode					; endpoint fifo

		mov		A, [ep1_dmabuff0]			; copy over button data
		mov		[ep0_dmabuff0], A

		mov		A, [ep1_dmabuff1]			; copy horizontal data
		mov		[ep0_dmabuff1], A

		mov		A, [ep1_dmabuff2]			; copy vertical data
		mov		[ep0_dmabuff2], A

		mov		A, CONTROL_READ_DATA		; set state machine state
		mov		[ep0_in_machine], A			
		mov		X, 03h						; set number of byte to transfer to 3
		jmp		dmabuffer_load_done			; jump to finish transfer
		
	
	get_interface_idle:						; GET IDLE
		mov		A, DATA_TOGGLE				; set data toggle to DATA ONE
		mov		[ep0_data_toggle], A
		mov		A, NAK_IN_OUT				; clear setup bit to write to
		iowr	ep0_mode					; endpoint fifo

		mov		A, [idle]					; copy over idle time
		mov		[ep0_dmabuff0], A

		mov		A, CONTROL_READ_DATA		; set state machine state
		mov		[ep0_in_machine], A			
		mov		X, 01h						; set number of byte to transfer to 3
		jmp		dmabuffer_load_done			; jump to finish transfer

	
	get_interface_protocol:					; GET PROTOCOL
		mov		A, INTERFACE_PROTOCOL_LENGTH
		mov		[maximum_data_count], A		; get offset of device descriptor table
		mov		A, [protocol]
		and		A, 01h
		jz		boot_protocol
		report_protocol:
			mov		A, (interface_report_protocol - control_read_table)
			mov		[data_start], A
			jmp		initialize_control_read	; get ready to send data
		boot_protocol:
			mov		A, (interface_boot_protocol - control_read_table)
			mov		[data_start], A
			jmp		initialize_control_read	; get ready to send data


	get_interface_hid:
		mov		A, [wValuehi]
		cmp		A, 21h
		jz		get_interface_hid_descriptor
		cmp		A, 22h
		jz		get_interface_hid_report
		jmp		request_not_supported

	get_interface_hid_descriptor:			; GET HID CLASS DESCRIPTOR
		mov		A, 00h						; get hid decriptor length
		index	hid_desc_table
		mov		[maximum_data_count], A		; get offset of device descriptor table
		mov		A, (hid_desc_table - control_read_table)
		mov		[data_start], A
		jmp		initialize_control_read		; get ready to send data


	get_interface_hid_report:				; GET HID REPORT DESCRIPTOR
		mov		A, 07h						; get hid report descriptor length
		index	hid_desc_table
		mov		[maximum_data_count], A		; get offset of device descriptor table
		mov		A, (hid_report_desc_table - control_read_table)
		mov		[data_start], A
		jmp		initialize_control_read		; get ready to send data


	;;************ ENDPOINT REQUESTS ************

	clear_endpoint_feature:					; CLEAR FEATURE
		mov		A, [wValuelo]
		cmp		A, ENDPOINT_STALL
		jnz		request_not_supported		
		mov		A, 00h						; clear endpoint 1 stall
		mov		[ep1_stall], A
		mov		A, NO_CHANGE_PENDING		; respond with no-data control
		mov		[ep0_in_flag], A
		jmp		initialize_no_data_control

	set_endpoint_feature:					; SET FEATURE
		mov		A, [wValuelo]
		cmp		A, ENDPOINT_STALL
		jnz		request_not_supported		
		mov		A, FFh						; stall endpoint 1
		mov		[ep1_stall], A
		mov		A, NO_CHANGE_PENDING		; respond with no-data control
		mov		[ep0_in_flag], A
		jmp		initialize_no_data_control

	get_endpoint_status:					; GET STATUS
		mov		A, ENDPOINT_STALL_LENGTH
		mov		[maximum_data_count], A
		mov		A, [ep1_stall]				; test if endpoint 1 stalled
		and		A, FFh
		jnz		endpoint_stalled
		endpoint_not_stalled:				; send no-stall status
			mov		A, (endpoint_nostall_table - control_read_table)
			mov		[data_start], A
			jmp		initialize_control_read
		endpoint_stalled:					; send stall status
			mov		A, (endpoint_stall_table - control_read_table)
			mov		[data_start], A
			jmp		initialize_control_read
		
;;***************** CONTROL READ TRANSACTION **************

	initialize_control_read:
		mov		A, TRANS_CONTROL_READ		; set transaction type to control read
		mov		[ep0_transtype], A

		mov		A, DATA_TOGGLE				; set data toggle to DATA ONE
		mov		[ep0_data_toggle], A

		; if wLengthhi == 0
		mov		A, [wLengthhi]				; find lesser of requested and maximum
		cmp		A, 00h
		jnz		initialize_control_read_done
		; and wLengthlo < maximum_data_count
		mov		A, [wLengthlo]				; find lesser of requested and maximum
		cmp		A, [maximum_data_count]		; response lengths
		jnc		initialize_control_read_done
		; then maximum_data_count >= wLengthlo
		mov		A, [wLengthlo]
		mov		[maximum_data_count], A
		initialize_control_read_done:
			jmp		control_read_data_stage	; send first packet


;;***************** CONTROL WRITE TRANSACTION *************

	initialize_control_write:
		mov		A, TRANS_CONTROL_WRITE		; set transaction type to control write
		mov		[ep0_transtype], A

		mov		A, DATA_TOGGLE				; set accepted data toggle
		mov		[ep0_data_toggle], A
		mov		A, ACK_OUT_NAK_IN			; set mode
		iowr	ep0_mode
		pop		A
		pop		X
		reti


;;***************** NO DATA CONTROL TRANSACTION ***********

	initialize_no_data_control:
		mov		A, TRANS_NO_DATA_CONTROL	; set transaction type to no data control
		mov		[ep0_transtype], A

		mov		A, STATUS_IN_ONLY			; set SIE for STATUS IN mode
		iowr	ep0_mode
		pop		A
		pop		X
		reti


;;***************** UNSUPPORTED TRANSACTION ***************

	request_not_supported:
		iord	ep0_mode
		mov	A, STALL_IN_OUT					; send a stall to indicate that the request
		iowr	ep0_mode					; is not supported
		pop	A
		pop	X
		reti


;**********************************************************

	;**********************************
	; IN - CONTROL READ DATA STAGE
	;	 - CONTROL WRITE STATUS STAGE
	;	 - NO DATA CONTROL STATUS STAGE

	ep0_in_received:
	mov		A, [ep0_transtype]
	jacc	ep0_in_jumptable


	;**********************************

	control_read_data_stage:
		mov		X, 00h

		mov		A, [maximum_data_count]
		cmp		A, 00h						; has all been sent
		jz		dmabuffer_load_done			

		dmabuffer_load:
			mov		A, X					; check if 8 byte ep0 dma
			cmp		A, 08h					; buffer is full
			jz		dmabuffer_load_done

			mov		A, [data_start]			; read data from desc. table
			index	control_read_table
			mov		[X + ep0_dmabuff0], A

			inc		X						; increment buffer offset
			inc		[data_start]			; increment descriptor table pointer
			dec		[maximum_data_count]	; decrement number of bytes requested
			jz		dmabuffer_load_done
			jmp		dmabuffer_load			; loop to load more data
			dmabuffer_load_done:
	
		iord	ep0_count					; unlock counter register
		mov		A, X						; find number of bytes loaded
		or		A, [ep0_data_toggle]		; or data toggle
		iowr	ep0_count					; write ep0 count register

		mov		A, ACK_IN_STATUS_OUT		; set endpoint mode to ack next IN
		iowr	ep0_mode					; or STATUS OUT
			
		mov		A, DATA_TOGGLE				; toggle data toggle
		xor		[ep0_data_toggle], A

		pop		A
		pop		X
		reti


	;**********************************

	control_write_status_stage:
		mov		A, STATUS_OUT_ONLY
		iowr	ep0_mode

		mov		A, TRANS_NONE
		mov		[ep0_transtype], A

		pop		A
		pop		X
		reti


	;**********************************

	no_data_control_status_stage:
		mov		A, [ep0_in_flag]		; end of no-data control transaction 
		cmp		A, ADDRESS_CHANGE_PENDING
		jnz		no_data_status_done

		change_address:
			mov		A, [pending_data]	; change the device address if this
			or		A, ADDRESS_ENABLE	; data is pending
			iowr	usb_address

		no_data_status_done:			; otherwise set to stall in/out until
			mov		A, STALL_IN_OUT		; a new setup
			iowr	ep0_mode

			mov		A, TRANS_NONE
			mov		[ep0_transtype], A

			pop		A
			pop		X
			reti


;**********************************************************

	;**********************************
	; OUT - CONTROL READ STATUS STAGE
	;	  - CONTROL WRITE DATA STAGE
	;	  - ERROR DURING NO DATA CONTROL TRANSACTION

	ep0_out_received:
	mov		A, [ep0_transtype]
	jacc	ep0_out_jumptable

	
	;**********************************

	control_read_status_stage:
		mov		A, STATUS_IN_ONLY
		iowr	ep0_mode

		mov		A, TRANS_NONE
		mov		[ep0_transtype], A

		pop		A
		pop		X
		reti	


	;**********************************

	control_write_data_stage:
		mov		A, ep0_count					; check that data is valid
		and		A, DATA_VALID
		jz		control_write_data_stage_done

		mov		A, ep0_count					; check for correct data toggle
		and		A, DATA_TOGGLE
		xor		A, [ep0_data_toggle]
		jnz		control_write_data_stage_done

		; get data and transfer it to a buffer here


		mov		A, DATA_TOGGLE
		xor		[ep0_data_toggle], A

		control_write_data_stage_done:
		pop		A
		pop		X
		reti

		
	;**********************************

	no_data_control_error:	
		mov		A, STALL_IN_OUT
		iowr	ep0_mode

		mov		A, TRANS_NONE
		mov		[ep0_transtype], A

		pop		A
		pop		X
		reti

	
;*******************************************************
;
;	Interrupt handler: endpoint1
;	Purpose: This interrupt routine handles the specially
;		 reserved data endpoint 1 (for a mouse).  This
;		 interrupt happens every time a host sends an
;		 IN on endpoint 1.  The data to send (NAK or 3
;		 byte packet) is already loaded, so this routine
;		 just prepares the dma buffers for the next packet
;
;*******************************************************

endpoint1:
	push	A

	; change data toggle
	mov		A, 80h
	xor		[ep1_data_toggle], A

	mov		A, NO_EVENT_PENDING				; clear pending events
	mov		[event_machine], A 

	; clear endpoint variables
	mov		A, 00h							; clear horz&vert cursor change values
	mov		[ep1_dmabuff1], A
	mov		[ep1_dmabuff2], A

	; set response
	mov		A, [ep1_stall]					; if endpoint is set to stall, then set
	cmp		A, FFh							; mode to stall
	jnz		endpoint1_done
		mov		A, STALL_IN_OUT
		iowr	ep1_mode

	endpoint1_done:
		pop		A
		reti

	
;**********************************************************
;	JUMP TABLES
;**********************************************************

XPAGEOFF
ORG		600h

		; bmRequestTypes commented out are not used for this device,
		; but may be used for your device.  They are kept here as
		; an example of how to use this jumptable.

		bmRequestType_jumptable:
			jmp		h2d_std_device			; 00
			jmp		h2d_std_interface		; 01	
			jmp		h2d_std_endpoint		; 02	
			jmp		request_not_supported	; h2d_std_other			03	
			jmp		request_not_supported	; h2d_class_device		04	
			jmp		request_not_supported	; h2d_class_interface	05	
			jmp		request_not_supported	; h2d_class_endpoint	06	
			jmp		request_not_supported	; h2d_class_other		07	
			jmp		request_not_supported	; h2d_vendor_device		08	
			jmp		request_not_supported	; h2d_vendor_interface	09	
			jmp		request_not_supported	; h2d_vendor_endpoint	0A	
			jmp		request_not_supported	; h2d_vendor_other		0B	
			jmp		request_not_supported	; 0C	
			jmp		request_not_supported	; 0D	
			jmp		request_not_supported	; 0E	
			jmp		request_not_supported	; 0F	
			jmp		d2h_std_device			; 10	
			jmp		d2h_std_interface		; 11	
			jmp		d2h_std_endpoint		; 12	
			jmp		request_not_supported	; d2h_std_other			13	
			jmp		request_not_supported	; d2h_class_device		14	
			jmp		request_not_supported	; d2h_class_interface	15	
			jmp		request_not_supported	; d2h_class_endpoint	16	
			jmp		request_not_supported	; d2h_class_other		17	
			jmp		request_not_supported	; d2h_vendor_device		18	
			jmp		request_not_supported	; d2h_vendor_interface	19	
			jmp		request_not_supported	; d2h_vendor_endpoint	1A	
			jmp		request_not_supported	; d2h_vendor_other		1B	
			jmp		request_not_supported	; 1C	
			jmp		request_not_supported	; 1D	
			jmp		request_not_supported	; 1E	
			jmp		request_not_supported	; 1F	

		h2d_std_device_jumptable:
			jmp		request_not_supported	; 00
			jmp		request_not_supported	; 01
			jmp		request_not_supported	; 02
			jmp		request_not_supported		; 03
			jmp		request_not_supported	; 04
			jmp		set_device_address		; 05
			jmp		request_not_supported	; 06
			jmp		request_not_supported	; set_device_descriptor		07
			jmp		request_not_supported	; 08
			jmp		set_device_configuration; 09

		h2d_std_interface_jumptable:
			jmp		request_not_supported	; 00
			jmp		request_not_supported	; clear_interface_feature 01
			jmp		request_not_supported	; 02
			jmp		request_not_supported	; set_interface_feature	 03
			jmp		request_not_supported	; 04
			jmp		request_not_supported	; 05
			jmp		request_not_supported	; 06
			jmp		request_not_supported	; 07
			jmp		request_not_supported	; 08
			jmp		request_not_supported	; 09
			jmp		request_not_supported	; 0A
			jmp		set_interface_interface	; 0B

		h2d_std_endpoint_jumptable:
			jmp		request_not_supported	; 00
			jmp		clear_endpoint_feature	; 01
			jmp		request_not_supported	; 02
			jmp		set_endpoint_feature	; 03
									
		d2h_std_device_jumptable:
			jmp		get_device_status		; 00
			jmp		request_not_supported	; 01
			jmp		request_not_supported	; 02
			jmp		request_not_supported	; 03
			jmp		request_not_supported	; 04
			jmp		request_not_supported	; 05
			jmp		get_device_descriptor	; 06
			jmp		request_not_supported	; 07
			jmp		get_device_configuration; 08

		d2h_std_interface_jumptable:
			jmp		get_interface_status	; 00
			jmp		request_not_supported	; 01
			jmp		request_not_supported	; 02
			jmp		request_not_supported	; 03
			jmp		request_not_supported	; 04
			jmp		request_not_supported	; 05
			jmp		get_interface_hid		; 06
			jmp		request_not_supported	; 07
			jmp		request_not_supported	; 08
			jmp		request_not_supported	; 09
			jmp		get_interface_interface	; 0A
	
		d2h_std_endpoint_jumptable:
			jmp		get_endpoint_status		; 00
			jmp		request_not_supported	; 01
			jmp		request_not_supported	; 02
			jmp		request_not_supported	; 03
			jmp		request_not_supported	; 04
			jmp		request_not_supported	; 05
			jmp		request_not_supported	; 06
			jmp		request_not_supported	; 07
			jmp		request_not_supported	; 08
			jmp		request_not_supported	; 09
			jmp		request_not_supported	; 0A
			jmp		request_not_supported	; 0B
			jmp		request_not_supported	; synch frame 0C
	
		ep0_in_jumptable:
			jmp		request_not_supported
			jmp		control_read_data_stage
			jmp		control_write_status_stage
			jmp		no_data_control_status_stage		

		ep0_out_jumptable:
			jmp		request_not_supported
			jmp		control_read_status_stage
			jmp		control_write_data_stage
			jmp		no_data_control_error


		get_device_descriptor_jumptable:
			jmp		request_not_supported
			jmp		send_device_descriptor
			jmp		send_configuration_descriptor
			jmp		send_string_descriptor
			jmp		send_interface_descriptor
			jmp		send_endpoint_descriptor

		string_jumptable:
			jmp		language_string
			jmp		manufacturer_string
			jmp		product_string
			jmp		serial_string
			jmp		configuration_string


;*********************************************************
;                   rom lookup tables
;*********************************************************

XPAGEOFF
ORG		700h

control_read_table:
   device_desc_table:
	db	12h			; bLength (18 bytes)
	db	01h			; bDescriptorType (device descriptor)
	db	10h, 01h	; bcdUSB (ver 1.1)
	db	00h			; bDeviceClass (each interface specifies class info)
	db	00h			; bDeviceSubClass (not specified)
	db	00h			; bDeviceProtocol (not specified)
	db	08h			; bMaxPacketSize0 (8 bytes)
	db	B4h, 04h	; idVendor (Cypress vendor ID)
	db	70h, 63h	; idProduct (Cypress USB mouse product ID)
	db	00h, 01h	; bcdDevice (1.00) 
	db	01h			; iManufacturer (Cypress Semiconductor)
	db	02h			; iProduct (Cypress Ultra Mouse)
	db	03h			; iSerialNumber (000-000-0001)
	db	01h			; bNumConfigurations (1)

   config_desc_table:
	db	09h			; bLength (9 bytes)
	db	02h			; bDescriptorType (CONFIGURATION)
	db	22h, 00h	; wTotalLength (34 bytes)
	db	01h			; bNumInterfaces (1)
	db	01h			; bConfigurationValue (1)
	db	04h			; iConfiguration (USB HID Compliant Mouse)
	db	00h			; bmAttributes (bus powered, remote wakeup)
	db	0Dh			; MaxPower (13mA)
   interface_desc_table:
	db	09h			; bLength (9 bytes)
	db	04h			; bDescriptorType (INTERFACE)
	db	00h			; bInterfaceNumber (0)
	db	00h			; bAlternateSetting (0)
	db	01h			; bNumEndpoints (1)
	db	03h			; bInterfaceClass (3..defined by USB spec)
	db	01h			; bInterfaceSubClass (1..defined by USB spec)
	db	02h			; bInterfaceProtocol (2..defined by USB spec)
	db	00h			; iInterface (not supported)
   hid_desc_table:
	db	09h			; bLength (9 bytes)
	db	21h			; bDescriptorType (HID)
	db	00h, 01h	; bcdHID (1.00)	
	db	00h			; bCountryCode (US)
	db	01h			; bNumDescriptors (1)
	db	22h			; bDescriptorType (HID)
	db	32h, 00h	; wDescriptorLength (50 bytes) 
   endpoint_desc_table:
	db	07h			; bLength (7 bytes)
	db	05h			; bDescriptorType (ENDPOINT)
	db	81h			; bEndpointAddress (IN endpoint, endpoint 1)
	db	03h			; bmAttributes (interrupt)
	db	03h, 00h	; wMaxPacketSize (3 bytes)
	db	0Ah			; bInterval (10ms)

   hid_report_desc_table:
	db	05h, 01h	; usage page (generic desktop)
	db	09h, 02h	; usage (mouse)
	db	A1h, 01h	; collection (application)
	db	09h, 01h	; usage (pointer)
	db	A1h, 00h	; collection (linked)
	db	05h, 09h	; usage page (buttons)
	db	19h, 01h	; usage minimum (1)
	db	29h, 03h	; usage maximum (3)
	db	15h, 00h	; logical minimum (0)
	db	25h, 01h	; logical maximum (1)
	db	95h, 03h	; report count (3 bytes)
	db	75h, 01h	; report size (1)
	db	81h, 03h	; input (3 button bits)
	db	95h, 01h	; report count (1)
	db	75h, 05h	; report size (5)
	db	81h, 01h	; input (constant 5 bit padding)
	db	05h, 01h	; usage page (generic desktop)
	db	09h, 30h	; usage (X)
	db	09h, 31h	; usage (Y)
	db	15h, 81h	; logical minimum (-127)
	db	25h, 7Fh	; logical maximum (127)
	db	75h, 08h	; report size (8)
	db	95h, 02h	; report count (2)
	db	81h, 06h	; input (2 position bytes X & Y)
	db	C0h, C0h	; end collection, end collection

   device_status_wakeup_disabled:
    db  00h, 00h    ; remote wakeup disabled, bus powered

   device_configured_table:
	db	01h			; device in configured state
   device_unconfigured_table:
	db	00h			; device in unconfigured state

   endpoint_nostall_table:
	db	00h, 00h	; endpoint not stalled
   endpoint_stall_table:
	db	01h, 00h	; endpoint stalled

   interface_status_table:
	db	00h, 00h	; default response

   interface_alternate_table:
	db	00h			; only valid alternate setting

   interface_boot_protocol:
	db	00h
   interface_report_protocol:
	db	01h

   ilanguage_string:
    db 04h          				; Length
    db 03h          				; Type (3=string)
    db 09h          				; Language:  English
    db 04h          				; Sub-language: US

   imanufacturer_string:
    db 1Ch          				; Length
    db 03h          				; Type (3=string)
    dsu "Cypress Semi."

   iproduct_string:
    db 34h          				; Length
    db 03h          				; Type (3=string)
    dsu "CY3654 Development System"

   iserialnumber_string:			; serial number
	db 10h                        	; Length 
    db 03h							; Type (3=string)
    dsu "0000001"

   iconfiguration_string:
    db 28h          				; Length
    db 03h          				; Type (3=string)
    dsu "HID-Compliant Mouse"


;**********************************************************
;	APPLICATION SPECIFIC TABLES
;**********************************************************

ORG		800h


		event_machine_jumptable:
			jmp		no_event_pending
			jmp		no_event_task


	logo_table:
		db 00h, 05h	;1
		db 00h, 05h	;2
		db 00h, 05h	;3
		db 00h, 05h	;4
		db 00h, 05h	;5
		db 05h, 05h	;6
		db 05h, 00h	;7
		db 05h, 00h	;8
		db 05h, FBh	;9
		db 00h, FBh	;10
		db 00h, FBh	;11
		db 00h, FBh	;12
		db 00h, FBh	;13
		db 00h, FBh	;14
		db 23h, 05h	;15
		db FBh, FBh	;16
		db FBh, 00h	;17
		db FBh, 00h	;18
		db FBh, 05h	;19
		db 00h, 05h	;20
		db 05h, 05h	;21
		db 05h, 00h	;22
		db 05h, 00h	;23
		db 05h, 05h	;24
		db 00h, 05h	;25
		db FBh, 05h	;26
		db FBh, 00h	;27
		db FBh, 00h	;28
		db FBh, FBh	;29
		db 05h, 05h	;30
		db 1Eh, 00h	;31
		db 05h, 00h	;32
		db 05h, 00h	;33
		db 05h, 00h	;34
		db 05h, FBh	;35
		db 00h, FBh	;36
		db FBh, FBh	;37
		db FBh, 00h	;38
		db FBh, 00h	;39
		db FBh, 00h	;40
		db 0Fh, 00h	;41
		db 05h, FBh	;42
		db 00h, FBh	;43
		db FBh, FBh	;44
		db FBh, 00h	;45
		db FBh, 00h	;46
		db FBh, 00h	;47
		db 00h, 05h	;48
		db 00h, 05h	;49
		db 00h, 05h	;50
		db 00h, 05h	;51
		db 00h, 05h	;52
		db 00h, 05h	;53
		db 00h, E2h	;54
		db BAh, 00h	;55

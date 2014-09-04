;******************************************************
;
;	file: 		Low Cost Mouse firmware
;	Date: 		10/20/2000
;	Description:This code provides the functionality  
;				for a USB HID compliant mouse.
;	Target:		Cypress CY7C63231
;
; Overview
;  		There are four main tasks: 
;			* USB 
;			* buttons 
;			* optics 
;			* suspend/resume 
;
;   	The system is started in the reset() routine at reset. 
;		This routine initializes the USB variables, the IO ports, 
;		the mouse logic, and the data space. All USB 
;		communication occurs on an interrupt basis.
; USB
;  		Endpoint 0 is used to support Control Transfers and 
;		vendor specific requests.  During enumeration setup
;		commands are sent to endpoint1 to initialize the
;		USB device and to extract configuration information
;		from the device
;
;		Endpoint 1 is used to transfer interrupt data back to
;		the host.  In this case we transfer data from the 
;		button and optics back to the host. 
; Buttons
;		The buttons are read and debounced every millisecond in
;		the main task loop.
; Optics
;		The optics are continuously polled in the main loop.  The
;		quadrature state of the optics tells us which direction
;		the mouse is moving in.  This data is sent back to the
;		host as an offset from the last time the mouse was polled
;		for data by the host.
; Suspend/Resume
;		Every millisecond, the USB is polled for activity.  If no
;		activity occurs for three milliseconds, then it is assumed
;		that the USB is in suspend.  Because this device supports
;		remote wakeup, pressing the buttons or moving the mouse
;		causes the firmware to send resume signalling back to the
;		host to wakeup and resume operation.
;
; Endpoint1 packet definition
;
; Byte  Usage
;  0	Button Data 7-3 Not used, 2=middle, 1=right, 0=left
;  1	horizontal displacement measured via the optics
;  2	vertical displacement measured via the optics
;  3	Wheel displacement 0x01 for forward, 0xFF for backward
;
;
; Port Usage
;
;			 -------------------
;  		X0	| P0[0]		P0[4]	|  Z1	
;  		X1	| P0[1]		P0[5]	|  Z0	
;  		Y0	| P0[2]		P0[6]	|  OPTIC CONTROL	
;  		Y1	| P0[3] 	P0[7]	|  LEFT	
;  	 RIGHT	| P1[0]		P1[1]	|  MIDDLE	
;			| P1[2]		P1[3]	|	
;	GND		| VSS		D+/SCLK	|  D+
;	GND		| VPP		D-/SDATA|  D-	
;	PULLUP	| VREG		VCC		|	+5
;			| XTALIN	XTALOUT	|
;			 -------------------
;
; Revisions:
;			10/20/2000 - Creation 
;
;**********************************************************
;
;		Copyright 2000 Cypress Semiconductor
;	This code is provided by Cypress as a reference.  Cypress 
;	makes no claims or warranties to this firmware's 
;	suitability for any application. 
;
;********************************************************** 

	CPU	63743

	XPAGEON

	INCLUDE	"637xx.inc"
	INCLUDE "USB.inc"


;**************************************
; EP0 IN TRANSACTION STATE MACHINE
EP0_IN_IDLE:				equ	00h
CONTROL_READ_DATA:			equ	02h
NO_DATA_STATUS:				equ	04h
EP0_IN_STALL:				equ	06h

;**************************************
; EP0 NO-DATA CONTROL FLAGS
ADDRESS_CHANGE_PENDING:		equ	00h
NO_CHANGE_PENDING:			equ	02h

;**************************************
; RESPONSE SIZES
DEVICE_STATUS_LENGTH:		equ	2
DEVICE_CONFIG_LENGTH:		equ	1
ENDPOINT_STALL_LENGTH:		equ 2
INTERFACE_STATUS_LENGTH:	equ 2
INTERFACE_ALTERNATE_LENGTH:	equ	1
INTERFACE_PROTOCOL_LENGTH:	equ	1

;**************************************
; INTERFACE CONSTANTS

LEFT_BUTTON_PORT:			equ	port0
LEFT_BUTTON:				equ	80h
RIGHT_BUTTON_PORT:			equ	port1
RIGHT_BUTTON:				equ	01h
MIDDLE_BUTTON_PORT:			equ	port1
MIDDLE_BUTTON:				equ	02h

HID_LEFT_MOUSE_BUTTON:		equ	01h
HID_RIGHT_MOUSE_BUTTON:		equ	02h
HID_MIDDLE_MOUSE_BUTTON:	equ	04h

X_OPTICS_PORT:				equ	port0
X0:							equ	01h
X1:							equ	02h

Y_OPTICS_PORT:				equ	port0
Y0:							equ	04h
Y1:							equ	08h

Z_OPTICS_PORT:				equ port0
Z0:							equ	20h
Z1:							equ	10h

OPTIC_CONTROL_PORT:			equ	port0
OPTIC_CONTROL:				equ	40h

; button debounce time
BUTTON_DEBOUNCE:			equ 15

;**************************************
; BUTTON STATE MACHINE
NO_BUTTON_DATA_PENDING:		equ	00h
BUTTON_DATA_PENDING:		equ	02h

;**************************************
; OPTICS STATE MACHINE
NO_OPTIC_DATA_PENDING:		equ	00h
OPTIC_DATA_PENDING:			equ	02h

;**************************************
; EVENT STATE MACHINE
NO_EVENT_PENDING:			equ	00h
EVENT_PENDING:				equ	02h

;**************************************
; TRANSACTION TYPES
TRANS_NONE:					equ	00h
TRANS_CONTROL_READ:			equ	02h
TRANS_CONTROL_WRITE:		equ	04h
TRANS_NO_DATA_CONTROL:		equ	06h


;**************************************
; DATA MEMORY VARIABLES
suspend_count:				equ	20h			; usb suspend counter
ep1_data_toggle:			equ	21h			; endpoint 1 data toggle
ep0_data_toggle: 			equ	22h			; endpoint 0 data toggle
data_start:					equ	23h			; ROM table address, start of data
data_count:					equ	24h			; data count to return to host
maximum_data_count:			equ	25h			; maximum size of data to return to host
ep0_in_machine:				equ	26h			; endpoint 0 IN state machine
ep0_in_flag:				equ	27h			; endpoint 0 flag for no-data control
configuration:				equ	28h			; configured/not configured state
remote_wakeup:				equ	29h			; remote wakeup on/off
ep1_stall:					equ	2Ah			; endpoint 1 stall on/off
idle:						equ	2Bh			; HID idle timer
protocol:					equ	2Ch			; mouse protocol boot/report
debounce_count:				equ	2Dh			; debounce counters for buttons
optic_status:				equ	2Eh			; current optic status
current_button_state:		equ	2Fh			; current button status 
x_state:					equ	30h			; current optics x state
y_state:					equ	31h			; current optics y state
button_machine:				equ	32h			; buttons/optics state machine
temp:						equ	33h			; temporary register
event_machine:				equ	34h			; state machine for sending data back to host
pending_data:				equ	35h			; data pending during no-data control
last_button_state:			equ	36h			; last read value of buttons
x_current_state:			equ	37h			; y-axis current state
y_current_state:			equ	38h			; x-axis current state
z_current_state:			equ	39h			; z-axis current state
x_last_state:				equ	3Ah			; last read y-axis optics
y_last_state:				equ	3Bh			; last read x-axis optics
z_last_state:				equ	3Ch			; last read z-axis optics
int_temp:					equ	3Dh			; interrupt routine temp variable
idle_timer:					equ	3Eh			; HID idle timer
idle_prescaler:				equ	3Fh			; HID idle prescale (4ms)
ep0_transtype:				equ	40h			; Endpoint 0 transaction type
wakeup_timer:				equ	41h			; wakeup timer minimum count

;**********************************************************
; Interrupt vector table

ORG 00h			

jmp	Main									; Reset vector		

jmp	Bus_reset								; USB reset / PS2 interrupt

jmp	Error									; 128us interrupt

jmp	1ms_timer								; 1.024ms interrupt

jmp	Endpoint0								; Endpoint 0 interrupt

jmp	Endpoint1								; Endpoint 1 interrupt

jmp	Error									; Reserved

jmp	Error									; Reserved

jmp	Error									; Reserved

jmp	Error									; Reserved

jmp	Error									; GPIO interrupt vector

jmp	Wakeup									; Wake-up interrupt vector 


;**********************************************************
; Program listing

ORG  1Ah
Error: halt

;**********************************************************
;
;	Interrupt handler: Main
;	Purpose: The program jumps to this routine when
;		 the microcontroller has a power on reset.
;
;**********************************************************

Main:

	;**********************************
	; set wakeup timer interval and disable XTALOUT 
	mov		A, WAKEUP_ADJUST2 | WAKEUP_ADJUST0 | PRECISION_CLK | INTERNAL_CLK 
	iowr	clock_config

	;**********************************
	; setup data memory stack pointer
	mov		A, 20h
	swap	A, dsp		

	;**********************************
	; clear variables
	mov		A, 00h		
	mov		[ep0_in_machine], A
	mov		[configuration], A
	mov		[ep1_stall], A
	mov		[idle], A
	mov		[suspend_count], A
	mov		[debounce_count], A
	mov		[x_state], A
	mov		[y_state], A
	mov		[ep1_dmabuff0], A
	mov		[ep1_dmabuff1], A
	mov		[ep1_dmabuff2], A
	mov		[ep1_dmabuff3], A
	mov		[button_machine], A
	mov		[x_last_state], A
	mov		[y_last_state], A
	mov		[z_last_state], A
	mov		[int_temp], A
	mov		[idle_timer], A
	mov		[idle_prescaler], A
	mov		[event_machine], A
	mov		[ep0_transtype], A
	mov		[current_button_state], A
	mov		[last_button_state], A
	mov		[wakeup_timer], A

	mov		A, HID_REPORT
	mov		[protocol], A

	mov		A, SET
	mov		[remote_wakeup], A

	
	;**********************************
	; set port I/O configuration
	; *** NOTE - this is configured for the particular
	; hardware you are dealing with.  You will need to change
	; this section for the particular hardware you are working
	; on

	mov		A, LEFT_BUTTON
	iowr	port0

	mov		A, RIGHT_BUTTON | MIDDLE_BUTTON
	iowr	port1

	mov		A, OPTIC_CONTROL							; set button pins in resistive mode 
	iowr	port0_mode0
	mov		A, LEFT_BUTTON | OPTIC_CONTROL 
	iowr	port0_mode1

	mov		A, 00h									; remember that we have to drive
	iowr	port1_mode0								; unused pins to meet suspend current
	mov		A, (RIGHT_BUTTON | MIDDLE_BUTTON | FCh )
	iowr	port1_mode1


	;**********************************
	; enable USB address for endpoint 0
	mov		A, ADDRESS_ENABLE
	iowr	usb_address

	;**********************************
	; enable global interrupts
	mov		A, (1MS_INT | USB_RESET_INT)
	iowr 	global_int

	mov 	A, EP0_INT			
	iowr 	endpoint_int

	ei

	;**********************************
	; enable USB pullup resistor
	mov		A, VREG_ENABLE  
	iowr	usb_status


task_loop:

	;**********************************
	; main loop watchdog clear
	iowr watchdog


; this routine allows the user to map the button pins whereever
; they want, as long as all the buttons remain on the same port.
; in order to change the button ports you must change the mask
; in the pin mask constants above and change the definition of the 
; "button_port."  You must also change the way the port mode
; is initialized in the reset routine.
	mov		A, [button_machine]				; read buttons every millisecond
	jacc	button_machine_jumptable

	button_task:
	mov		A, [current_button_state]		; read button states
 	cmp		A, [last_button_state]
	jz		button_state_same:

	button_state_different:					; if the button state has changed, then
		mov		[last_button_state], A		; reset the debounce timer and set 
		mov		A, 00h						; last button value to the one just read
		mov		[debounce_count], A
		jmp		button_task_done
	
	button_state_same:		
		mov		A, BUTTON_DEBOUNCE - 1		; if at debounce count-1 then send
		cmp		A, [debounce_count]			; new value to host 
		jz		set_button_event

		increment_debounce_counter:			; otherwise increment debounce count
			mov		A, [debounce_count]		; if it's not already at the 
			cmp		A, BUTTON_DEBOUNCE		; BUTTON_DEBOUNCE value
			jz		button_task_done
			inc		[debounce_count]
			jmp		button_task_done

		set_button_event:					; set event pending to signal packet
			inc		[debounce_count]		; needs to be sent to host
			mov		A, EVENT_PENDING
			mov		[event_machine], A

			mov		A, [current_button_state]
			mov		[ep1_dmabuff0], A

			button_task_done:
			mov		A, NO_BUTTON_DATA_PENDING
			mov		[button_machine], A

		no_button_task:


; this routine allows the user to map the optics pins whereever
; they want, as long as all the optics sets remain on the same port.
; in order to change the optic ports you must change the mask
; in the pin mask constants above.  You must also change the way 
;the port mode is initialized in the reset routine.

	optic_task:
		mov		A, 00h						; reset optic values
		mov		[x_current_state], A
		mov		[y_current_state], A
		mov		[z_current_state], A	

		read_x_optics:
			iord	X_OPTICS_PORT
			mov		X, A
			read_x0:
				and		A, X0
				jz		read_x1
				mov		A, 01h
				or		[x_current_state], A
			read_x1:
				mov		A, X
				and		A, X1
				jz		read_y_optics
				mov		A, 02h
				or		[x_current_state], A

		read_y_optics:
			iord	Y_OPTICS_PORT
			mov		X, A
			read_y0:
				and		A, Y0
				jz		read_y1
				mov		A, 01h
				or		[y_current_state], A
			read_y1:
				mov		A, X
				and		A, Y1
				jz		read_z_optics
				mov		A, 02h
				or		[y_current_state], A

		read_z_optics:
			iord	Z_OPTICS_PORT
			mov		X, A
			read_z0:
				and		A, Z0
				jz		read_z1
				mov		A, 01h
				or		[z_current_state], A
			read_z1:
				mov		A, X
				and		A, Z1
				jz		analyze_x_optics
				mov		A, 02h
				or		[z_current_state], A

		analyze_x_optics:
			mov		A, [x_last_state]
			asl		A
			asl		A
			or		A, [x_current_state]
			asl		A
			jacc	x_jumptable				; jump to transition state

			x_increment:
				inc		[ep1_dmabuff1]		; increment mouse cursor change	
				mov		A, EVENT_PENDING	; set event pending to signal data to
				mov		[event_machine], A	; send to the host
				jmp		analyze_y_optics					
			x_decrement:
				dec		[ep1_dmabuff1]		; decrement mouse cursor change
				mov		A, EVENT_PENDING	; set event pending to signal data to
				mov		[event_machine], A	; send to the host

 		analyze_y_optics:
			mov		A, [y_last_state]
			asl		A
			asl		A
			or		A, [y_current_state]
			asl		A
			jacc	y_jumptable				; jump to transition state

			y_increment:
				inc		[ep1_dmabuff2]		; increment mouse cursor change	
				mov		A, EVENT_PENDING	; set event pending to signal data to
				mov		[event_machine], A	; send to the host
				jmp		analyze_z_optics					
			y_decrement:
				dec		[ep1_dmabuff2]		; decrement mouse cursor change
				mov		A, EVENT_PENDING	; set event pending to signal data to
				mov		[event_machine], A	; send to the host

		analyze_z_optics:
			mov		A, [z_last_state]
			asl		A
			asl		A
			or		A, [z_current_state]
			asl		A
			jacc	z_jumptable				; jump to transition state

			z_forward:
				mov		A, 01h
				mov		[ep1_dmabuff3], A	; increment mouse wheel change	
				mov		A, EVENT_PENDING	; set event pending to signal data to
				mov		[event_machine], A	; send to the host
				jmp		optic_task_done					
			z_backward:
				mov		A, FFh
				mov		[ep1_dmabuff3], A	; decrement mouse wheel change
				mov		A, EVENT_PENDING	; set event pending to signal data to
				mov		[event_machine], A	; send to the host
	
	optic_task_done:
		mov		A, [x_current_state]
		mov		[x_last_state], A
 		mov		A, [y_current_state]
		mov		[y_last_state], A
		mov		A, [z_current_state]
		mov		[z_last_state], A
	
; this task sends data out endpoint 1 if the endpoint is configured
; and not set to stall

	mov		A, [event_machine]
	jacc	event_machine_jumptable
		event_pending:
			; if not configured then skip data transfer
			mov		A, [configuration]
			cmp		A, 01h
			jnz		event_task_done
			; if stalled then skip data transfer
			mov		A, [ep1_stall]
			cmp		A, FFh
			jz		event_task_done
			
			; We have to determine which protocol is currently enabled
			; and send the format that is supported by that protocol
			mov		A, [protocol]
			cmp		A, HID_REPORT
			jnz		boot_protocol_report

		hid_protocol_report:
			mov		A, 04h					; set endpoint 1 to send 3 bytes
			or		A, [ep1_data_toggle]
			iowr	ep1_count
			mov		A, ACK_IN				; set to ack on endpoint 1
			iowr	ep1_mode	
			jmp		event_task_done

		boot_protocol_report:
			mov		A, 03h					; set endpoint 1 to send 3 bytes
			or		A, [ep1_data_toggle]
			iowr	ep1_count
			mov		A, ACK_IN				; set to ack on endpoint 1
			iowr	ep1_mode	


		event_task_done:
			mov		A, NO_EVENT_PENDING		; clear pending events
			mov		[event_machine], A 
		no_event_task:


	jmp task_loop


;*******************************************************
;
;	Interrupt handler: Bus_reset
;	Purpose: The program jumps to this routine when
;		 the host causes a USB reset.
;
;*******************************************************

Bus_reset:

	mov		A, STALL_IN_OUT					; set to STALL INs&OUTs
	iowr	ep0_mode

	mov		A, ADDRESS_ENABLE				; enable USB address 0
	iowr	usb_address
	mov		A, DISABLE						; disable endpoint1
	iowr	ep1_mode

	mov		A, 00h							; reset program stack pointer
	mov		psp,a	

	jmp		Main


;*******************************************************
;
;	Interrupt: 1ms_clear_control
;	Purpose: This interrupt handler sets a flag to indicate
;		it's time to read the buttons in the main task loop,
;		watches for USB suspend, and handles the HID idle
;		timer.
;
;*******************************************************

1ms_timer:
	push A


	;**********************************
	; poll buttons for button on/off state

	mov		A, [button_machine]
	cmp		A, BUTTON_DATA_PENDING
	jz		1ms_suspend_timer
	
		; if the main task has read the buttons, then we need to re-read the 
		; buttons and set the pending flag

		mov		A, 00h
		mov		[current_button_state], A
	left_button_read:
		iord	LEFT_BUTTON_PORT
		and		A, LEFT_BUTTON
		jnz		right_button_read
			mov		A, HID_LEFT_MOUSE_BUTTON
			or		[current_button_state], A
	right_button_read:
		iord	RIGHT_BUTTON_PORT
		and		A, RIGHT_BUTTON
		jnz		middle_button_read
			mov		A, HID_RIGHT_MOUSE_BUTTON 
			or		[current_button_state], A
	middle_button_read:
		iord	MIDDLE_BUTTON_PORT
		and		A, MIDDLE_BUTTON
		jnz		button_read_done
			mov		A, HID_MIDDLE_MOUSE_BUTTON
			or		[current_button_state], A
	button_read_done:
  		mov		A, BUTTON_DATA_PENDING
		mov		[button_machine], A


	;**********************************
	; check for no bus activity/usb suspend

	1ms_suspend_timer:
		iord	usb_status					; read bus activity bit
		and		A, BUS_ACTIVITY				; mask off activity bit
		jnz		bus_activity
			
		inc		[suspend_count]				; increment suspend counter
		mov		A, [suspend_count]
		cmp		A, 04h						; if no bus activity for 3-4ms,
		jz		usb_suspend					; then go into low power suspend
		jmp		idle_timer_handler

 		usb_suspend:

		;******************************
		; disable unused pins		
		; buttons are already resistively pulled up
		; optics inputs are pulled down by external resistors
		; must turn off LED
		; NOTE - this firmware must change for each pin out 

			mov		A, OPTIC_CONTROL | LEFT_BUTTON
			iowr	OPTIC_CONTROL_PORT


		; enable wakeup timer interrupt
			mov		A, (WAKEUP_INT | USB_RESET_INT)
			iowr 	global_int

		; suspend execution
  			mov		A, (SUSPEND | RUN)		; set suspend bit
 			ei
 			iowr	control
 			nop
			di

		; look for bus activity, if none go back into suspend
			iord	usb_status
			and		A, BUS_ACTIVITY
			jz		usb_suspend		

		; re-enable the optics in the case of the host wakeup
			mov		A, LEFT_BUTTON
			iowr	OPTIC_CONTROL_PORT


		; re-enable interrupts
			mov		A, (1MS_INT | USB_RESET_INT)
			iowr 	global_int

		; reset wakeup timer
			mov		A, 00h
			mov		[wakeup_timer], A

	bus_activity:
		mov		A, 00h						; reset suspend counter
		mov		[suspend_count], A
		iord	usb_status
		and		A, ~(BUS_ACTIVITY | 10h)	; clear bus activity bit
		iowr	usb_status


	;**********************************
	; handle HID SET_IDLE request
	
	idle_timer_handler:
		mov		A, [idle]
		cmp		A, 00h
		jz		ms_timer_done

		inc		[idle_prescaler]
		mov		A, [idle_prescaler]
		cmp		A, 04h
		jz		decrement_idle_timer
		jmp		ms_timer_done

		decrement_idle_timer:
			mov		A, 00h
			mov		[idle_prescaler], A
			dec		[idle_timer]
			jz		reset_idle_timer
			jmp		ms_timer_done
			reset_idle_timer:
				mov		A, [idle]
				mov		[idle_timer], A
				mov		A, EVENT_PENDING
				mov		[event_machine], A


	ms_timer_done:
		pop A
		reti


;*******************************************************
;
;	Interrupt: Endpoint0
;	Purpose: Usb control endpoint handler.  This interrupt
;			handler formulates responses to SETUP and 
;			CONTROL READ, and NO-DATA CONTROL transactions. 
;
;*******************************************************

Endpoint0:
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


		mov		A, [ep0_dmabuff + BMREQUESTTYPE]	; compact bmRequestType into 5 bit field
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
			mov		A, [ep0_dmabuff + BREQUEST]
			asl		A
			jacc	h2d_std_device_jumptable

		h2d_std_interface:	
			mov		A, [ep0_dmabuff + BREQUEST]
			asl		A
			jacc	h2d_std_interface_jumptable

		h2d_std_endpoint:
			mov		A, [ep0_dmabuff + BREQUEST]
			asl		A
			jacc	h2d_std_endpoint_jumptable

		h2d_class_interface:
			mov		A, [ep0_dmabuff + BREQUEST]
			asl		A
			jacc	h2d_class_interface_jumptable

		d2h_std_device:
			mov		A, [ep0_dmabuff + BREQUEST]
			asl		A
			jacc	d2h_std_device_jumptable

		d2h_std_interface:
			mov		A, [ep0_dmabuff + BREQUEST]
			asl		A
			jacc	d2h_std_interface_jumptable

		d2h_std_endpoint:
			mov		A, [ep0_dmabuff + BREQUEST]
			asl		A
			jacc	d2h_std_endpoint_jumptable

		d2h_class_interface:
			mov		A, [ep0_dmabuff + BREQUEST]
			asl		A
			jacc	d2h_class_interface_jumptable


	;;************ DEVICE REQUESTS **************

	clear_device_feature:					; CLEAR FEATURE
		mov		A, [ep0_dmabuff + WVALUELO]
		cmp		A, DEVICE_REMOTE_WAKEUP
		jnz		request_not_supported		
		mov		A, 00h						; disable remote wakeup capability
		mov		[remote_wakeup], A
		mov		A, NO_CHANGE_PENDING
		mov		[ep0_in_flag], A
		jmp		initialize_no_data_control

	set_device_feature:						; SET FEATURE
		mov		A, [ep0_dmabuff + WVALUELO]
		cmp		A, DEVICE_REMOTE_WAKEUP
		jnz		request_not_supported		
		mov		A, FFh						; enable remote wakeup capability
		mov		[remote_wakeup], A
		mov		A, NO_CHANGE_PENDING
		mov		[ep0_in_flag], A
		jmp		initialize_no_data_control

	set_device_address:						; SET ADDRESS
		mov		A, ADDRESS_CHANGE_PENDING	; set flag to indicate we
		mov		[ep0_in_flag], A			; need to change address on
		mov		A, [ep0_dmabuff + WVALUELO]
		mov		[pending_data], A
		jmp		initialize_no_data_control

	set_device_configuration:				; SET CONFIGURATION
		mov		A, [ep0_dmabuff + WVALUELO]
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
		mov		A, [remote_wakeup]			; test remote wakeup status
		and		A, FFh
		jz		remote_wakeup_disabled
		remote_wakeup_enabled:				; send remote wakeup enabled status
			mov		A, (device_status_wakeup_enabled - control_read_table)
			mov		[data_start], A
			jmp		initialize_control_read
		remote_wakeup_disabled:				; send remote wakeup disabled status
			mov		A, (device_status_wakeup_disabled - control_read_table)
			mov		[data_start], A
			jmp		initialize_control_read
		

	get_device_descriptor:					; GET DESCRIPTOR
		mov		A, [ep0_dmabuff + WVALUEHI]
		asl		A
		jacc	get_device_descriptor_jumptable

		send_device_descriptor:
			mov		A, 00h
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
			mov		A, [ep0_dmabuff + WVALUELO]
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

 			configuration_string:
				mov		A, 00h
				index	iconfiguration_string
				mov		[maximum_data_count], A
				mov		A, (iconfiguration_string - control_read_table)
				mov		[data_start], A
				jmp		initialize_control_read

		send_interface_descriptor:
			mov		A, 00h
			index	interface_desc_table
			mov		[maximum_data_count], A
			mov		A, (interface_desc_table - control_read_table)
			mov		[data_start], A
			jmp		initialize_control_read

		send_endpoint_descriptor:
			mov		A, 00h
			index	endpoint_desc_table
			mov		[maximum_data_count], A
			mov		A, (endpoint_desc_table - control_read_table)
			mov		[data_start], A
			jmp		initialize_control_read


		get_device_configuration:				; GET CONFIGURATION
			mov		A, DEVICE_CONFIG_LENGTH
			mov		[maximum_data_count], A
			mov		A, [configuration]			; test configuration status
			and		A, FFh
			jz		device_unconfigured
			device_configured:					; send configured status
				mov		A, (device_configured_table - control_read_table)
				mov		[data_start], A
				jmp		initialize_control_read
			device_unconfigured:				; send unconfigured status
				mov		A, (device_unconfigured_table - control_read_table)
				mov		[data_start], A
				jmp		initialize_control_read


	;;************ INTERFACE REQUESTS ***********

	set_interface_interface:				; SET INTERFACE
		mov		A, [ep0_dmabuff + WVALUELO]
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
		mov		A, [ep0_dmabuff + WVALUEHI]				; test if new idle time 
		cmp		A, 00h						; disables idle timer
		jz		idle_timer_disable

		mov		A, [idle_timer]				; test if less than 4ms left
		cmp		A, 01h
		jz		set_idle_last_not_expired

		mov		A, [ep0_dmabuff + WVALUEHI]				; test if time left less than
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
			mov		A, [ep0_dmabuff + WVALUEHI]			; set new idle value
			mov		[idle_timer], A
			mov		[idle], A
			jmp		set_idle_done

		set_idle_new_timer_less:			
			mov		A, 00h
			mov		[idle_prescaler], A		; reset idle prescaler
			mov		A, [ep0_dmabuff + WVALUEHI]
			mov		[idle_timer], A			; update idle time value
			mov		[idle], A
			jmp		set_idle_done

		set_idle_normal:
			mov		A, 00h					; reset idle prescaler
			mov		[idle_prescaler], A
			mov		A, [ep0_dmabuff + WVALUEHI]			; update idle time value
			mov		[idle_timer], A
			mov		[idle], A

		set_idle_done:
			mov		A, NO_CHANGE_PENDING	; respond with no-data control
			mov		[ep0_in_flag], A		; transaction
			jmp		initialize_no_data_control


	set_interface_protocol:					; SET PROTOCOL
		mov		A, [ep0_dmabuff + WVALUELO]
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

		mov		A, TRANS_CONTROL_READ
		mov		[ep0_transtype], A
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

		mov		A, TRANS_CONTROL_READ
		mov		[ep0_transtype], A
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


	get_interface_hid:						; GET HID REPORT DESCRIPTOR
		mov		A, [ep0_dmabuff + WVALUEHI]
		cmp		A, 22h						; test if report request
		jz		get_hid_report_desc
		cmp		A, 21h						; test if class request
		jz		get_hid_desc
		jmp		request_not_supported

		get_hid_desc:
		mov		A, 00h
		index	hid_desc_table	
		mov		[maximum_data_count], A		; get offset of device descriptor table
		mov		A, (hid_desc_table - control_read_table)
		mov		[data_start], A
		jmp		initialize_control_read		; get ready to send data

		get_hid_report_desc:
		mov		A, 07h
		index	hid_desc_table		
		mov		[maximum_data_count], A		; get offset of device descriptor table
		mov		A, (hid_report_desc_table - control_read_table)
		mov		[data_start], A
		jmp		initialize_control_read		; get ready to send data


	;;************ ENDPOINT REQUESTS ************

	clear_endpoint_feature:					; CLEAR FEATURE
		mov		A, [ep0_dmabuff + WVALUELO]
		cmp		A, ENDPOINT_STALL
		jnz		request_not_supported		
		mov		A, 00h						; clear endpoint 1 stall
		mov		[ep1_stall], A
		mov		A, NO_CHANGE_PENDING		; respond with no-data control
		mov		[ep0_in_flag], A
		jmp		initialize_no_data_control

	set_endpoint_feature:					; SET FEATURE
		mov		A, [ep0_dmabuff + WVALUELO]
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
		mov		A, [ep0_dmabuff + WLENGTHHI]				; find lesser of requested and maximum
		cmp		A, 00h
		jnz		initialize_control_read_done
		; and wLengthlo < maximum_data_count
		mov		A, [ep0_dmabuff + WLENGTHLO]				; find lesser of requested and maximum
		cmp		A, [maximum_data_count]		; response lengths
		jnc		initialize_control_read_done
		; then maximum_data_count >= wLengthlo
		mov		A, [ep0_dmabuff + WLENGTHLO]
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
		mov		A, STALL_IN_OUT					; send a stall to indicate that the request
		iowr	ep0_mode					; is not supported
		pop		A
		pop		X
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
		mov		A, STATUS_IN_ONLY
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
		mov		A, STATUS_OUT_ONLY
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

		iord	ep0_count						; check for correct data toggle
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
;	Interrupt handler: Endpoint1
;	Purpose: This interrupt routine handles the specially
;		 reserved data endpoint 1 (for a mouse).  This
;		 interrupt happens every time a host sends an
;		 IN on endpoint 1.  The data to send (NAK or 3
;		 byte packet) is already loaded, so this routine
;		 just prepares the dma buffers for the next packet
;
;*******************************************************

Endpoint1:
	push	A

	iord	ep1_mode						; if the interrupt was caused by
	and	A, EP_ACK							; a NAK or STALL, then just set
	jz	endpoint1_set_response				; response and return

	;**********************************
	; change data toggle
	mov		A, 80h
	xor		[ep1_data_toggle], A

	;**********************************
	; clear endpoint variables
	mov		A, 00h							; clear x,y,z cursor change values
	mov		[ep1_dmabuff1], A
	mov		[ep1_dmabuff2], A
	mov		[ep1_dmabuff3], A

	;**********************************
	; set response
	endpoint1_set_response:
	mov		A, [ep1_stall]					; if endpoint is set to stall, then set
	cmp		A, FFh							; mode to stall
	jnz		endpoint1_nak
		mov		A, STALL_IN_OUT
		iowr	ep1_mode
		jmp	endpoint1_done
	endpoint1_nak:
		mov	A, NAK_IN						; clear the ACK and STALL bits
		iowr	ep1_mode

	endpoint1_done:
		pop		A
		reti


;*******************************************************
;
;	Interrupt: Wakeup
;	Purpose:   This interrupt happens during USB suspend
;			when the microcontroller wakes up due to the
;			internal wakeup timer.  The buttons and optics
;			are then polled for any change in state.  If
;			a change occurs then a wakeup/resume signal
;			is forced on the bus by this microcontroller.
;
;*******************************************************

Wakeup:
	push	A

	;**********************************
	; reset watchdog
	iowr	watchdog

	;**********************************
	; test if remote wakeup is enabled
	mov		A, [remote_wakeup]
	cmp		A, 00h
	jz		wakeup_done


	;**********************************
	; wait for a couple wakeup times to pass
	; some hosts mess up if we drive a remote wakeup after 100ms
	mov		A, 05h
	cmp		A, [wakeup_timer]
	jz		test_buttons		
	inc		[wakeup_timer]
	jmp		wakeup_done


	;**********************************
	; test for button status change
	test_buttons:
		mov		A, 00h
		mov		[int_temp], A
	wakeup_left_button_read:
		iord	LEFT_BUTTON_PORT
		and		A, LEFT_BUTTON
		jnz		wakeup_right_button_read
			mov		A, HID_LEFT_MOUSE_BUTTON
			or		[int_temp], A
	wakeup_right_button_read:
		iord	RIGHT_BUTTON_PORT
		and		A, RIGHT_BUTTON
		jnz		wakeup_middle_button_read
			mov		A, HID_RIGHT_MOUSE_BUTTON 
			or		[int_temp], A
	wakeup_middle_button_read:
		iord	MIDDLE_BUTTON_PORT
		and		A, MIDDLE_BUTTON
		jnz		wakeup_button_read_done
			mov		A, HID_MIDDLE_MOUSE_BUTTON
			or		[int_temp], A
	wakeup_button_read_done:
		mov		A, [int_temp]
		xor		A, [current_button_state]
		jnz		force_wakeup		


	;**********************************
	; test for optics status change

	; turn on optics
	mov		A, LEFT_BUTTON
	iowr	OPTIC_CONTROL_PORT

	; wait 100us for phototransistors to turn on
	mov		A, 80h							
	optic_delay:
		dec	A
		jnz	optic_delay

	; test x-axis for change
	mov		A, 00h
	mov		[int_temp], A

	test_x0:
	iord	X_OPTICS_PORT
	mov		X, A
	and		A, X0
	jz		test_x1
		mov		A, 01h
		or		[int_temp], A
	test_x1:
	mov		A, X
	and		A, X1
	jz		test_x
		mov		A, 02h
		or		[int_temp], A

	test_x:
		mov		A, [int_temp]
		cmp		A, [x_last_state]
		jnz		force_wakeup

	; test y-axis for change
	mov		A, 00h
	mov		[int_temp], A

	test_y0:
	iord	Y_OPTICS_PORT
	mov		X, A
	and		A, Y0
	jz		test_y1
		mov		A, 01h
		or		[int_temp], A
	test_y1:
	mov		A, X
	and		A, Y1
	jz		test_y
		mov		A, 02h
		or		[int_temp], A

	test_y:
		mov		A, [int_temp]
		cmp		A, [y_last_state]
		jnz		force_wakeup

	; test z-axis for change
	mov		A, 00h
	mov		[int_temp], A

	test_z0:
	iord	Z_OPTICS_PORT
	mov		X, A
	and		A, Z0
	jz		test_z1
		mov		A, 01h
		or		[int_temp], A
	test_z1:
	mov		A, X
	and		A, Z1
	jz		test_z
		mov		A, 02h
		or		[int_temp], A

	test_z:
		mov		A, [int_temp]
		cmp		A, [z_last_state]
		jnz		force_wakeup


	; if there is no change in the optics, then we need to go back to sleep
	mov		A, LEFT_BUTTON | OPTIC_CONTROL
	iowr	OPTIC_CONTROL_PORT

	pop		A
	reti


	;**********************************
	; force resume for 14ms
	force_wakeup:
		mov		A, VREG_ENABLE | CONTROL1		; force J
		iowr	usb_status
		mov		A, VREG_ENABLE | CONTROL0		; force K
		iowr	usb_status
	
		mov		A, 48h						; wait 14ms
		outer_wakeup_timer:
			push	A
			iowr	watchdog
			mov		A, FFh
			inner_wakeup_timer:
				dec		A
				jnz		inner_wakeup_timer
			pop		A
			dec		A
			jnz		outer_wakeup_timer

	mov		A, VREG_ENABLE | BUS_ACTIVITY	; disable forcing and signal
	iowr	usb_status						; that we are about to have
											; bus activity
	wakeup_done:
		pop		A
		reti

	
;**********************************************************
;				USB REQUEST JUMP TABLES
;**********************************************************

XPAGEOFF
ORG		700h

		; bmRequestTypes commented out are not used for this device,
		; but may be used for your device.  They are kept here as
		; an example of how to use this jumptable.

		bmRequestType_jumptable:
			jmp		h2d_std_device			; 00
			jmp		h2d_std_interface		; 01	
			jmp		h2d_std_endpoint		; 02	
			jmp		request_not_supported	; h2d_std_other			03	
			jmp		request_not_supported	; h2d_class_device		04	
			jmp		h2d_class_interface		; 05	
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
			jmp		d2h_class_interface		; 15	
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
			jmp		clear_device_feature	; 01
			jmp		request_not_supported	; 02
			jmp		set_device_feature		; 03
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

		h2d_class_interface_jumptable:
			jmp		request_not_supported	; 00
			jmp		request_not_supported	; 01
			jmp		request_not_supported	; 02
			jmp		request_not_supported	; 03
			jmp		request_not_supported	; 04
			jmp		request_not_supported	; 05
			jmp		request_not_supported	; 06
			jmp		request_not_supported	; 07
			jmp		request_not_supported	; 08
			jmp		request_not_supported	; set_report 09
			jmp		set_interface_idle		; 0A
			jmp		set_interface_protocol	; 0B
									
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
	
		d2h_class_interface_jumptable:
			jmp		request_not_supported	; 00
			jmp		get_interface_report	; 01
			jmp		get_interface_idle		; 02
			jmp		get_interface_protocol	; 03

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
			jmp		request_not_supported
			jmp		configuration_string


;*********************************************************
;       		USB DESCRIPTOR ROM TABLES
;*********************************************************

XPAGEOFF
ORG		800h

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
	db	20h, 63h	; idProduct (Cypress USB mouse product ID)
	db	00h, 01h	; bcdDevice (1.00) 
	db	01h			; iManufacturer (Cypress Semiconductor)
	db	02h			; iProduct (Cypress 632xx Mouse)
	db	00h			; iSerialNumber (not supported)
	db	01h			; bNumConfigurations (1)

   config_desc_table:
	db	09h			; bLength (9 bytes)
	db	02h			; bDescriptorType (CONFIGURATION)
	db	22h, 00h	; wTotalLength (34 bytes)
	db	01h			; bNumInterfaces (1)
	db	01h			; bConfigurationValue (1)
	db	04h			; iConfiguration (USB HID Compliant Mouse)
	db	A0h			; bmAttributes (bus powered, remote wakeup)
	db	32h			; MaxPower (100mA)
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
	db	48h, 00h	; wDescriptorLength (72 bytes) 
   endpoint_desc_table:
	db	07h			; bLength (7 bytes)
	db	05h			; bDescriptorType (ENDPOINT)
	db	81h			; bEndpointAddress (IN endpoint, endpoint 1)
	db	03h			; bmAttributes (interrupt)
	db	04h, 00h	; wMaxPacketSize (4 bytes)
	db	0Ah			; bInterval (10ms)

hid_report_desc_table:
	db	05h, 01h	; usage page (generic desktop)
	db	09h, 02h	; usage (mouse)
	db	A1h, 01h	; collection (application)
	db	05h, 09h	; usage page (buttons)
	db	19h, 01h	; usage minimum (1 button)
	db	29h, 03h	; usage maximum (3 buttons)
	db	15h, 00h	; logical minimum (0)
	db	25h, 01h	; logical maximum (1)
	db	95h, 03h	; report count (3 reports)
	db	75h, 01h	; report size (1 bit each)
	db	81h, 02h	; input (Data, Var, Abs)
	db	95h, 01h	; report count (1 report)
	db	75h, 05h	; report size (5 bits)
	db	81h, 03h	; input (Cnst, Ary, Abs)
	db	05h, 01h	; usage page (generic desktop)
	db	09h, 01h	; usage (pointer)
	db	A1h, 00h	; collection (linked)
	db	09h, 30h	; usage (X)
	db	09h, 31h	; usage (Y)
	db	15h, 81h	; logical minimum (-127)
	db	25h, 7Fh	; logical maximum (127)
	db	75h, 08h	; report size (8 bits each)
	db	95h, 02h	; report count (2 reports)
	db	81h, 06h	; input (Cnst, Var, Rel)
	db	C0h			; end collection	
	db	09h, 38h	; wheel
	db	95h, 01h	; wheel size = 1 byte
	db	81h, 06h	; variable data bit field with relative position
	db	09h, 3ch	; motion wake up
	db	15h, 00h	; 0 no movement
	db	25h, 01h	; 1 movement
	db	75h, 01h	; 1st bit represent movement
	db	95h, 01h	; 1 report
	db	b1h, 22h	; variable data bit field with absolute positioning and no preferred state
	db	95h, 07h	; 7 reports for reversing, upper 7 bits of byte 3
	db	b1h, 01h	; constant array bit field with absolute positioning
	db	0c0h		; end collection, end collection

   device_status_wakeup_enabled:
    db  02h, 00h    ; remote wakeup enabled, bus powered
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
    db 28h          				; Length
    db 03h          				; Type (3=string)
    dsu "Cypress 632xx Mouse"

   iconfiguration_string:
    db 28h          				; Length
    db 03h          				; Type (3=string)
    dsu "HID-Compliant Mouse"


;**********************************************************
;				TASK LOOP JUMP TABLES
;**********************************************************

XPAGEOFF
ORG 900h

		button_machine_jumptable:
			jmp		no_button_task
			jmp		button_task

		event_machine_jumptable:
			jmp		no_event_task
			jmp		event_pending

		x_jumptable:					; [x_last_state]	[x_current_state]
			jmp	analyze_y_optics		; 00     			00	
			jmp	x_increment				; 00				01
			jmp	x_decrement				; 00				10
			jmp	analyze_y_optics		; 00				11
			jmp	x_decrement				; 01				00
			jmp	analyze_y_optics		; 01				01
			jmp	analyze_y_optics		; 01				10
			jmp	x_increment				; 01				11
			jmp	x_increment				; 10				00
			jmp	analyze_y_optics		; 10				01
			jmp	analyze_y_optics		; 10				10
			jmp	x_decrement				; 10				11
			jmp	analyze_y_optics		; 11				00
			jmp	x_decrement				; 11				01
			jmp	x_increment				; 11				10
			jmp	analyze_y_optics		; 11				11

		y_jumptable:					; [y_last_state]	[y_current_state]
			jmp	analyze_z_optics		; 00     			00	
			jmp	y_decrement				; 00				01
			jmp	y_increment				; 00				10
			jmp	analyze_z_optics		; 00				11
			jmp	y_increment				; 01				00
			jmp	analyze_z_optics		; 01				01
			jmp	analyze_z_optics		; 01				10
			jmp	y_decrement				; 01				11
			jmp	y_decrement				; 10				00
			jmp	analyze_z_optics		; 10				01
			jmp	analyze_z_optics		; 10				10
			jmp	y_increment				; 10				11
			jmp	analyze_z_optics		; 11				00
			jmp	y_increment				; 11				01
			jmp	y_decrement				; 11				10
			jmp	analyze_z_optics		; 11				11

		z_jumptable:					; [z_last_state]	[z_current_state]
			jmp	optic_task_done			; 00     			00	
			jmp	z_backward				; 00				01
			jmp	z_forward				; 00				10
			jmp	optic_task_done			; 00				11
			jmp	z_forward				; 01				00
			jmp	optic_task_done			; 01				01
			jmp	optic_task_done			; 01				10
			jmp	z_backward				; 01				11
			jmp	z_backward				; 10				00
			jmp	optic_task_done			; 10				01
			jmp	optic_task_done			; 10				10
			jmp	z_forward				; 10				11
			jmp	optic_task_done			; 11				00
			jmp	z_forward				; 11				01
			jmp	z_backward				; 11				10
			jmp	optic_task_done			; 11				11

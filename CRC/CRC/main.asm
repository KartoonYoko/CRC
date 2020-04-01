; CRC.asm
; Created: 02.03.2020 20:00:13

; Replace with your application code
;############################################
;###									  ###
;###	���������� ���������� ����������� ###
;### ����� CRC							  ###
;###									  ###
;############################################
; RAMEND - ���������, ������� ���������� ����� ������� ����� ���
; DDRx - ������� �����, ������� ���������� ��� ������(0 - ����, 1 - �����)
; PORTx - ������� �����, ������� ������ ��� ��������(1 - ������ �������� ������, 0 - �������)
; PINx - ������ ����������� ������� �������� ����� x



;------------ ������� ����������

.include "m644def.inc"								; ����������� ����� �������� ���������. ��� ���� ��������� �������� �� �����
.list												; ��������� ��������

; RAM ========================================================
			.DSEG

			.equ MAXBUFF_IN	 =	10	
			.equ MAXBUFF_OUT = 	10
	
IN_buff:	.byte	MAXBUFF_IN
IN_PTR_S:	.byte	1
IN_PTR_E:	.byte	1
IN_FULL:	.byte	1	

OUT_buff:	.byte	MAXBUFF_OUT
OUT_PTR_S:	.byte	1
OUT_PTR_E:	.byte	1
OUT_FULL:	.byte	1

; FLASH ======================================================
         .CSEG
         .ORG $000        	; (RESET) 
         RJMP   Reset
         .ORG $002
         RETI             	; (INT0) External Interrupt Request 0
         .ORG $004
         RETI             	; (INT1) External Interrupt Request 1
         .ORG $006
         RETI		      	; (TIMER2 COMP) Timer/Counter2 Compare Match
         .ORG $008
         RETI             	; (TIMER2 OVF) Timer/Counter2 Overflow
         .ORG $00A
         RETI		      	; (TIMER1 CAPT) Timer/Counter1 Capture Event
         .ORG $00C 
         RETI			  	; (TIMER1 COMPA) Timer/Counter1 Compare Match A
         .ORG $00E
         RETI				; (TIMER1 COMPB) Timer/Counter1 Compare Match B
         .ORG $010
         RETI			  	; (TIMER1 OVF) Timer/Counter1 Overflow
         .ORG $012
         RETI			 	; (TIMER0 OVF) Timer/Counter0 Overflow
         .ORG $014
         RETI             	; (SPI,STC) Serial Transfer Complete
         .ORG $016
         RJMP	RX_OK	  	; (USART,RXC) USART, Rx Complete
         .ORG $018
         RJMP	UD_OK       ; (USART,UDRE) USART Data Register Empty
         .ORG $01A
         RJMP	TX_OK      	; (USART,TXC) USART, Tx Complete
         .ORG $01C
         RETI		      	; (ADC) ADC Conversion Complete
         .ORG $01E
         RETI             	; (EE_RDY) EEPROM Ready
         .ORG $020
         RETI             	; (ANA_COMP) Analog Comparator
         .ORG $022
         RETI             	; (TWI) 2-wire Serial Interface
         .ORG $024
         RETI             	; (INT2) External Interrupt Request 2
         .ORG $026
         RETI             	; (TIMER0 COMP) Timer/Counter0 Compare Match
         .ORG $028
         RETI             	; (SPM_RDY) Store Program Memory Ready
	
	 	.ORG   INT_VECTORS_SIZE      	
;========================================================= ����� ������� ����������

.cseg												; ����� �������� ����������� ����
.def	Msg_frstBite = r17							; ������ ������ ���� ���������
.def	Msg_scndBite = r16							; ������ ������ ���� ���������


.def	temp = r23									; ��������� ������� ��� ���������� ������� �����
;------------------- �������� ��� ������� crc
.def	pol_frst = r21								; ������� ������ (������� ����)
.def	pol_scnd = r22								; ������� ������ (������� ����)
.def	counter = r20								; ������� �����
.def	msg = r24									; ��� �������� ���������� ����� ���������

;------------------- ���������� crc ��������� (XL - ������� ���� � XH - �������)
ldi		XL, 0xFF							
ldi		XH, 0xFF	
												
;------------------- ������� �������
ldi		pol_frst, 0xA0
ldi		pol_scnd, 0x01

;------------------- ������������� ����� �� �����
ldi		temp, 0xFF
out		DDRB, temp 
out		DDRC, temp

;------------------- ���������
ldi		Msg_frstBite, 0x10					
ldi		Msg_scndBite, 0x10	

;------------ ������ ���� ���������

; �� ���� 0x1010 ��� 0b1000000010000. �� ����� 0xBC0D ��� 0b1011110000001101 (��� ��������)
main:
	RCALL	uart_rcv					; ���� �����
	mov		msg, r16					; ������� � ��������������� �������
	call	crc_calculation				; ������������ ���������� crc
	nop									; ��������� � ������ todo: �������� ���������� � �����
	RCALL	uart_snt					; ���������� �������.
	JMP		Main

	mov		msg, Msg_frstBite
	call	crc_calculation
	mov		msg, Msg_scndBite
	call	crc_calculation
	out		DDRB, xl
	out		DDRC, xh

	nop
	nop
	nop


	
;------------------- ������� ��� ������� crc
; IN:	pol_frst (21) - ������ ���� �������� ��������� ������
;		pol_scnd (22) - ������ ���� �������� ��������� ������
;		msg		 (16) - ������ 8 ��� ��������� ��� ���������
;		�ounter	 (20) - ������� ��� �����
; OUT: 	XH - ������� ���� crc
;		XL - ������� ���� crc
crc_calculation:
		eor		xh, msg							; ����������� ��� � 8 ������ ���������

	;------------------- ����, � ����������� ������ 1 ���� ������ (���� ��� ����� 1 - XOR � A001; ����� ����� ����� ������)
		ldi		counter, 0x00

	crcl_1:
	;------------------- ������� �����(��e����� ����� �������� ���������� 8 ���)
		inc		counter
		cpi		counter, 9
		breq	end_crc_calculation						; �������, ���� �����
	;------------------- 
		lsr		XL										; ����� �� ���� ��� ������ ���������� c ����������� �������� ���� � ����� ��������
		ror		xh										; ����� ������, ������� ����� ��� ���������� ��������� �� ����� ��������
		brcc	crcl_1									; ���� ���������� ��� = 0, ��������� 

	;-------------------  ����������� ��� ����������� �������� �� ��������� A001h
		eor		XL, pol_frst
		eor		xh, pol_scnd
		jmp		crcl_1
	end_crc_calculation:
ret


;=========================== ���������� ����� ��������� 1 �����
; ������� � ����� ��������� ����
RX_OK:		
		PUSHF									; ������, �������� � ���� SREG � R16
		PUSH	R17
		PUSH	R18
		PUSH	XL
		PUSH	XH
 
		LDI		XL,low(IN_buff)					; ����� ����� ������ �������
		LDI		XH,high(IN_buff)
		LDS		R16,IN_PTR_E					; ����� �������� ����� ������
		LDS		R18,IN_PTR_S					; ����� �������� ����� ������
 
		ADD		XL,R16							; ��������� ������ �� ���������
		CLR		R17								; �������� ����� ����� ������
		ADC		XH,R17
 
		IN		R17,UDR							; �������� ������
		ST		X,R17							; ��������� �� � ������
 
		INC		R16								; ����������� ��������
 
		CPI		R16,MAXBUFF_IN					; ���� �������� ����� 
		BRNE	NoEnd	
		CLR		R16								; ������������ �� ������
 
NoEnd:		
		CP		R16,R18							; ����� �� ������������� ������?
		BRNE	RX_OUT							; ���� ���, �� ������ �������
 
 
RX_FULL:	LDI	R18,1							; ���� ��, �� ������ ����������.
		STS	IN_FULL,R18							; ���������� ���� �������������
 
RX_OUT:		STS	IN_PTR_E,R16					; ��������� ��������. �������
 
		POP	XH
		POP	XL
		POP	R18
		POP	R17
		POPF									; ������� SREG � R16
RETI




TX_OK:		
		PUSHF						
tx_ok_begin:
		call		Buff_Pop							; ���������� �������� r17 � r19
		cpi			r19, 1
		breq		tx_ok_end							; ���������, ���� ����� ����

		mov			msg, r17
		call		crc_calculation						; �������� 16, 20, 21, 22, xh, xl

		jmp			tx_ok_begin



tx_ok_end:
		LDI 			R16, (1<<RXEN)|(1<<TXEN)|(1<<RXCIE)|(1<<TXCIE)|(0<<UDRIE)			; ��������� ���������� UDRE
		OUT 			UCSRB, R16
		POPF
RETI


; ������ �� ������ �� �����
; IN: NONE
; OUT: 	R17 - Data,
;		R19 - ERROR CODE (������ 1, ���� ����� ����) 
Buff_Pop: 	CLI 				; ��������� ���������. 
						; �� ����� ��������� ���������� ���������  �� 
						; UART, ��� ��������� ������ ���.
		LDI	XL,low(IN_buff)		; ����� ����� ������ �������
		LDI	XH,high(IN_buff)
		LDS	R16,IN_PTR_E		; ����� �������� ����� ������
		LDS	R18,IN_PTR_S		; ����� �������� ����� ������			
		LDS	R19,IN_FULL		; ���� ���� ������������
 
		CPI	R19,1			; ���� ������ ����������, �� ��������� ������
		BREQ	NeedPop			; ����� ��������� �����. ��� ���� ������.
 
		CP	R18,R16			; ��������� ������ ������ ��������� ������?
		BRNE	NeedPop			; ���! ������ �� ����. �������� ������
 
		LDI	R19,1			; ��� ������ - ������ ������!
 
		RJMP	_TX_OUT			; �������
 
NeedPop:	CLR	R17			; �������� ����
		STS	IN_FULL,R17		; ���������� ���� ������������
 
		ADD	XL,R18			; ��������� ������ �� ���������
		ADC	XH,R17			; �������� ����� ����� ������
 
		LD	R17,X			; ����� ���� �� �������
		CLR	R19			; ����� ���� ������
 
		INC	R18			; ����������� �������� ��������� ������
 
		CPI	R18,MAXBUFF_OUT		; �������� ����� ������?
		BRNE	_TX_OUT			; ���? 
 
		CLR	R18			; ��? ����������, ����������� �� 0
 
_TX_OUT:	STS	IN_PTR_S,R18		; ��������� ���������
		SEI				; ��������� ����������
RET






; XTAL � ������� �������� ������� �����������.
; baudrate � ��������� �������� � ��� ��������� ��� ��������. 9600 � ����������� ������� �������)
		.equ 	XTAL = 8000000 	
		.equ 	baudrate = 9600  
		.equ 	bauddivider = XTAL/(16*baudrate)-1			; ��� 8000000 � 9600 = 51.083

;----------------------------- ������� ������������� uart
uart_init:	
		LDI 	R16, low(bauddivider)
		OUT 	UBRRL,R16
		LDI 	R16, high(bauddivider)
		OUT 	UBRRH,R16	
; ����� uart ������������ � ����
		LDI 	R16,0
		OUT 	UCSRA, R16
; ���������� ���������, �����-�������� ��������.
; ���� RXEN � TXEN � ���������� ������ � ��������
; ���� RXCIE, TXCIE, UDRIE ��������� ���������� �� ���������� ������, �������� � ����������� ������ �������� UDR.
		LDI 	R16, (1<<RXEN)|(1<<TXEN)|(1<<RXCIE)|(1<<TXCIE)|(0<<UDRIE)
		OUT 	UCSRB, R16	
; ������ ����� - 8 ���, ����� � ������� UCSRC, �� ��� �������� ��� ��������
		LDI 	R16, (1<<URSEL)|(1<<UCSZ0)|(1<<UCSZ1)
		OUT 	UCSRC, R16
		RET
;-----------------------------


;----------------------------- ������� �������� �����
uart_snt:	
		SBIS 	UCSRA,UDRE		; ������� ���� ��� ����� ����������
		RJMP	uart_snt 		; ���� ���������� - ����� UDRE
 
		OUT		UDR, R16		; ���� ����
		RET						; �������
;-----------------------------


;----------------------------- ������� ������ �����
uart_rcv:	
		SBIS	UCSRA,RXC		; ���� ����� ������� �����
		RJMP	uart_rcv		; �������� � �����
 
		IN		R16,UDR0		; ���� ������ - ��������.
		RET						; �������. ��������� � R16
;-----------------------------





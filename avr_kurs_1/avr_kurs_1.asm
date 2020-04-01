			.include "m16def.inc"   ; ���������� ATMega16
			.include "macro.inc"

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
	
	 	.ORG   INT_VECTORS_SIZE      	; ����� ������� ����������

; Interrupts ==============================================


RX_OK:		PUSHF						; ������, �������� � ���� SREG � R16
			PUSH	R17
			PUSH	R18
			PUSH	XL
			PUSH	XH

			LDI		XL,low(IN_buff)		; ����� ����� ������ �������
			LDI		XH,high(IN_buff)
			LDS		R16,IN_PTR_E		; ����� �������� ����� ������
			LDS		R18,IN_PTR_S		; ����� �������� ����� ������

			ADD		XL,R16				; ��������� ������ �� ���������
			CLR		R17					; �������� ����� ����� ������
			ADC		XH,R17
			
			IN		R17,UDR				; �������� ������
			ST		X,R17				; ��������� �� � ������

			INC		R16					; ����������� ��������

			CPI		R16,MAXBUFF_IN		; ���� �������� ����� 
			BRNE	NoEnd
			CLR		R16					; ������������ �� ������

NoEnd:		CP		R16,R18				; ����� �� ������������� ������?
			BRNE	RX_OUT				; ���� ���, �� ������ �������


RX_FULL:	LDI		R18,1				; ���� ��, �� ������ ����������.
			STS		IN_FULL,R18			; ���������� ���� �������������
			
RX_OUT:		STS		IN_PTR_E,R16		; ��������� ��������. �������

			POP		XH
			POP		XL
			POP		R18
			POP		R17
			POPF						; ������� SREG � R16
			RETI


TX_OK:		PUSHF						; ��������� ���������� UDRE
			LDI 	R16, (1<<RXEN)|(1<<TXEN)|(1<<RXCIE)|(1<<TXCIE)|(0<<UDRIE)
			OUT 	UCSRB, R16
			POPF
			RETI



UD_OK:		PUSHF						
			PUSH	R17
			PUSH	R18
			PUSH	R19
			PUSH	XL
			PUSH	XH


			LDI		XL,low(OUT_buff)	; ����� ����� ������ �������
			LDI		XH,high(OUT_buff)
			LDS		R16,OUT_PTR_E		; ����� �������� ����� ������
			LDS		R18,OUT_PTR_S		; ����� �������� ����� ������			
			LDS		R19,OUT_FULL		; ���� ���� ������������

			CPI		R19,1				; ���� ������ ����������, �� ��������� ������
			BREQ	NeedSend			; ����� ��������� �����. ��� ���� ������.

			CP		R18,R16				; ��������� ������ ������ ��������� ������?
			BRNE	NeedSend			; ���! ������ �� ����. ���� ����� ������

			LDI 	R16,1<<RXEN|1<<TXEN|1<<RXCIE|1<<TXCIE|0<<UDRIE	; ������ ����������
			OUT 	UCSRB, R16										; �� ������� UDR
			RJMP	TX_OUT				; �������

NeedSend:	CLR		R17					; �������� ����
			STS		OUT_FULL,R17		; ���������� ���� ������������

			ADD		XL,R18				; ��������� ������ �� ���������
			ADC		XH,R17				; �������� ����� ����� ������

			LD		R17,X				; ����� ���� �� �������
			OUT		UDR,R17				; ���������� ��� � USART

			INC		R18					; ����������� �������� ��������� ������

			CPI		R18,MAXBUFF_OUT		; �������� ����� ������?
			BRNE	TX_OUT				; ���? 
			
			CLR		R18					; ��? ����������, ����������� �� 0

TX_OUT:		STS		OUT_PTR_S,R18		; ��������� ���������
			
			POP		XH
			POP		XL
			POP		R19
			POP		R18
			POP		R17
			POPF						; �������, ������ ��� �� �����
			RETI
; End Interrupts ==========================================

; Load Loop Buffer 
; IN R19 	- DATA
; OUT R19 	- ERROR CODE 
Buff_Push:	LDI		XL,low(OUT_buff)	; ����� ����� ������ �������
			LDI		XH,high(OUT_buff)
			LDS		R16,OUT_PTR_E		; ����� �������� ����� ������
			LDS		R18,OUT_PTR_S		; ����� �������� ����� ������

			ADD		XL,R16				; ��������� ������ �� ���������
			CLR		R17					; �������� ����� ����� ������
			ADC		XH,R17
			

			ST		X,R19				; ��������� �� � ������
			CLR		R19					; ������� R19, ������ ��� ��� ������
										; ������� ������ ������������

			INC		R16					; ����������� ��������

			CPI		R16,MAXBUFF_OUT		; ���� �������� ����� 
			BRNE	_NoEnd
			CLR		R16					; ������������ �� ������

_NoEnd:		CP		R16,R18				; ����� �� ������������� ������?
			BRNE	_RX_OUT				; ���� ���, �� ������ �������


_RX_FULL:	LDI		R19,1				; ���� ��, �� ������ ����������.
			STS		OUT_FULL,R19		; ���������� ���� �������������
										; � R19 �������� 1 - ��� ������ ������������
			
_RX_OUT:	STS		OUT_PTR_E,R16		; ��������� ��������. �������
			RET

; Read from loop Buffer
; IN: NONE
; OUT: 	R17 - Data,
;		R19 - ERROR CODE

Buff_Pop: 	LDI		XL,low(IN_buff)		; ����� ����� ������ �������
			LDI		XH,high(IN_buff)
			LDS		R16,IN_PTR_E		; ����� �������� ����� ������
			LDS		R18,IN_PTR_S		; ����� �������� ����� ������			
			LDS		R19,IN_FULL			; ���� ���� ������������

			CPI		R19,1				; ���� ������ ����������, �� ��������� ������
			BREQ	NeedPop				; ����� ��������� �����. ��� ���� ������.

			CP		R18,R16				; ��������� ������ ������ ��������� ������?
			BRNE	NeedPop				; ���! ������ �� ����. �������� ������

			LDI		R19,1				; ��� ������ - ������ ������!
												
			RJMP	_TX_OUT				; �������

NeedPop:	CLR		R17					; �������� ����
			STS		IN_FULL,R17			; ���������� ���� ������������

			ADD		XL,R18				; ��������� ������ �� ���������
			ADC		XH,R17				; �������� ����� ����� ������

			LD		R17,X				; ����� ���� �� �������
			CLR		R19					; ����� ���� ������

			INC		R18					; ����������� �������� ��������� ������

			CPI		R18,MAXBUFF_OUT		; �������� ����� ������?
			BRNE	_TX_OUT				; ���? 
			
			CLR		R18					; ��? ����������, ����������� �� 0

_TX_OUT:	STS		IN_PTR_S,R18		; ��������� ���������
			RET



; RUN =====================================================
Reset:   	STACKINIT					; ������������� �����
			RAMFLUSH					; ������� ������

; Usart INIT
			.equ 	XTAL = 8000000 	
			.equ 	baudrate = 9600  
			.equ 	bauddivider = XTAL/(16*baudrate)-1

uart_init:	LDI 	R16, low(bauddivider)
			OUT 	UBRRL,R16
			LDI 	R16, high(bauddivider)
			OUT 	UBRRH,R16

			LDI 	R16,0
			OUT 	UCSRA, R16

; ���������� ���������, �����-�������� ��������.
			LDI 	R16, (1<<RXEN)|(1<<TXEN)|(1<<RXCIE)|(1<<TXCIE)|(0<<UDRIE)
			OUT 	UCSRB, R16	

; ������ ����� - 8 ���, ����� � ������� UCSRC, �� ��� �������� ��� ��������
			LDI 	R16, (1<<URSEL)|(1<<UCSZ0)|(1<<UCSZ1)
			OUT 	UCSRC, R16


; ������������ ��������:
			CLR		R16

			STS		IN_PTR_S,R16				; �������� ���������
			STS		IN_PTR_E,R16
			STS		OUT_PTR_S,R16
			STS		OUT_PTR_E,R16


		
			SEI
; End Internal Hardware Init ===================================



; External Hardware Init  ======================================


; End External Hardware Init  ==================================

; Run ==========================================================

; End Run ======================================================

; Main =========================================================
Main:		
LOOPS:		RCALL	Buff_Pop
			CPI		R19,1
			BREQ	LOOPS

			INC		R17

			MOV		R19,R17
			RCALL	Buff_Push
			
			CPI		R19,1
			BRNE	RUN	
			
			RCALL	Delay

RUN:		
			TX_RUN

			RJMP		LOOPS

	


; Procedure ====================================================

			.equ 	LowByte  = 255
			.equ	MedByte  = 255
			.equ	HighByte = 1

Delay:		LDI		R16,LowByte		; ������ ��� �����
			LDI		R17,MedByte		; ����� ��������
			LDI		R18,HighByte
 
loop:		SUBI	R16,1			; �������� 1
			SBCI	R17,0			; �������� ������ �
			SBCI	R18,0			; �������� ������ �
 
			BRCC	Loop 			; ���� ��� �������� - �������




uart_snt:	SBIS 	UCSRA,UDRE		; ������� ���� ��� ����� ����������
			RJMP	PC-1 			; ���� ���������� - ����� UDRE

			OUT		UDR, R16		; ���� ����
			RET


uart_rcv:	SBIS	UCSRA,RXC
			RJMP	uart_rcv

			IN		R16,UDR
			RET


; End Procedure ================================================



; EEPROM =====================================================
			.ESEG				; ������� EEPROM

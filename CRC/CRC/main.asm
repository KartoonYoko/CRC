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
.cseg												; ����� �������� ����������� ����
.def	Msg_frstBite = r17							; ������ ������ ���� ���������
.def	Msg_scndBite = r16							; ������ ������ ���� ���������


.def	temp = r23									; ��������� ������� ��� ���������� ������� �����
;------------------- �������� ��� ������� crc
.def	pol_frst = r21								; ������� ������ (������� ����)
.def	pol_scnd = r22								; ������� ������ (������� ����)
.def	counter = r20								; ������� �����
.def	msg = r24									; ��� �������� ���������� ����� ���������


;------------------- ������������� ����� �� �����
ldi		temp, 0xFF
out		DDRB, temp 
out		DDRC, temp
						
;------------------- ���������� crc ��������� (XL - ������� ���� � XH - �������)
ldi		XL, 0xFF							
ldi		XH, 0xFF	
							
;------------------- ������� �������
ldi		pol_frst, 0xA0
ldi		pol_scnd, 0x01

;------------------- ���������
ldi		Msg_frstBite, 0x10					
ldi		Msg_scndBite, 0x10	

;------------ ������ ���� ���������

; �� ���� 0x1010 ��� 0b1000000010000. �� ����� 0xBC0D ��� 0b1011110000001101 (��� ��������)
main:

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
;			������������ ��������:
; * msg - ������ 8 ��� ��������� ��� ���������
; * �ounter - ������� ��� �����
; * �������� �������� �������� ��� ������� crc
;		pol_frst - ������ ���� �������� ��������� ������
;		pol_scnd - ������ ���� �������� ��������� ������
; * �������� ��� �������� ������ crc
;		xl - ������� ���� 
;		xh - ������� ����
crc_calculation:
		eor		xh, msg							; ����������� ��� � 8 ������ ���������

	;------------------- ����, � ����������� ������ 1 ���� ������ (���� ��� ����� 1 - XOR � A001; ����� ����� ����� ������)
		ldi		counter, 0x00

	crcl_1:
	;------------------- ������� �����(������� ����� �������� ����������� 8 ���)
		inc		counter
		cpi		counter, 9
		breq	end_f									; �������, ���� �����
	;------------------- 
		lsr		XL										; ����� �� ���� ��� ������ ���������� c ������������ �������� ���� � ����� ��������
		ror		xh										; ����� ������, ������� ����� ��� ���������� ��������� �� ����� ��������
		brcc	crcl_1									; ���� ���������� ��� = 0, ��������� 

	;-------------------  ����������� ��� ����������� �������� �� ��������� A001h
		eor		XL, pol_frst
		eor		xh, pol_scnd
		jmp		crcl_1
	end_f:
ret









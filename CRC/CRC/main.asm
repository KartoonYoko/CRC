; CRC.asm
; Created: 02.03.2020 20:00:13

; Replace with your application code
;############################################
;###									  ###
;###	Программма нахождения контрольной ###
;### суммы CRC							  ###
;###									  ###
;############################################
; RAMEND - константа, которая обозначает самый верхний адрес ОЗУ
; DDRx - регистр порта, который определяет его работу(0 - вход, 1 - выход)
; PORTx - регистр порта, который хранит его значение(1 - сигнал высокого уровня, 0 - низкого)
; PINx - чтение логическитх уровней разрядов порта x



;------------ Команды управления

.include "m644def.inc"								; подключение файла описания регистров. без него программа работать не будет
.list												; включение листинга

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
;========================================================= Конец таблицы прерываний

.cseg												; выбор сегмента програмного кода
.def	Msg_frstBite = r17							; хранит первый байт сообщения
.def	Msg_scndBite = r16							; хранит второй байт сообщения


.def	temp = r23									; временный регистр для управления портами ввода
;------------------- регистры для расчета crc
.def	pol_frst = r21								; полином модбас (старший байт)
.def	pol_scnd = r22								; полином модбас (младший байт)
.def	counter = r20								; счетчик цикла
.def	msg = r24									; для хранения очередного байта сообщения

;------------------- заполнение crc единицами (XL - старший байт и XH - младший)
ldi		XL, 0xFF							
ldi		XH, 0xFF	
												
;------------------- полином модбаса
ldi		pol_frst, 0xA0
ldi		pol_scnd, 0x01

;------------------- инициализация порта на выход
ldi		temp, 0xFF
out		DDRB, temp 
out		DDRC, temp

;------------------- сообщение
ldi		Msg_frstBite, 0x10					
ldi		Msg_scndBite, 0x10	

;------------ Начало тела программы

; на вход 0x1010 или 0b1000000010000. на выход 0xBC0D или 0b1011110000001101 (для проверки)
main:
	RCALL	uart_rcv					; Ждем байта
	mov		msg, r16					; заносим в соответствующий регистр
	call	crc_calculation				; обрабатываем алгоритмом crc
	nop									; сохоаняем в буфере todo: доделать сохранение в буфер
	RCALL	uart_snt					; Отправляем обратно.
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


	
;------------------- Функция для расчета crc
; IN:	pol_frst (21) - первый байт полинома протокола Модбас
;		pol_scnd (22) - второй байт полинома протокола Модбас
;		msg		 (16) - хранит 8 бит сообщения для обработки
;		сounter	 (20) - счетчик для цикла
; OUT: 	XH - младший байт crc
;		XL - старший байт crc
crc_calculation:
		eor		xh, msg							; исключающее или с 8 битами сообщения

	;------------------- цикл, с выполнением сдвига 1 бита вправо (если бит равен 1 - XOR с A001; инчае снова сдвиг вправо)
		ldi		counter, 0x00

	crcl_1:
	;------------------- счетчик цикла(опeранды после счетчика выполнятся 8 раз)
		inc		counter
		cpi		counter, 9
		breq	end_crc_calculation						; перейти, если равно
	;------------------- 
		lsr		XL										; сдивг на один бит вправо результата c сохранением младшего бита в флаге переноса
		ror		xh										; сдвиг вправо, крайний левый бит заполнится значением из флага переноса
		brcc	crcl_1									; если сдвигаемый бит = 0, повторяем 

	;-------------------  исключающее ИЛИ содержимого регистра со значением A001h
		eor		XL, pol_frst
		eor		xh, pol_scnd
		jmp		crcl_1
	end_crc_calculation:
ret


;=========================== Прерывание после получения 1 байта
; Занесет в буфер очередной байт
RX_OK:		
		PUSHF									; Макрос, пихающий в стек SREG и R16
		PUSH	R17
		PUSH	R18
		PUSH	XL
		PUSH	XH
 
		LDI		XL,low(IN_buff)					; Берем адрес начала буффера
		LDI		XH,high(IN_buff)
		LDS		R16,IN_PTR_E					; Берем смещение точки записи
		LDS		R18,IN_PTR_S					; Берем смещение точки чтения
 
		ADD		XL,R16							; Сложением адреса со смещением
		CLR		R17								; получаем адрес точки записи
		ADC		XH,R17
 
		IN		R17,UDR							; Забираем данные
		ST		X,R17							; сохраняем их в кольцо
 
		INC		R16								; Увеличиваем смещение
 
		CPI		R16,MAXBUFF_IN					; Если достигли конца 
		BRNE	NoEnd	
		CLR		R16								; переставляем на начало
 
NoEnd:		
		CP		R16,R18							; Дошли до непрочитанных данных?
		BRNE	RX_OUT							; Если нет, то просто выходим
 
 
RX_FULL:	LDI	R18,1							; Если да, то буффер переполнен.
		STS	IN_FULL,R18							; Записываем флаг наполненности
 
RX_OUT:		STS	IN_PTR_E,R16					; Сохраняем смещение. Выходим
 
		POP	XH
		POP	XL
		POP	R18
		POP	R17
		POPF									; Достаем SREG и R16
RETI




TX_OK:		
		PUSHF						
tx_ok_begin:
		call		Buff_Pop							; использует регистры r17 и r19
		cpi			r19, 1
		breq		tx_ok_end							; закончить, если буфер пуст

		mov			msg, r17
		call		crc_calculation						; регистры 16, 20, 21, 22, xh, xl

		jmp			tx_ok_begin



tx_ok_end:
		LDI 			R16, (1<<RXEN)|(1<<TXEN)|(1<<RXCIE)|(1<<TXCIE)|(0<<UDRIE)			; Выключаем прерывание UDRE
		OUT 			UCSRB, R16
		POPF
RETI


; Чтение из буфера по байту
; IN: NONE
; OUT: 	R17 - Data,
;		R19 - ERROR CODE (вернет 1, если буфер пуст) 
Buff_Pop: 	CLI 				; Запрещаем прерыания. 
						; Но лучше запретить прерывания конкретно  от 
						; UART, чем запрещать вообще все.
		LDI	XL,low(IN_buff)		; Берем адрес начала буффера
		LDI	XH,high(IN_buff)
		LDS	R16,IN_PTR_E		; Берем смещение точки записи
		LDS	R18,IN_PTR_S		; Берем смещение точки чтения			
		LDS	R19,IN_FULL		; Берм флаг переполнения
 
		CPI	R19,1			; Если буффер переполнен, то указатель начала
		BREQ	NeedPop			; Равен указателю конца. Это надо учесть.
 
		CP	R18,R16			; Указатель чтения достиг указателя записи?
		BRNE	NeedPop			; Нет! Буффер не пуст. Работаем дальше
 
		LDI	R19,1			; Код ошибки - пустой буффер!
 
		RJMP	_TX_OUT			; Выходим
 
NeedPop:	CLR	R17			; Получаем ноль
		STS	IN_FULL,R17		; Сбрасываем флаг переполнения
 
		ADD	XL,R18			; Сложением адреса со смещением
		ADC	XH,R17			; получаем адрес точки чтения
 
		LD	R17,X			; Берем байт из буффера
		CLR	R19			; Сброс кода ошибки
 
		INC	R18			; Увеличиваем смещение указателя чтения
 
		CPI	R18,MAXBUFF_OUT		; Достигли конца кольца?
		BRNE	_TX_OUT			; Нет? 
 
		CLR	R18			; Да? Сбрасываем, переставляя на 0
 
_TX_OUT:	STS	IN_PTR_S,R18		; Сохраняем указатель
		SEI				; Разрешаем прерывания
RET






; XTAL — рабочая тактовая частота контроллера.
; baudrate — требуемая скорость — чем медленней тем надежней. 9600 в большинстве случаев хватает)
		.equ 	XTAL = 8000000 	
		.equ 	baudrate = 9600  
		.equ 	bauddivider = XTAL/(16*baudrate)-1			; при 8000000 и 9600 = 51.083

;----------------------------- Функция инициализации uart
uart_init:	
		LDI 	R16, low(bauddivider)
		OUT 	UBRRL,R16
		LDI 	R16, high(bauddivider)
		OUT 	UBRRH,R16	
; флаги uart сбрасываются в ноль
		LDI 	R16,0
		OUT 	UCSRA, R16
; Прерывания разрешены, прием-передача разрешен.
; биты RXEN и TXEN — разрешение приема и передачи
; Биты RXCIE, TXCIE, UDRIE разрешают прерывания по завершению приема, передачи и опустошении буфера передачи UDR.
		LDI 	R16, (1<<RXEN)|(1<<TXEN)|(1<<RXCIE)|(1<<TXCIE)|(0<<UDRIE)
		OUT 	UCSRB, R16	
; Формат кадра - 8 бит, пишем в регистр UCSRC, за это отвечает бит селектор
		LDI 	R16, (1<<URSEL)|(1<<UCSZ0)|(1<<UCSZ1)
		OUT 	UCSRC, R16
		RET
;-----------------------------


;----------------------------- Функция отправки байта
uart_snt:	
		SBIS 	UCSRA,UDRE		; Пропуск если нет флага готовности
		RJMP	uart_snt 		; ждем готовности - флага UDRE
 
		OUT		UDR, R16		; шлем байт
		RET						; Возврат
;-----------------------------


;----------------------------- Функция приема байта
uart_rcv:	
		SBIS	UCSRA,RXC		; Ждем флага прихода байта
		RJMP	uart_rcv		; вращаясь в цикле
 
		IN		R16,UDR0		; байт пришел - забираем.
		RET						; Выходим. Результат в R16
;-----------------------------





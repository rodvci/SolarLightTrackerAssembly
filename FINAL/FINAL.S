#define __SFR_OFFSET 0         
#include <avr/io.h>          

; === Bit Masks ===
.set SERVO_PIN,     0b00000010   ; PB1 = D9 (OC1A)  pin for servo PWM
.set LED2,          0b00001000   ; PD3 = D3 (LDR0 indicator) — LED2 ON when LDR0 triggers
.set LDR_SENSOR0,   0b00000001   ; PC0 = A0 input  (LDR0)
.set LED1,          0b00000100   ; PD2 = D2 (LDR1 indicator) — LED1 ON when LDR1 triggers
.set LDR_SENSOR1,   0b00000010   ; PC1 = A1 input  (LDR1)

.section .text
.global main

main:
    ; --- Stack Pointer Setup ---
    ldi   r16, 0xFF          
    out   SPL, r16           
    ldi   r16, 0x08          
    out   SPH, r16           

    ; --- I/O Setup ---
    ; PB1 (D9) as servo output
    ldi   r16, SERVO_PIN     
    out   DDRB, r16          

    ; PD3 (LED2) and PD2 (LED1) as outputs
    ldi   r16, LED2 | LED1   
    out   DDRD, r16          

    ; PC0 and PC1 as inputs
    ldi   r16, 0x00          
    out   DDRC, r16          

    ; --- Timer1 Fast PWM Mode 14 on OC1A, prescaler=64 ---
    ; TCCR1A: COM1A1=1 (non-inverting OC1A), WGM11=1, WGM10=1 (partial Fast PWM)
    ldi   r16, 0b10000010    
    sts   TCCR1A, r16        

    ; TCCR1B: WGM13=1, WGM12=1 (Fast PWM mode 14), CS11=1, CS10=0, CS12=1 (prescaler=64)
    ldi   r16, 0b00011011    
    sts   TCCR1B, r16        

    ; ICR1 = 0x1388 → 20 ms period @ 16 MHz, prescaler 64
    ldi   r16, 0x13          
    sts   ICR1H, r16         
    ldi   r16, 0x88          
    sts   ICR1L, r16         

    ; --- Initialize OCR1A to 90° (1.5 ms pulse) once at startup ---
    ; 1.5 ms out of 20 ms corresponds to 0x0177 (375 decimal)
    ldi   r16, 0x01          ; High byte of 0x0177
    sts   OCR1AH, r16        
    ldi   r16, 0x77          ; Low byte of 0x0177
    sts   OCR1AL, r16        

loop:
    ; Read both LDR inputs together
    in    r18, PINC          

    ; --- Check LDR1 (PC1) first → move to 0° if HIGH ---
    andi  r18, LDR_SENSOR1   
    brne  do_0deg            ; If PC1=1, jump to 0° branch
    cbi   PORTD, 2           ; Else, turn OFF LED1

    ; --- Check LDR0 (PC0) next → move to 180° if HIGH ---
    in    r18, PINC          ; Re-read PINC (since r18 was modified)
    andi  r18, LDR_SENSOR0   
    brne  do_180deg          ; If PC0=1, jump to 180° branch
    cbi   PORTD, 3           ; Else, turn OFF LED2

    ; --- NEITHER LDR is triggered: do NOT change OCR1A ---
    ; Just loop again. Servo remains at its last position.
    rjmp  loop

do_0deg:
    ; LDR1 (PC1) HIGH → want 0° (1 ms pulse = 0x0096)
    sbi   PORTD, 2          ; Turn ON LED1 to indicate LDR1 trigger
    ldi   r16, 0x00         ; High byte of 0x0096 (150 decimal)
    sts   OCR1AH, r16       ; Update OCR1A high byte
    ldi   r16, 0x96         ; Low byte of 0x0096
    sts   OCR1AL, r16       ; Update OCR1A low byte
    rjmp  loop

do_180deg:
    ; LDR0 (PC0) HIGH → want 180° (2 ms pulse = 0x0258)
    sbi   PORTD, 3          ; Turn ON LED2 to indicate LDR0 trigger
    ldi   r16, 0x02         ; High byte of 0x0258 (600 decimal)
    sts   OCR1AH, r16       ; Update OCR1A high byte
    ldi   r16, 0x58         ; Low byte of 0x0258
    sts   OCR1AL, r16       ; Update OCR1A low byte
    rjmp  loop

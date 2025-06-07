#define __SFR_OFFSET 0            ; Map Special Function Registers starting at I/O address 0
#include <avr/io.h>              ; Include device-specific register definitions

; === Bit Masks ===
.set SERVO_PIN,   0b00000010     ; PB1 (D9/OC1A)  servo PWM output pin
.set LED1,        0b00000100     ; PD2 (D2)  indicator for right-side LDR (LDR1)
.set LED2,        0b00001000     ; PD3 (D3)  indicator for left-side LDR (LDR0)
.set LDR_SENSOR1, 0b00000010     ; PC1 (A1)  right LDR input mask
.set LDR_SENSOR0, 0b00000001     ; PC0 (A0)  left LDR input mask

.section .text
.global main

main:
    ; --- Stack Pointer Setup ---
    ldi   r16, 0xFF            ; Load low byte of stack start (0xFF)
    out   SPL, r16             ; Set SPL ← 0xFF (stack low byte)
    ldi   r16, 0x08            ; Load high byte of stack start (0x08)
    out   SPH, r16             ; Set SPH ← 0x08 (stack high byte)

    ; --- I/O Direction Configuration ---
    ldi   r16, SERVO_PIN       ; Load mask for servo pin
    out   DDRB, r16            ; DDRB ← SERVO_PIN (PB1 as output)
    ldi   r16, LED1 | LED2     ; Load mask for both LEDs
    out   DDRD, r16            ; DDRD ← LED1|LED2 (PD2,PD3 as outputs)
    ldi   r16, 0x00            ; Load zero for input pins
    out   DDRC, r16            ; DDRC ← 0x00 (PC0,PC1 as inputs)

    ; --- Timer1 Fast PWM Mode14, Prescaler=64 ---
    ldi   r16, 0b10000010      ; COM1A1=1 (non-inverting), WGM11=1, WGM10=1
    sts   TCCR1A, r16          ; Configure TCCR1A for fast PWM partial
    ldi   r16, 0b00011011      ; WGM13=1, WGM12=1 (mode14), CS12=1, CS11=1 (prescale64)
    sts   TCCR1B, r16          ; Configure TCCR1B for fast PWM + prescaler
    ldi   r16, 0x13            ; High byte of ICR1 (TOP = 5000)
    sts   ICR1H, r16           ; Set ICR1H ← 0x13
    ldi   r16, 0x88            ; Low byte of ICR1 (0x1388)
    sts   ICR1L, r16           ; Set ICR1L ← 0x88 (5000 ticks → 20ms period)

    ; --- Center Servo to 90° (1.5ms pulse → 375 ticks = 0x0177) ---
    ldi   r16, 0x01            ; High byte of 375
    sts   OCR1AH, r16          ; OCR1AH ← 0x01r
    ldi   r16, 0x77            ; Low byte of 375
    sts   OCR1AL, r16          ; OCR1AL ← 0x77

    ; --- Initialize LEDs ON (no light detected yet) ---
    ldi   r16, LED1 | LED2     ; Mask for both LEDs
    out   PORTD, r16           ; Turn ON LED1 and LED2

loop:
    ; --- Read both LDR inputs at once ---
    in    r18, PINC            ; r18 ← PINC (PC1..PC0 bits)
    andi  r18, 0b00000011      ; Mask out bits 0 and 1 (LDR_SENSOR0|1)

    ; --- Case 1: both sensors detect light? ---
    cpi   r18, 0b00000011      ; Compare r18 to 0b11
    breq  both_detect          ; If equal, branch to both_detect

    ; --- Case 2: neither sensor detects light? ---
    cpi   r18, 0x00            ; Compare r18 to 0
    breq  none_detect          ; If zero (no bits set), branch to none_detect

    ; --- Case 3: exactly one sensor active; test right (LDR1) first ---
    andi  r18, LDR_SENSOR1     ; Mask PC1 bit only
    brne  ldr1_detect          ; If non-zero, right sensor triggered
    rjmp  ldr0_detect          ; Else, left sensor must be triggered

; —————————————————————————————————————
; LDR1 only (right) detected → move servo 90°→0°, LED1 OFF, LED2 ON
ldr1_detect:
    cbi   PORTD, 2            ; Clear PD2 → turn OFF LED1
    sbi   PORTD, 3            ; Set PD3 → turn ON LED2
    ; 0° pulse ~150 ticks (0x0096)
    ldi   r16, 0x00           ; High byte of 150 ticks
    sts   OCR1AH, r16         ; OCR1AH ← 0x00
    ldi   r16, 0x96           ; Low byte of 150
    sts   OCR1AL, r16         ; OCR1AL ← 0x96
    rjmp  loop                ; Return to main loop

; LDR0 only (left) detected → move servo 90°→180°, LED2 OFF, LED1 ON
ldr0_detect:
    cbi   PORTD, 3            ; Clear PD3 → turn OFF LED2
    sbi   PORTD, 2            ; Set PD2 → turn ON LED1
    ; 180° pulse ~600 ticks (0x0258)
    ldi   r16, 0x02           ; High byte of 600
    sts   OCR1AH, r16         ; OCR1AH ← 0x02
    ldi   r16, 0x58           ; Low byte of 600
    sts   OCR1AL, r16         ; OCR1AL ← 0x58
    rjmp  loop                ; Return to main loop

; Both sensors detect light → move servo to center (90°), both LEDs OFF
both_detect:
    cbi   PORTD, 2            ; Clear PD2 → LED1 OFF
    cbi   PORTD, 3            ; Clear PD3 → LED2 OFF
    ; 90° pulse =  375 ticks (0x0177)
    ldi   r16, 0x01           ; High byte of 375
    sts   OCR1AH, r16         ; OCR1AH ← 0x01
    ldi   r16, 0x77           ; Low byte of 375
    sts   OCR1AL, r16         ; OCR1AL ← 0x77
    rjmp  loop                ; Return to main loop

; Neither sensor detects light → LEDs ON, servo holds last position
none_detect:
    sbi   PORTD, 2            ; Set PD2 → LED1 ON
    sbi   PORTD, 3            ; Set PD3 → LED2 ON
    rjmp  loop                ; Return to main loop

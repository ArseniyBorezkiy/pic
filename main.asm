#include <p16f873a.inc>
    
; TODO INSERT CONFIG CODE HERE USING CONFIG BITS GENERATOR

timer_lh EQU 0x20
timer_ll EQU 0x21
timer_hh EQU 0x22
timer_hl EQU 0x23
digit_value EQU 0x24
digit_position EQU 0x25
time_over_flag EQU 0x26
delay_flag EQU 0x27
timer_scale EQU 0x28
timer_scale_original EQU 0x29
defuse_flag EQU 0x30
chance_over EQU 0x31
game_mode EQU 0x32
config_stage EQU 0x33		    ; 0 - time, 1 - code
no_timer EQU 0x34
 
RES_VECT CODE 0x0000		    ; processor reset vector
    GOTO START			    ; go to beginning of program

RES_INTERRUPTS CODE 0x0004
    GOTO ISR
    
MAIN_PROG CODE                      ; let linker place main program

START
    BCF STATUS,RP0 ; bank 0
    BCF STATUS,RP1
    
    ; init variables
    MOVLW 0
    MOVWF time_over_flag
    MOVWF defuse_flag
    MOVWF chance_over
    MOVWF game_mode
    MOVWF config_stage
    MOVWF no_timer
    MOVLW 10
    MOVWF timer_scale_original
    MOVF timer_scale_original,0
    MOVWF timer_scale
    
    ; initialization
    BSF STATUS,RP0 ; bank 1
    
    BCF OPTION_REG,T0CS ; select internal timer
    BCF OPTION_REG,PSA ; pick timer0 prescaler
    BSF OPTION_REG,PS0 ; set 1:256 prescale
    BSF OPTION_REG,PS1 ; set 1:256 prescale
    BSF OPTION_REG,PS2 ; set 1:256 prescale
    BCF INTCON,T0IF ; reset timer0 overflow flag
    BSF INTCON,T0IE ; enable timer0    
    BSF INTCON,GIE ; enable unmaskable interrupts   

    CLRF TRISA
    CLRF TRISB
    CLRF TRISC
    
    BSF TRISA,RA2
    BSF TRISA,RA3
    BSF TRISC,RC4
    BSF TRISC,RC5
    BSF TRISC,RC6
    BSF TRISC,RC7
    BSF ADCON1,PCFG1 ; set A channels as digital inputs
    BSF ADCON1,PCFG2

    BCF STATUS,RP0 ; bank 0
    
    CLRF PORTA
    CLRF PORTB
    CLRF PORTC

    f_main_loop
	CLRWDT
	; display
	CALL f_draw_digits
	; check mode
	MOVF game_mode,1
	BTFSC STATUS,Z
	GOTO f_config_loop
	; user interactions
	MOVF chance_over,1
	BTFSC STATUS,Z
	CALL f_user_interactions
	; check game over
	MOVF time_over_flag,1
	BTFSS STATUS,Z
	GOTO f_main_loop_game_over
	; check win
	MOVF defuse_flag,1
	BTFSS STATUS,Z
	GOTO f_main_loop_defused
	; user code input
	CALL f_user_code_input
	
	GOTO f_main_loop
    
    f_main_loop_defused
	; defuse output actions
	BSF PORTA,RA1
	GOTO f_main_loop
	
    f_main_loop_game_over
	BCF STATUS,RP0 ; bank 0
	; reset time
	BCF INTCON,GIE
	MOVLW 0
	MOVWF timer_hh
	MOVWF timer_hl
	MOVWF timer_lh
	MOVWF timer_ll
	BSF INTCON,GIE
	; game over output actions
	BSF PORTA,RA0
	GOTO f_main_loop
	
    f_config_loop
	; check no timer
	MOVLW 1
	BTFSC PORTA,RA3
	MOVWF no_timer
	; time stage
	MOVF config_stage,1
	BTFSC STATUS,Z
        CALL f_user_time_input
	; code stage
	DECF config_stage,0
	BTFSC STATUS,Z
	CALL f_user_init_code_input
	
	GOTO f_main_loop

;
; Function
;
f_user_interactions
    BCF STATUS,RP0 ; bank 0
    ; game over pin
    BTFSC PORTC,RC4
    GOTO f_user_interactions_game_over
    ; high speed pins
    BTFSC PORTA,RA2
    GOTO f_user_interactions_high_speed
    BTFSC PORTC,RC6
    GOTO f_user_interactions_high_speed
    ; low speed pin
    BTFSC PORTC,RC5
    GOTO f_user_interactions_low_speed
    ; defuse
    BTFSC PORTC,RC7
    GOTO f_user_interactions_defused
    
    ; no interactions
    RETURN
    
    f_user_interactions_chance_over
	MOVLW 1
	MOVWF chance_over
	MOVLW 0
	MOVWF no_timer
	RETURN

    f_user_interactions_game_over
	MOVLW 1
	MOVWF time_over_flag
	GOTO f_user_interactions_chance_over
    
    f_user_interactions_low_speed
	MOVLW 5
	MOVWF timer_scale_original
	GOTO f_user_interactions_chance_over

    f_user_interactions_high_speed
	MOVLW 1
	MOVWF timer_scale_original
	GOTO f_user_interactions_chance_over
	
    f_user_interactions_defused
	MOVLW 1
	MOVWF defuse_flag
	GOTO f_user_interactions_chance_over
	
;
; Function
;
f_user_init_code_input
    ; next stage
    INCF config_stage,1
    ; activate game
    MOVLW 1
    MOVWF game_mode
    
    RETURN
    
;
; Function
;
f_user_code_input

    RETURN

; Function
f_user_time_input
    ; set time
    MOVLW 5
    MOVWF timer_hl
    MOVLW 0
    MOVWF timer_hh
    MOVWF timer_lh
    MOVWF timer_ll
    
    ; next stage
    INCF config_stage,1
	
    RETURN
    
;
; Function
;
f_draw_digits
    f_draw_digits_high
	; timer_hh
	MOVLW 0x1
	MOVWF digit_position
	MOVF timer_hh,0
	MOVWF digit_value
	CALL f_draw_digit
	; timer_hl
	MOVLW 0x2
	MOVWF digit_position
	MOVF timer_hl,0
	MOVWF digit_value
	CALL f_draw_digit
    
        ; check game mode
	MOVF game_mode,1
	BTFSS STATUS,Z
	GOTO f_draw_digits_separator
	
	; check time stage
	MOVF config_stage,1
	BTFSC STATUS,Z
	GOTO f_draw_digits_separator
	
	GOTO f_draw_digits_low
	
    f_draw_digits_separator
	; ':'
	BCF STATUS,RP0 ; bank 0
	BSF PORTC,RC0
	BSF PORTC,RC1
	BSF PORTC,RC2
	BSF PORTC,RC3
	MOVLW 0x2
	XORWF PORTC,1
	BSF PORTB,RB7
    
    f_draw_digits_low
	; timer_l
	MOVLW 0x4
	MOVWF digit_position
	MOVF timer_lh,0
	MOVWF digit_value
	CALL f_draw_digit
	; timer_l
	MOVLW 0x8
	MOVWF digit_position
	MOVF timer_ll,0
	MOVWF digit_value
	CALL f_draw_digit
    
    RETURN
    
;
; Function
;
f_delay
    MOVLW 0
    MOVWF delay_flag

    delay
	MOVF delay_flag,1
	BTFSC STATUS,Z
	GOTO delay
	
    RETURN
    
;
; Function (digit_value, digit_position)
; 0 = 0000 ABCDEF
; 1 = 0001  BC
; 2 = 0010 AB DE G 
; 3 = 0011 ABCD  G
; 4 = 0100  BC  FG
; 5 = 0101 A CD FG
; 6 = 0110 A CDEFG
; 7 = 0111 ABC
; 8 = 1000 ABCDEFG
; 9 = 1001 ABCD FG
; A = R0, B = R1, C = R2, D = R3, E = R4, F = R5, G = R6
;
f_draw_digit
    CLRWDT
    BCF STATUS,RP0 ; bank 0
    
    ; prepare to draw
    CLRF PORTB
    
    ; select position
    BSF PORTC,RC0
    BSF PORTC,RC1
    BSF PORTC,RC2
    BSF PORTC,RC3
    MOVF digit_position,0
    XORWF PORTC,1
    
    ; draw
    CLRW
    ADDWF digit_value,0
    BTFSS STATUS,Z
    GOTO f_draw_digit_A
    
    f_draw_digit_zero
	BSF PORTB,RB0
	BSF PORTB,RB1
	BSF PORTB,RB2
	BSF PORTB,RB3
	BSF PORTB,RB4
	BSF PORTB,RB5
	GOTO f_draw_digit_end
    
    f_draw_digit_positive
    f_draw_digit_A
	MOVLW 1
	XORWF digit_value,0
	BTFSC STATUS,Z
	GOTO f_draw_digit_B
	MOVLW 4
	XORWF digit_value,0
	BTFSC STATUS,Z
	GOTO f_draw_digit_B

    BSF PORTB,RB0

    f_draw_digit_B
	MOVLW 5
	XORWF digit_value,0
	BTFSC STATUS,Z
	GOTO f_draw_digit_C
	MOVLW 6
	XORWF digit_value,0
	BTFSC STATUS,Z
	GOTO f_draw_digit_C

    BSF PORTB,RB1

    f_draw_digit_C
	MOVLW 2
	XORWF digit_value,0
	BTFSC STATUS,Z
	GOTO f_draw_digit_D

    BSF PORTB,RB2

    f_draw_digit_D
	MOVLW 1
	XORWF digit_value,0
	BTFSC STATUS,Z
	GOTO f_draw_digit_E
	MOVLW 4
	XORWF digit_value,0
	BTFSC STATUS,Z
	GOTO f_draw_digit_E
	MOVLW 7
	XORWF digit_value,0
	BTFSC STATUS,Z
	GOTO f_draw_digit_E

    BSF PORTB,RB3

    f_draw_digit_E
	MOVLW 1
	XORWF digit_value,0
	BTFSC STATUS,Z
	GOTO f_draw_digit_F
	MOVLW 3
	XORWF digit_value,0
	BTFSC STATUS,Z
	GOTO f_draw_digit_F
	MOVLW 4
	XORWF digit_value,0
	BTFSC STATUS,Z
	GOTO f_draw_digit_F
	MOVLW 5
	XORWF digit_value,0
	BTFSC STATUS,Z
	GOTO f_draw_digit_F
	MOVLW 7
	XORWF digit_value,0
	BTFSC STATUS,Z
	GOTO f_draw_digit_F
	MOVLW 9
	XORWF digit_value,0
	BTFSC STATUS,Z
	GOTO f_draw_digit_F

    BSF PORTB,RB4

    f_draw_digit_F
	MOVLW 1
	XORWF digit_value,0
	BTFSC STATUS,Z
	GOTO f_draw_digit_G
	MOVLW 2
	XORWF digit_value,0
	BTFSC STATUS,Z
	GOTO f_draw_digit_G
	MOVLW 3
	XORWF digit_value,0
	BTFSC STATUS,Z
	GOTO f_draw_digit_G
	MOVLW 7
	XORWF digit_value,0
	BTFSC STATUS,Z
	GOTO f_draw_digit_G

    BSF PORTB,RB5
    
    f_draw_digit_G
	MOVLW 0
	XORWF digit_value,0
	BTFSC STATUS,Z
	GOTO f_draw_digit_end
	MOVLW 1
	XORWF digit_value,0
	BTFSC STATUS,Z
	GOTO f_draw_digit_end
	MOVLW 7
	XORWF digit_value,0
	BTFSC STATUS,Z
	GOTO f_draw_digit_end

    BSF PORTB,RB6
    
    f_draw_digit_end

    RETURN

;
; Interrupt
;
ISR
    ; process only timer interrupts
    BTFSS INTCON,T0IF
    GOTO end_interrupt
    
    timer0_interruput
	; normalize delay
	MOVLW 1
	MOVWF delay_flag
	
	; normalize clock frequency
	BCF INTCON,T0IF
	DECFSZ timer_scale,1
	GOTO end_interrupt

	MOVF timer_scale_original,0
	MOVWF timer_scale

	; if scenario is over or no timer - skip clock's ticks
	MOVF defuse_flag,1
	BTFSS STATUS,Z
	GOTO end_interrupt
	
	MOVF time_over_flag,1
	BTFSS STATUS,Z
	GOTO end_interrupt

	MOVF no_timer,1
	BTFSS STATUS,Z
	GOTO end_interrupt
	
	; clock's tick
	isr_ll
	    MOVF timer_ll,1
	    BTFSC STATUS,Z
	    GOTO isr_lh
	    DECF timer_ll,1
	    GOTO end_interrupt

	isr_lh
	    MOVF timer_lh,1
	    BTFSC STATUS,Z
	    GOTO isr_hl
	    DECF timer_lh,1
	    MOVLW 9
	    MOVWF timer_ll
	    GOTO end_interrupt

	isr_hl
	    MOVF timer_hl,1
	    BTFSC STATUS,Z
	    GOTO isr_hh
	    DECF timer_hl,1
	    MOVLW 9
	    MOVWF timer_ll
	    MOVLW 5
	    MOVWF timer_lh
	    GOTO end_interrupt
	    
	isr_hh
	    MOVF timer_hh,1
	    BTFSC STATUS,Z
	    GOTO time_over
	    DECF timer_hh,1
	    MOVLW 9
	    MOVWF timer_ll
	    MOVWF timer_hl
	    MOVLW 5
	    MOVWF timer_lh
	    GOTO end_interrupt

	time_over
	    MOVLW 1
	    MOVWF time_over_flag

    end_interrupt
	RETFIE
	
END
    
    

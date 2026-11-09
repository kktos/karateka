;
; boot blocks 0-1
;
.segment BOOTLOADER	{ start: $0800, size: $00A0 }
.segment TINY_DOS	{ start: $D000, size: $0300 }

;
; KARATEKA: what $5300 (the loader's boot) did, the game loaded with tiny-dos
;
.segment INIT		{ start: $1000, size: 0 }

;
; GAME: the game at its start, before $5300 jumps to $0200
;  $0200-$07FF  T0 S2-S7, the RWTS loader at $0309-$03C7 replaced
;  $0800-$0FFF  T1B S0-S7
;  $6000-$9FFF  T1B S8 - T20
;
.segment GAME_LO	{ start: $0200, end: $0FFF }
.segment GAME_HI	{ start: $6000, end: $9FFF }

;
; TITLE ($0303): T04-T06, the title picture
;
.segment TITLE		{ start: $A000, end: $BFFF }

;
; chunk n ($0300 with A=n): T(4n+7)-T(4n+10)
;
.segment C0_LO		{ start: $1000, end: $1FFF }
.segment C0_HI		{ start: $A000, end: $BFFF }
.segment C1_LO		{ start: $1000, end: $1FFF }
.segment C1_HI		{ start: $A000, end: $BFFF }
.segment C2_LO		{ start: $1000, end: $1FFF }
.segment C2_HI		{ start: $A000, end: $BFFF }
.segment C3_LO		{ start: $1000, end: $1FFF }
.segment C3_HI		{ start: $A000, end: $BFFF }
.segment C4_LO		{ start: $1000, end: $1FFF }
.segment C4_HI		{ start: $A000, end: $BFFF }

;
; UPSIDE: side 2, the same game upside down, loaded instead when a key is held at boot
;  $0800-$09FF  T1B S0-S1: the hires row tables, reversed (over GAME's)
;  $A000-$BFFF  T04-T06: the title picture, flipped (instead of TITLE)
;
.segment UP_ROWS	{ start: $0800, end: $09FF }
.segment UP_TITLE	{ start: $A000, end: $BFFF }

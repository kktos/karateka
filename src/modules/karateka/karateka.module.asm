	.MODULE KARATEKA

	.segment INIT

;
; Run by the bootloader, LC bank 2 read/write (tiny-dos is there).
; Does what the original boot did: boot1 ($1000, T0 S1), then the loader's $5300 (T2),
; with the game loaded from the file GAME instead of T1B-T20.
;
Init:
	; boot1: clear HGR page 1, then its soft switches
	ldy #$00
	ldx #$20
	sty $3C
	stx $3D
	tya
:	sta ($3C),y
	iny
	bne :-
	inc $3D
	dex
	bne :-

	; HIRES, full screen, page 1, graphics; and on a //e: 80COL, ALTZP, RAMWRT, RAMRD, 80STORE off
	; (boot1 stores, A=0)
	ldx #$00
:	ldy bootSwitches,x
	sta sys::KBD,y
	beq :+
	inx
	bne :-
:
	; the game: $0200-$0FFF and $6000-$9FFF
	ldx #<gameLo
	ldy #>gameLo
	jsr tinyDOS::LoadFromFileAt
	ldx #<gameHi
	ldy #>gameHi
	jsr tinyDOS::LoadFromFileAt

	; a key held at boot: side 2's game, upside down. The latch catches a key pressed during the boot
	; (a held key repeats), the //e's any-key-down bit one pressed before; reading it clears the strobe.
	lda sys::KBD
	ora sys::KBDSTRB
	bpl :+
	ldx #<upsideRows
	ldy #>upsideRows
	jsr tinyDOS::LoadFromFileAt
	lda #<titleUpside
	sta titleFile
	lda #>titleUpside
	sta titleFile+1
:
	; $5300
	lda sys::ROMIN		; the ROM, as the original loader left it

	ldx #$FF
	txs
	inx
	txa
:	sta $00,x
	inx
	bne :-

	lda #$01
	sta $86
	sta $4F
	lda #$00
	sta $D0			; chunk 0
	lda #$FF
	sta $D2
	jmp $0200

bootSwitches:
	.db $5F, $57, $52, $54, $50, $0C, $08, $04, $02, $00

gameLo:	.db 0, GAME_LO_BLOCKS
	.dw $0200
	.pstr "GAME"
gameHi:	.db GAME_LO_BLOCKS, GAME_HI_BLOCKS
	.dw $6000
	.pstr "GAME"
upsideRows:
	.db 0, UP_ROWS_BLOCKS
	.dw $0800
	.pstr "UPSIDE"

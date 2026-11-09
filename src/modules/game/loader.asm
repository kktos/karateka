;
; In place of the RWTS loader, $0309-$03C7.
; The game calls it through
;  $0300: JMP $0309	chunk n: A=n (0-4), from $020C and from the chunks ($1118)
;  $0303: JMP $03C8	the title: $03C8 does LDA #$10 / JSR $0309, then shows it
;
; in:  A = chunk 0-4, or $10 = the title
; out: A=0 (Z=1: $020C loads again on Z=0), X=0, Y=0, the zero page unchanged
;      (the original swapped it with $4F00, and copied it back)
;

	.if * != $0309 {
		.error "The loader is at " + .hex(*) + ", not at $0309."
	}

LoadChunk:
	pha

	; tiny-dos: LC bank 2, read/write
	lda sys::LCBANK2
	lda sys::LCBANK2

	; tiny-dos uses $00-$06 and $42-$47, the SmartPort firmware maybe more
	ldx #$00
:	lda $00,x
	sta ZP_SAVE,x
	inx
	bne :-

	pla
	cmp #$10
	beq LoadTitle

	; "Cn": its blocks for $1000-$1FFF, then for $A000-$BFFF
	ora #$30
	sta chunkLo+6
	sta chunkHi+6
	ldx #<chunkLo
	ldy #>chunkLo
	jsr tinyDOS::LoadFromFileAt
	ldx #<chunkHi
	ldy #>chunkHi
	jsr tinyDOS::LoadFromFileAt
	bra Loaded

LoadTitle:
	ldx titleFile
	ldy titleFile+1
	jsr tinyDOS::LoadFromFileAt

Loaded:
	ldx #$00
:	lda ZP_SAVE,x
	sta $00,x
	inx
	bne :-

	lda sys::ROMIN

	lda #$00
	tay
	rts

chunkLo:
	.db 0, CHUNK_LO_BLOCKS
	.dw $1000
	.pstr "C0"
chunkHi:
	.db CHUNK_LO_BLOCKS, CHUNK_HI_BLOCKS
	.dw $A000
	.pstr "C0"

; the title to load: Init points it at titleUpside when a key is held at boot
titleFile:
	.dw titleNormal
titleNormal:
	.db 0, TITLE_BLOCKS
	.dw $A000
	.pstr "TITLE"
titleUpside:
	.db UP_ROWS_BLOCKS, TITLE_BLOCKS
	.dw $A000
	.pstr "UPSIDE"

	.if * > $03C8 {
		.error "The loader ends at " + .hex(*) + ": past $03C7, it overwrites $03C8."
	}
	.fill $03C8 - *, $00

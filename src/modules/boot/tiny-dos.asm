
	.include "../../includes/prodos.asm"

	.namespace tinyDOS scope="lc_bank2"

; directory / index block buffer, 2 pages: in LC bank 2 with tiny-dos, as the game uses all of $0800-$BFFF.
; The language card must be read/write enabled (LCBANK2 twice) when tiny-dos is called.
BUFFER 		= $DE00

namelen 	= $02
tmplen 		= $03
blockPage	= $04
blockStart	= $05
blockCount	= $06

SmartPortEntry:
	jmp $FFFF

LoadFile:
	jmp LoadFileEntry
LoadFromFile:
	jmp LoadFromFileEntry
RunFile:
	jmp RunFileEntry
LoadFromFileAt:
	jmp LoadFromFileAtEntry

;
; x/y points to
;  .pstr filename
;
LoadFileEntry:
	stz hasLoadAddr		; load at the file's aux type
	stz blockStart		; read from first file block
	stz blockCount		; read the 256 block, i.e all

	stx tmpPtr
	sty tmpPtr+1

internalLoadFile:
	; read
	lda #$01
	sta smartport::command

	; directory block $0002
	inc a
	sta smartport::bloklo
	stz smartport::blokhi

dirLoop:
	jsr initBuffer
        jsr SmartPortEntry

        jsr FindFile
        bcc :+		          ; C=1 if found

        jmp LoadFileBlocks

:
	; get next directory block
	lda BUFFER+2
	sta smartport::bloklo
	lda BUFFER+3
	sta smartport::blokhi

	lda smartport::bloklo
	ora smartport::blokhi
	bne dirLoop

	jmp ShowError

;
; x/y points to
;  .db block start
;  .db block count
;  .pstr filename
;
LoadFromFileEntry:
	stz hasLoadAddr		; load at the file's aux type
	stx tmpPtr
	sty tmpPtr+1

	lda (tmpPtr)
	sta blockStart
	inc tmpPtr

	lda (tmpPtr)
	sta blockCount
	inc tmpPtr
	bra internalLoadFile

;
; x/y points to
;  .db block start
;  .db block count
;  .dw load address, instead of the file's aux type
;  .pstr filename
;
LoadFromFileAtEntry:
	stx tmpPtr
	sty tmpPtr+1

	ldy #0
	lda (tmpPtr),y
	sta blockStart
	iny
	lda (tmpPtr),y
	sta blockCount
	iny
	lda (tmpPtr),y
	sta loadAddr
	iny
	lda (tmpPtr),y
	sta loadAddr+1

	lda #$80
	sta hasLoadAddr

	; tmpPtr -> filename
	clc
	lda tmpPtr
	adc #4
	sta tmpPtr
	bcc :+
	inc tmpPtr+1
:
	jmp internalLoadFile

initBuffer:
	lda #>BUFFER
	sta smartport::adrhi
	stz smartport::adrlo
	rts

;
; x/y points to
;  .pstr filename
;
RunFileEntry:
	jsr LoadFileEntry
	jmp (srcPtr)


FindFile:
	stz blockPage
        ldy #4                      ; first entry

NextEntry:
        lda (smartport::adrlo),y
        beq NotFound                ; unused entry
	cmp #$E0		    ; a volume or subdirectory header ($Fx, $Ex), not a file:
	bcs Next		    ; its name can be a file's, KARATEKA here

        jsr MatchName
        bcc Next                    ; C=0 → no match

	lda smartport::adrhi
	sta srcPtr+1

	tya
	clc
	adc smartport::adrlo
	sta srcPtr
	bcc :+
	inc srcPtr+1
:
        ; Starting block
	ldy #prodos::keyPtr
        lda (srcPtr),y
        sta smartport::bloklo
        iny
        lda (srcPtr),y
        sta smartport::blokhi

        ; Load address
	ldy #prodos::auxType
        lda (srcPtr),y
        sta tmpPtr
        iny
        lda (srcPtr),y
        sta tmpPtr+1

	; LoadFromFileAt: its load address instead
	bit hasLoadAddr
	bpl :+
	lda loadAddr
	sta tmpPtr
	lda loadAddr+1
	sta tmpPtr+1
:
        sec
        rts

Next:
        tya
        clc
        adc #$27
        tay
        bcc NextEntry

	lda blockPage
	bne NotFound 	; we should read the next dir block - TBD

	inc blockPage
	inc smartport::adrhi
        bra NextEntry

NotFound:
        clc
        rts

MatchName:
        and #$0F
        cmp (tmpPtr)
        bne NotFound

        phy
	sta namelen
        iny
	lda #$01
	sta tmplen

NameLoop:
        phy
        ldy tmplen
        lda (tmpPtr),y
        ply
        cmp (smartport::adrlo),y
        bne NoMatch

        iny
        inc tmplen
        lda tmplen
	cmp namelen	; <= namelen
        bcc NameLoop
        beq NameLoop

        ply
        rts

NoMatch:
        clc
        ply
        rts

LoadFileBlocks:
	jsr dbgAddMemRegion

	jsr initBuffer

	; read index block
        jsr SmartPortEntry

	lda tmpPtr
	sta smartport::adrlo
	sta srcPtr
	lda tmpPtr+1
	sta smartport::adrhi
	sta srcPtr+1

	lda #>BUFFER
	sta tmpPtr+1
	stz tmpPtr

	; =0 LoadFile
	; =xx LoadFromFile
	ldy blockStart
loop:
	dec blockCount

	lda (tmpPtr),y
	beq loaded

        sta smartport::bloklo
        jsr SmartPortEntry

	lda blockCount
	beq loaded

	inc smartport::adrhi
	inc smartport::adrhi
	iny
	bne loop
loaded:

	rts

ShowError:
	lda sys::PAGE2OFF
	lda sys::TEXTON

        ldy #$00
        lda (tmpPtr),y
	tay
	lda #$00
	sta ErrorMsgFile+1,y
:
        lda (tmpPtr),y
	sta ErrorMsgFile,y
	dey
	bne :-

        ldx #0
        ldy #5
:
        lda ErrorMsg,x
        beq Hang
	ora #$80
	sta LINE10,y
        inx
        iny
        bne :-
Hang:
        bra Hang

ErrorMsg:
        .text "UNABLE TO FIND "
ErrorMsgFile:
        .pstr "KARATEKA"
        .align 16, $A0
	.db 0

; LoadFromFileAt: bit 7 set = load at loadAddr
hasLoadAddr:	.db 0
loadAddr:	.dw 0

dbgAddMemRegion:

	lda tmpPtr
	sta start
	lda tmpPtr+1
	sta start+1

	lda blockCount 		; =0 LoadFile => size = EOF
	beq setSizeEOF

	asl
	sta size+1
	bra setFilename

        ; ; block size
	; ldy #prodos::blockSize
        ; lda (srcPtr),y
        ; sta size
        ; iny
        ; lda (srcPtr),y
        ; sta size+1

setSizeEOF:
        ; block size
	ldy #prodos::EOF
        lda (srcPtr),y
        sta size
        iny
        lda (srcPtr),y
        sta size+1

setFilename:
        ; filename
        lda srcPtr+1
        sta name+1
	clc
	lda #prodos::filename
        adc srcPtr
        sta name
	bcc :+
        inc name+1
:
	; addMemRegion(filename, addr, len, color)

	BRK
	.db $03
start:	.dw $0000
size:	.dw $0000
name:	.dw $0000
	.dw $0000

	rts
	.align $10
	.text "tiny_dos"
	.end namespace

	; .org $A00 - 5
	; .text "kktos"

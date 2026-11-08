	.cpu "65C02"

	.include "segments.asm"

	.include "includes/a2-firmware.asm"
	.include "includes/smartport.asm"

; LC bank 2, next to tiny-dos ($D000) and its buffer ($DE00): the game's zero page while tiny-dos runs
ZP_SAVE		= $DD00

; file layout, in 512-byte blocks: each segment of a file starts on a block
GAME_LO_BLOCKS	= ($1000 - $0200) / 512
GAME_HI_BLOCKS	= ($A000 - $6000) / 512
CHUNK_LO_BLOCKS	= ($2000 - $1000) / 512
CHUNK_HI_BLOCKS	= ($C000 - $A000) / 512

	.include "modules/boot/boot.module.asm"
	.include "modules/karateka/karateka.module.asm"
	.include "modules/game/game.module.asm"
	.include "modules/chunks/chunks.module.asm"

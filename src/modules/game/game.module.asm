	.MODULE GAME

	.segment GAME_LO
	.incbin "../../../bin/game_lo.0200-0308.bin"
	.include "loader.asm"
	.incbin "../../../bin/game_lo.03C8-0FFF.bin"

	.segment GAME_HI
	.incbin "../../../bin/game_hi.6000-9FFF.bin"

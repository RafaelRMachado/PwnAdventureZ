.include "defines.inc"

.define FOREST_TILES $80
.define BORDER_TILES $c0

.define FOREST_PALETTE 0
.define BORDER_PALETTE 1

.code

PROC gen_forest
	; Load forest tiles
	LOAD_ALL_TILES FOREST_TILES, forest_tiles

	; Load forest palette
	LOAD_PTR forest_palette
	jsr load_background_game_palette

	; Determine which kind of border (if there is one) needs to be generated
	jsr read_overworld_up
	and #$3f
	cmp #MAP_FOREST
	bne bordertypedone

	jsr read_overworld_down
	and #$3f
	cmp #MAP_FOREST
	bne bordertypedone

	jsr read_overworld_left
	and #$3f
	cmp #MAP_FOREST
	bne bordertypedone

	jsr read_overworld_right
	and #$3f

bordertypedone:
	sta border_type

	cmp #MAP_BOUNDARY
	beq rockborderset
	cmp #MAP_CAVE_INTERIOR
	beq caveborderset

	; Not a special border set, use trees to block
	lda #MAP_FOREST
	sta border_type
	jmp borderloaded

caveborderset:
	; There is a cave next to this area, but it might be inaccessible, check path
	jsr read_overworld_up
	and #$3f
	cmp #MAP_CAVE_INTERIOR
	bne topnotcave
	jsr can_travel_up
	beq rockborderset

topnotcave:
	; There is a cave but it is not accessible, use the normal solid rock border
	lda #MAP_BOUNDARY
	sta border_type

rockborderset:
	; There is a map boundary or cave next to this area, load the rock border tile set
	LOAD_ALL_TILES BORDER_TILES, forest_rock_border_tiles
	LOAD_PTR forest_rock_border_palette
	jsr load_game_palette_1
	jmp borderloaded

borderloaded:
	; Generate parameters for map generation
	jsr gen_map_opening_locations

	; Generate the surrounding trees, but avoid generating borders of different types
	lda border_type
	cmp #MAP_FOREST
	beq leftisforest
	jsr read_overworld_left
	and #$3f
	cmp #MAP_FOREST
	bne leftnotforest
leftisforest:
	lda #FOREST_TILES + FOREST_TREE
	jsr gen_left_wall_small

leftnotforest:
	lda border_type
	cmp #MAP_FOREST
	beq rightisforest
	jsr read_overworld_right
	and #$3f
	cmp #MAP_FOREST
	bne rightnotforest
rightisforest:
	lda #FOREST_TILES + FOREST_TREE
	jsr gen_right_wall_small

rightnotforest:
	lda border_type
	cmp #MAP_FOREST
	beq topisforest
	jsr read_overworld_up
	and #$3f
	cmp #MAP_FOREST
	bne topnotforest
topisforest:
	lda #FOREST_TILES + FOREST_TREE
	jsr gen_top_wall_small

topnotforest:
	lda border_type
	cmp #MAP_FOREST
	beq botisforest
	jsr read_overworld_down
	and #$3f
	cmp #MAP_FOREST
	bne botnotforest
botisforest:
	lda #FOREST_TILES + FOREST_TREE
	jsr gen_bot_wall_small

botnotforest:
	lda #FOREST_TILES + FOREST_GRASS
	jsr gen_walkable_path

	; Generate border for other types
	lda border_type
	cmp #MAP_BOUNDARY
	beq rock_boundary
	cmp #MAP_CAVE_INTERIOR
	beq cave_boundary
	jmp boundarydone

rock_boundary:
	jsr gen_forest_rock_boundary
	jmp boundarydone

cave_boundary:
	; Place the cave entrance tile while generating the rocks
	ldx top_opening_pos
	dex
	stx top_opening_pos
	jsr gen_forest_rock_boundary

	ldx top_opening_pos
	inx
	ldy top_wall_right_extent
	lda #BORDER_TILES + CAVE_INTERIOR + BORDER_PALETTE
	jsr write_gen_map

	jmp boundarydone

boundarydone:
	; Create clutter in the middle of the forest
	lda #8
	jsr genrange_cur
	clc
	adc #8
	sta clutter_count

clutterloop:
	lda clutter_count
	bne placeclutter
	jmp clutterend
placeclutter:

	lda #8
	sta arg5

cluttertry:
	; Generate clutter position
	lda #11
	jsr genrange_cur
	clc
	adc #2
	sta arg0

	lda #8
	jsr genrange_cur
	clc
	adc #2
	sta arg1

	; Check to ensure clutter isn't blocking anything.  It must be surrounded with the
	; same type of blank space (not critical path, or all critical path) to ensure that
	; it will not block all paths to exits
	ldx arg0
	dex
	ldy arg1
	dey
	jsr read_gen_map
	cmp #0
	beq clutterblank
	cmp #FOREST_TILES + FOREST_GRASS
	bne clutterblock
clutterblank:
	sta arg4

	inx
	jsr read_gen_map
	cmp arg4
	bne clutterblock

	inx
	jsr read_gen_map
	cmp arg4
	bne clutterblock

	ldx arg0
	dex
	ldy arg1
	jsr read_gen_map
	cmp arg4
	bne clutterblock

	ldx arg0
	inx
	jsr read_gen_map
	cmp arg4
	bne clutterblock

	ldx arg0
	dex
	ldy arg1
	iny
	jsr read_gen_map
	cmp arg4
	bne clutterblock

	inx
	jsr read_gen_map
	cmp arg4
	bne clutterblock

	inx
	jsr read_gen_map
	cmp arg4
	bne clutterblock

	; Clutter is not blocking any paths, place it now
	lda #FOREST_TILES + FOREST_TREE
	ldx arg0
	ldy arg1
	jsr write_gen_map
	jmp nextclutter

clutterblock:
	; Clutter was blocking, try again up to a max number of tries
	ldx arg5
	dex
	stx arg5
	beq nextclutter
	jmp cluttertry

nextclutter:
	ldx clutter_count
	dex
	stx clutter_count
	jmp clutterloop
clutterend:

	; Convert tiles that have not been generated into grass
	ldy #0
yloop:
	ldx #0
xloop:
	jsr read_gen_map
	cmp #0
	bne nextblank
	lda #FOREST_TILES + FOREST_GRASS
	jsr write_gen_map
nextblank:
	inx
	cpx #MAP_WIDTH
	bne xloop
	iny
	cpy #MAP_HEIGHT
	bne yloop

	rts
.endproc


PROC gen_forest_rock_boundary
	; Generate borders of rock type with the rock tile set
	jsr read_overworld_left
	and #$3f
	cmp #MAP_FOREST
	beq leftnotrock
	lda #BORDER_TILES + CAVE_WALL + BORDER_PALETTE
	jsr gen_left_wall_large

leftnotrock:
	jsr read_overworld_right
	and #$3f
	cmp #MAP_FOREST
	beq rightnotrock
	lda #BORDER_TILES + CAVE_WALL + BORDER_PALETTE
	jsr gen_right_wall_large

rightnotrock:
	jsr read_overworld_up
	and #$3f
	cmp #MAP_FOREST
	beq topnotrock

	lda border_type
	cmp #MAP_CAVE_INTERIOR
	bne rightnotcave
	lda #BORDER_TILES + CAVE_WALL + BORDER_PALETTE
	jsr gen_top_wall_always_thick
	jmp topnotrock
rightnotcave:
	lda #BORDER_TILES + CAVE_WALL + BORDER_PALETTE
	jsr gen_top_wall_large

topnotrock:
	jsr read_overworld_down
	and #$3f
	cmp #MAP_FOREST
	beq botnotrock
	lda #BORDER_TILES + CAVE_WALL + BORDER_PALETTE
	jsr gen_bot_wall_large

botnotrock:
	; Process the rock tiles to give them a contoured appearance
	lda #BORDER_TILES + BORDER_PALETTE
	jsr process_rock_sides

	rts
.endproc


.data
VAR forest_palette
	.byte $0f, $09, $19, $08
	.byte $0f, $09, $19, $08
	.byte $0f, $09, $19, $08
	.byte $0f, $09, $19, $08

VAR forest_rock_border_palette
	.byte $0f, $19, $07, $17


TILES forest_tiles, 2, "tiles/forest/forest.chr", 8
TILES forest_rock_border_tiles, 2, "tiles/forest/rock.chr", 60
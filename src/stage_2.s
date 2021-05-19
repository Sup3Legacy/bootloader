.section .boot, "awx"
.code16

# This stage sets the target operating mode, loads the kernel from disk,
# creates an e820 memory map, enters protected mode, and jumps to the
# third stage.

second_stage_start_str: .asciz "Booting (second stage)..."
kernel_load_failed_str: .asciz "Failed to load kernel from disk"

WHITE_TEXT = 0x0f
DARK_RED = 0x04
LIGHT_RED = 0x04

kernel_load_failed:
    lea si, [kernel_load_failed_str]
    call real_mode_println
kernel_load_failed_spin:
    jmp kernel_load_failed_spin

stage_2:
    lea si, [second_stage_start_str]
    call real_mode_println


    push edx
print_logo:
    mov edi, offset printing_list_data
print_logo_loop:
    mov al, [edi]
    mov [text_color], al
    mov esi, [edi + 1]
    cmp esi, 0
    je print_logo_end
    call real_mode_print_color
    add edi, 5
    jmp print_logo_loop
print_logo_end:
    mov al, WHITE_TEXT
    mov [text_color], al

wainting_keystruck:
    mov ah, 0x00
    int 0x16
    cmp al, 0x20
    jne wainting_keystruck

    pop edx

set_target_operating_mode:
    # Some BIOSs assume the processor will only operate in Legacy Mode. We change the Target
    # Operating Mode to "Long Mode Target Only", so the firmware expects each CPU to enter Long Mode
    # once and then stay in it. This allows the firmware to enable mode-specifc optimizations.
    # We save the flags, because CF is set if the callback is not supported (in which case, this is
    # a NOP)
    pushf
    mov ax, 0xec00
    mov bl, 0x2
    int 0x15
    popf

load_kernel_from_disk:
    # start of memory buffer
    lea eax, _kernel_buffer
    mov [dap_buffer_addr], ax

    # number of disk blocks to load
    mov word ptr [dap_blocks], 1

    # number of start block
    mov eax, offset _kernel_start_addr
    lea ebx, _start
    sub eax, ebx
    shr eax, 9 # divide by 512 (block size)
    mov [dap_start_lba], eax

    # destination address
    mov edi, 0x400000

    # block count
    mov ecx, offset _kernel_size
    add ecx, 511 # align up
    shr ecx, 9

load_next_kernel_block_from_disk:
    # load block from disk
    lea si, dap
    mov ah, 0x42
    int 0x13
    jc kernel_load_failed

    # copy block to 2MiB
    push ecx
    push esi
    mov ecx, 512 / 4
    # move with zero extension
    # because we are moving a word ptr
    # to esi, a 32-bit register.
    movzx esi, word ptr [dap_buffer_addr]
    # move from esi to edi ecx times.
    rep movsd [edi], [esi]
    pop esi
    pop ecx

    # next block
    mov eax, [dap_start_lba]
    add eax, 1
    mov [dap_start_lba], eax

    sub ecx, 1
    jnz load_next_kernel_block_from_disk

create_memory_map:
    lea di, es:[_memory_map]
    call do_e820

video_mode_config:
    call config_video_mode

enter_protected_mode_again:
    cli
    lgdt [gdt32info]
    mov eax, cr0
    or al, 1    # set protected mode bit
    mov cr0, eax

    push 0x8
    lea eax, [stage_3]
    push eax
    retf

spin32:
    jmp spin32

text_color:
    .byte 0x07

real_mode_print_color:
    cld
real_mode_print_loop_color:
    lodsb al, BYTE PTR [si] # load value in al then increment si
    test al, al
    jz real_mode_print_done
    cmp al, 10
    je is_new_line
    call real_mode_print_char_color
    jmp real_mode_print_loop_color
is_new_line:
    call real_mode_print_char
    jmp real_mode_print_loop_color

real_mode_print_char_color:
    mov cx, 1
    mov bh, 0
    mov bl, [text_color]
    mov ah, 0x09
    int 0x10
    mov ah, 3
    int 0x10
    add dl, 1
    cmp dl, 80
    je line_full
    mov ah, 2
    int 0x10
    ret
line_full:
    mov dl, 0
    add dh, 1
    cmp dh, 25
    je screen_full
    mov ah, 2
    int 0x10
    ret
screen_full:
    mov ah, 0x6
    mov al, 01
    mov bh, 0x00
    mov cx, 0x0000
    mov dx, 0x194f
    int 0x10
    mov ah, 2
    mov dx, 0x1800
    int 0x10
    mov cx, 80
    mov bh, 0
    mov bl, 0x0f
    mov ah, 0x09
    mov al, 0
    int 0x10
    ret

logo_line_01: .string "                               /+/.  `/ss:`  ./+:                               "
logo_line_02: .string "                       `syo/:-oyyyysosyyyys+syyyy+-:+oys`                       "
logo_line_03: .string "                 /so+/:oyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyy+:/+os:                 "
logo_line_04: .string "           ./::-.+yyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyy+.-:::`           "
logo_line_05: .string "           `syyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyys`           "
logo_line_06: .string "      `+++++syyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyys+++++`      "
logo_line_07: .string "      `-syyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyys-       "
logo_line_08: .string "   :+ooosyyyyyyyyyyyyyyyyyyyysosyhhyyyyyyyyyyysooyhhyyyyyyyyyyyyyyyyyyysooo+-   "
logo_line_09: .string "   `:syyyyyyyyyyyyyyyyyyyyyyy`"
logo_line_09_c: .string " +MMMNhyyyyyyym."
logo_line_09_e: .string " :MMNdyyyyyyyyyyyyyyyyyyyys:`   "
logo_line_10: .string " -/osyyyyyyyyyyyyyyyyyyyyyyhNhssmMMMMmyyyyyydMdsymMMMMyyyyyyyyyyyyyyyyyyyyyso+- "
logo_line_11: .string ":syyyyyyyyyyyyyyyyyyyyyyyyyyhmNNNNNNmyyyyyyyydmNNNNNmhyyyyyyyyyyyyyyyyyyyyyyyyy-"
logo_line_12_a: .string ".oyyyyyyyy"
logo_line_12_b: .string "hdhhh"
logo_line_12_c: .string "yyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyy"
logo_line_12_d: .string "shdddd"
logo_line_12_e: .string "yyyyyyyo`"
logo_line_13_a: .string " `:osyyyyyo/"
logo_line_13_b: .string "shdhss"
logo_line_13_c: .string "yyyysoosyhyyyyyyyyssssssssssyyyyyyyhysoooyyyyo-"
logo_line_13_d: .string "/ddhs"
logo_line_13_e: .string "yyyyyyo:` "
logo_line_14: .string "    ./oyyyy+`./so.:+osssossyyyyyyyyys+:.```-+ssyyyyyyysssssso/-`.so:`-syyyo:`   "
logo_line_15: .string "      `./osy+   `   ``:yyyyyyyyyyyyyyyso` +syyyyyyyyyyyyyys`     `   oys+-`     "
logo_line_16_a: .string "          `:/.         :oyyyyy"
logo_line_16_b: .string "s////+++:."
logo_line_16_c: .string "` --"
logo_line_16_d: .string ":o+++"
logo_line_16_e: .string "o+syyyys+.          +:.        "
logo_line_17_a: .string "                         .:shsoss/-"
logo_line_17_d: .string "``:dh-  .Ny`"
logo_line_17_e: .string "./soo+/:.`                       "
logo_line_18: .string "                          .MM.        /MN   :osyys/.                            "
logo_line_19: .string "                           hMs`       yN+  `    `-NN`                           "
logo_line_20: .string "                            .+o+/:::/+/`   :s+:::+s:                            "
logo_line_21: .string "                                                                                "
logo_line_22: .string "                                                                                "
logo_line_23: .string "                          Ready to launch Ferr-OS ?                             "
logo_line_24: .string "                                                                                "
logo_line_25: .string " PRESS SPACE TO LAUNCH >"
blanck: .string "*"

printing_list_data:
    .byte LIGHT_RED
    .long logo_line_01
    .byte LIGHT_RED
    .long logo_line_02
    .byte LIGHT_RED
    .long logo_line_03
    .byte LIGHT_RED
    .long logo_line_04
    .byte LIGHT_RED
    .long logo_line_05
    .byte LIGHT_RED
    .long logo_line_06
    .byte LIGHT_RED
    .long logo_line_07
    .byte LIGHT_RED
    .long logo_line_08
    .byte LIGHT_RED
    .long logo_line_09
    .byte WHITE_TEXT
    .long blanck
    .byte LIGHT_RED
    .long logo_line_09_c
    .byte WHITE_TEXT
    .long blanck
    .byte LIGHT_RED
    .long logo_line_09_e
    .byte LIGHT_RED
    .long logo_line_10
    .byte LIGHT_RED
    .long logo_line_11

    .byte LIGHT_RED
    .long logo_line_12_a
    .byte DARK_RED
    .long logo_line_12_b
    .byte LIGHT_RED
    .long logo_line_12_c
    .byte DARK_RED
    .long logo_line_12_d
    .byte LIGHT_RED
    .long logo_line_12_e

    .byte LIGHT_RED
    .long logo_line_13_a
    .byte DARK_RED
    .long logo_line_13_b
    .byte LIGHT_RED
    .long logo_line_13_c
    .byte DARK_RED
    .long logo_line_13_d
    .byte LIGHT_RED
    .long logo_line_13_e

    .byte LIGHT_RED
    .long logo_line_14
    .byte LIGHT_RED
    .long logo_line_15

    .byte LIGHT_RED
    .long logo_line_16_a
    .byte WHITE_TEXT
    .long logo_line_16_b
    .byte LIGHT_RED
    .long logo_line_16_c
    .byte WHITE_TEXT
    .long logo_line_16_d
    .byte LIGHT_RED
    .long logo_line_16_e

    .byte LIGHT_RED
    .long logo_line_17_a
    /*.byte WHITE_TEXT
    .long logo_line_17_b
    .byte LIGHT_RED
    .long logo_line_17_c*/
    .byte WHITE_TEXT
    .long logo_line_17_d
    .byte LIGHT_RED
    .long logo_line_17_e

    .byte WHITE_TEXT
    .long logo_line_18
    .byte WHITE_TEXT
    .long logo_line_19
    .byte WHITE_TEXT
    .long logo_line_20
    .byte WHITE_TEXT
    .long logo_line_21
    .byte WHITE_TEXT
    .long logo_line_22
    .byte WHITE_TEXT
    .long logo_line_23
    .byte WHITE_TEXT
    .long logo_line_24
    .byte WHITE_TEXT
    .long logo_line_25
printing_list_end:
    .byte 0
    .double 0

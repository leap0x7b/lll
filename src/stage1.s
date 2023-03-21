section .stage1

global _start
extern stage2_begin
extern stage2_sector_size
extern stack_end
extern main

bits 16
_start:
    jmp short entry
    nop

bpb:
    .oem_name db 'lll0.1.0'
    .bytes_per_sector dw 512
    .sectors_per_cluster db 1
    .reserved_sectors dw 32
    .fat_count db 2
    .root_dir_entries dw 0
    .sector_count dw 0
    .media_descriptor db 0xf8
    .sectors_per_fat dw 9
    .sectors_per_track dw 18
    .head_count dw 2
    .hidden_sectors dd 0
    .large_sector_count dd 0
    ; FAT32 extended BPB
    .sectors_per_fat32 dd 0
    .flags dw 0
    .fat_version_number dw 0
    .root_dir_cluster dd 2
    .fsinfo_sector dw 0
    .backup_boot_sector dw 0
    .reserved0 times 12 db 0
    ; FAT12/16 extended BPB
    .drive_number db 0x80
    .reserved1 db 0
    .boot_signature db 0x29
    .serial_number dd 0
    .volume_label db 'lll v0.1.0 '
    .file_system db 'FAT32   '

entry:
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7c00

    mov al, 'L'
    mov ah, 0x0e
    int 0x10

    call load_stage2
    call protected_mode_switch

    jmp $

print:
    pusha

.loop:
    mov al, [bx]
    cmp al, 0
    je .done

    mov ah, 0x0e
    int 0x10

    add bx, 1
    jmp .loop

.done:
    popa
    ret

print_hex:
    pusha
    mov cx, 4

.loop:
    dec cx

    mov ax, dx
    shr dx, 4
    and ax, 0x0f

    mov bx, HEX_OUT
    add bx, cx

    cmp ax, 0x0a
    jl .step2

    add al, 7
    jl .step2

.step2:
    add al, 0x30
    mov byte [bx], al

    cmp cx, 0
    je .done

    jmp .loop

.done:
    mov bx, HEX_OUT
    call print

    popa
    ret

HEX_OUT db "0000", 0

error:
    mov dh, ah
    mov al, '!'
    mov ah, 0x0e
    int 0x10

    call print_hex
    jmp .hcf

.hcf:
    xor ah, ah
    int 16h
    jmp 0xffff:0

load_stage2:
    mov bx, stage2_begin
    mov dh, stage2_sector_size
    call disk_load
    ret

disk_load:
    pusha
    push dx

    mov ah, 2
    mov al, dh
    mov cl, 2
    xor ch, ch
    xor dh, dh

    int 0x13
    jc error

    pop dx
    cmp al, dh
    jne error

    popa
    ret

gdt:
    dq 0

.code16:
    dw 0xffff
    dw 0
    db 0
    db 10011010b
    db 1
    db 0

.data16:
    dw 0xffff
    dw 0
    db 0
    db 10010010b
    db 1
    db 0

.code32:
    dw 0xffff
    dw 0
    db 0
    db 10011010b
    db 11001111b
    db 0

.data32:
    dw 0xffff
    dw 0
    db 0
    db 10010010b
    db 11001111b
    db 0

.end:

.descriptor:
    dw (.end - gdt) - 1
    dd gdt

protected_mode_switch:
    lgdt [gdt.descriptor]
    cli

    mov eax, cr0
    bts ax, 0
    mov cr0, eax

    jmp 0x18:.init

bits 32
.init:
    mov eax, 0x20
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax
    mov esp, stack_end

    jmp main
    call .halt

.halt:
    hlt
    jmp $

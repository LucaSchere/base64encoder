; executable name : base64encoder
; author          : Luca Scherer
; description     : binary to base64 encoder
;
; build using these commands:
;   make
; run it this way:
;   ./base64encoder    # type input characters, end by Ctrl-d
; or
;   ./base64encoder < (input file)
;
; some explanations:
; - read byte by byte
; - extract 6bit-chunks and map to Base64Table
; - append with '=' if amount of input bytes is not a multiple of 3 bytes
;
; important registers:
; r12: stores read bytes
; r14: number of '=' to append
; r15: represents mask to extract 6bit-chunks
; cl:  amount of bits between 6bit-chunk and end of r12 (used for shifting)

SECTION .data
    Base64Table: db "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
    ToFewBytesSuffix: db "=="

SECTION .bss
    IOBufLen: equ 1
    InBuf: resb IOBufLen

SECTION .text

global _start

_start:

xor r12, r12                    ; reset r12
xor r14, r14                    ; reset r14
mov cl, 2                       ; 2 bits will follow the first 6bit-chunk in the first byte

encode:                         ; loop for each 6bit-chunk
    mov r15, 03Fh               ; default mask 0011 1111
    cmp cl, 8                   ; if cl >=8 3 bytes were processed
    jae afterEvery3Bytes

    shl r15, cl                 ; shift mask by cl (only possible with cl register)

    mov rax, 0
    mov rdi, 0
    mov rsi, InBuf
    mov rdx, IOBufLen
    push cx
    syscall                     ; read 1 byte from stdin, restore cx over stack, cl = last 8bits of cx
    pop cx

    cmp rax, 0                  ; if no more bytes to read
    je noMoreBytes

    shl r12, 8                  ; open 1 byte gap at the end of r12
    add r12, [InBuf]            ; read next byte to r12
    jmp write                   ; proceed to write (noMoreBytes and afterEvery3Bytes are not needed in default case)

    noMoreBytes:
    cmp cl, 2                   ; if cl is 2 a complete 3-byte-pack was processed before
    je exit                     ; and since there aro no more bytes to process we finish

    cmp cl, 5                   ; cl = 2 => first byte, cl = 4 => second byte, cl = 6 => third byte, cl = 8 is not possible here because afterEvery3Bytes
    ja second2BitShift          ; if only 1 byte is missing jump to second bit shift else do it twice
    shl r12, 2
    inc r14
    second2BitShift:
    shl r12, 2                  ; append r12 with 2 zeros
    inc r14                     ; increment '=' counter

    mov r15, 03Fh               ; set mask to 0011 1111 (last 6bits)
    mov cl, 0                   ; reset cl because no gap between end of r12 and 6bit-chunk
    jmp write                   ; write last Base64Character

    afterEvery3Bytes:
    mov cl, 0                   ; after every 3 bytes cl = 0

    write:
    mov r13, r12                ; copy r12 to r13
    and r13, r15                ; apply mask
    shr r13, cl                 ; shift 6bit-chunk to end of register

    mov rax, 1
    mov rdi, 1
    mov rsi, Base64Table
    add rsi, r13
    mov rdx, IOBufLen
    push cx
    syscall                     ; write Base64Character and restore cx over stack
    pop cx

    add cl, 2                   ; increment gap to end of r12 by two
    jmp encode                  ; next iteration

exit:
    mov rax, 1
    mov rdi, 1
    mov rsi, ToFewBytesSuffix
    mov rdx, r14
    syscall                     ; append Suffix depending on r14

    mov rax, 60
    mov rdi, 0
    syscall
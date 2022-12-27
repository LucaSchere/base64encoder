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
; - read input to memory
; - process input in 3-byte chunks
; - output 4 characters (6bit) for each 3-byte chunk
; - append with '=' if amount of input bytes is not a multiple of 3 bytes
;
; important registers:
; r12: address of currently processed byte
; r13: mask for currently processed 3-byte chunk
; r14: amount of 6-bit chunks in processed 3-byte chunk
; r15: actual amount of input bytes


SECTION .data

    ; char mapping table
    ; suffix char is used if amount of read bytes % 3 != 0

    Base64Table: db "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/",10
    ToFewBytesSuf: db "=",0

SECTION .bss
    Text: resb 16384                     ; reserve bytes 16384

SECTION .text

global _start

_start:
    mov rdi, 0                          ; default input
    mov rax, 0                          ; sys_read
    mov rsi, Text                       ; text into allocated memory
    mov rdx, 16384                      ; 16384 bytes length
    syscall

    mov r15, rax                        ; actual bytes read
    mov r12, Text                       ; r12 stores current addressed byte of read text

    cmp r15, 0                          ; compare r15 with 0
    je end                              ; jump to end if r15 equals 0

process3Bytes:
    mov r10, 3                          ; r10 as byte counter (decrementing)
    mov r8, 0                           ; set r8 to zero
    mov r14, 4                          ; 3bytes have 6bit-packs    ;  r14 equals amount of 6bit-packs in r8
    mov r13, 03F000000h                 ; mask for the first 6bit of 3bytes (+8bit because of shl r9, 8)

    ; in each iteration r8 get appended with 1 byte
    ; after the loop r8 contains the 3bytes (except if amount of read bytes was not a multiple of 3)
    extract1ByteLoop:

      ; check if byte-chunk is complete (3bytes)
      mov rdi, r15                      ; take actual bytes read
      add rdi, Text                     ; add base address of Text (= highest address of Text)
      sub rdi, r12                      ; sets zero-flag if all bytes were extracted from memory (only possible if r15 % 3 !== null)
      jnz moreBytesToExtract            ; jump if not all bytes extracted yet
      call handleToFewBytes             ; subroutine to handle case: r15 % 3 != 0
      jmp mapBytesToBase64Table         ; skip next part because there are no more bytes to read
      moreBytesToExtract:

      ; read bytes from memory to chunk
      movzx r9, byte [r12]              ; read 8bit from text to r9 (zero extending)
      shl r8, 8                         ; shift left current bits in r8 by 1 byte
      add r8, r9                        ; add r9 into 8 empty bits at the end of r8
      inc r12                           ; increment current address
      dec r10                           ; decrement byte counter
      jnz extract1ByteLoop              ; jump to loop start if less than 3 bytes extracted

    ; extract 6bit-packs from 3bytes (in r8) and map them to base64table
    mapBytesToBase64Table:

        ; each iteration processes 1 6bit-pack
        map6BitLoop:
          mov r9, r8                    ; copy of r8 in r9
          shl r9, 6                     ; after this r9 can be rightshifted 6 times r14
          and r9, r13                   ; apply mask

          mov rcx, r14                  ; copy bytecounter to rcx to use it in loop as iterator

          ; each iteration rightshifts the copy of our 3bytes by 6 bits
          ; for the first iteration of map6BitLoop  the copy would be rightshifted by 6*4 = 24 bits
          shift6Loop:                   ; loop to shift 6bit values to last 6bit in r9
            shr r9, 6                   ; shift right 6times
            dec rcx                     ; decrement  loop iterator
            jnz shift6Loop              ; jump to loop start if loop iterator is not 0

          shr r13, 6                    ; shift mask for next 6bit-pack

          ; write 6bit value to stdout
          mov rax, 1                    ; sys_write
          mov rdi, 1                    ; fd 1 = standard output
          mov rsi, Base64Table          ; Base64Table as output
          add rsi, r9                   ; r9 as Base64Table index (offset)
          mov rdx, 1                    ; 1 byte equals 1 character from Base64Table
          syscall

          dec r14                       ; decrement 6bit-pack counter
          jnz map6BitLoop               ; jump to loop start if byte counter is not 0

    ; if a complete 3byte chunk was processed
    ; and there are more bytes to process jump back to process3Bytes
    mov r9, Text                        ; base address of Text to r9
    add r9, r15                         ; add actual bytes read to r9 (= highest address to read from)
    sub r9, r12                         ; subtract highest possible address with current address
    jnz process3Bytes                   ; jump to next 3-bytes-processing if subtraction not zero

    ; if r10 > 10 the last 3byte-chunk was no complete
    ; and the output has to be appended with '=' * the amount of missing bytes to the next 3byte-chunk
    printToFewByteSuffix:
      dec r10                           ; r10 still contains amount of missing bytes (+1)
      jz end                            ; jump out of loop if printed for all missing bytes
      js end                            ; jump if sing-flag set (happens when r15 % 3 = 0 because r10 was already 0)
      mov rax, 1                        ; sys_write
      mov rdi, 1                        ; fd 1 = standard out
      mov rsi, ToFewBytesSuf            ; ToFewBytesSuffix as output
      mov rdx, 1                        ; 1 byte
      syscall
      jmp printToFewByteSuffix          ; start over

end:
    mov rax, 60                         ; sys_exit
    mov rdi, 0                          ; exit code
    syscall

; only called if amount of actual input bytes is not a multiple of 3
; fill the next 6bit-pack of r8 with 0
handleToFewBytes:
  mov r9, r10                           ; copy missing bytes from r10 to r9 (because r10 is used later)
  add r10, 1                            ; add 1 for later for-loop in printToFewByteSuffix
  sub r14, r9                           ; subtract missing bytes from 6bit-pack amount
                                        ; if 1 byte missing: 3 6bit-packs in r8 (r10 = 1)
                                        ; if 2 bytes missing: 2 6bit-packs in r8 (r10 = 2)
  appendZeroToTextLoop:
    shl r8, 2                           ; append zeros to read bytes
    shr r13, 6                          ; adjust mask (we now have less bits in r8)
    dec r9                              ; decrement "to few" bytes
    jnz appendZeroToTextLoop            ; do it again if 2 bytes were missing
  ret                                   ; go back to routine call

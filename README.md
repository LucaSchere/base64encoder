# A binary to base64 encoder in assembly Language (nasm)

## Overview and Goal

The goal of this program is to convert binary data into base64 encoding.

The basic idea of base64 is to define an alphabet (e.g. all lower- and upper-
case letters) and to map all possible binary values to this alphabet.
The normal base64 alphabet is {a-z, A-Z, 0-9, +, /}, which indeed consists of
64 characters.

As a byte has 256 possible values, it cannot be directly translated to the
base64 alphabet and a conversion must take place. For this, the binary input
data is split into groups of 6 bits (2^6 = 64). Each of these groups can then
be mapped to a character of the alphabet and used as output.

### handling of input data

1. The input length is a multiple of 3: No problem, we can encode the final 3
   bytes as all the others before.

2. The last group consists of only 2 bytes (16 bits): In this case, we add two
   additional 0-bits at the end (=18 bits) and encode to three base64
   characters. Then, we add a "="-character at the end of the output as a
   marker to indicate this change.

3. The last group consists only of 1 byte (8 bits): The procedure is similar.
   We add four additional 0-bits at the end (=12 bits) and encode to two base64
   characters. We use "==" at the end as a marker in this case.

See [Base64 Wikipedia](http://en.wikipedia.org/wiki/Base64) for more details.

## Usage
1. Rename one of the asm files to "base64encoder.asm"
2. Install nasm and run the following command:
```bash
    nasm -f elf64 -o base64encoder.o base64encoder.asm
    ld -o base64encoder base64encoder.o
    ./base64encoder
```

or use the Makefile:
```bash
    make
    ./base64encoder
```

Pipe input and output:
```bash
    ./base64encoder < input > output
```

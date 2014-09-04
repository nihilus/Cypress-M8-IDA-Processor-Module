#include "m8b.hpp"

instruc_t rgInstructions[] =
{
    // Unknown Operation
    { "", 0 },

    // ADD A,expr (op=01h, size=2, cf, zf)
    // ADD A,[expr] (op=02h, size=2, cf, zf)
    // ADD A,[X+expr] (op=03h, size=2, cf, zf)
    { "ADD", CF_USE1|CF_USE2|CF_CHG1 },

    // ADC A,expr (op=04h, size=2, cf, zf)
    // ADC A,[expr] (op=05h, size=2, cf, zf)
    // ADC A,[X+expr] (op=06h, size=2, cf, zf)
    { "ADC", CF_USE1|CF_USE2|CF_CHG1 },

    // AND A,expr (op=10h, size=2, cf=0, zf)
    // AND A,[expr] (op=11h, size=2, cf=0, zf)
    // AND A,[X+expr] (op=12h, size=2, cf=0, zf)
    // AND [expr],A (op=35h, size=2, cf=0, zf)
    // AND [X+expr],A (op=36h, size=2, cf=0, zf)
    { "AND", CF_USE1|CF_USE2|CF_CHG1 },

    // ASL A (op=3Bh, size=1, cf, zf)
    { "ASL", CF_USE1|CF_CHG1 },

    // ASR A (op=3Ch, size=1, cf, zf)
    { "ASR", CF_USE1|CF_CHG1 },

    // CALL addr (op=90h-9Fh, size=2)
    // CALL addr (op=50h-5Fh, size=2)
    { "CALL", CF_USE1|CF_CALL },

    // CMP A,expr (op=16h, size=2, cf, zf)
    // CMP A,[expr] (op=17h, size=2, cf, zf)
    // CMP A,[X+expr] (op=18h, size=2, cf, zf)
    { "CMP", CF_USE1|CF_USE2|CF_CHG1 },

    // CPL A (op=3Ah, size=1, cf=1, zf)
    { "CPL", CF_USE1|CF_CHG1 },

    // DEC A (op=25h, size=1, cf, zf)
    // DEC X (op=26h, size=1, cf, zf)
    // DEC [expr] (op=27h, size=2, cf, zf)
    // DEC [X+expr] (op=28h, size=2, cf, zf)
    { "DEC", CF_USE1|CF_CHG1 },

    // DI (op=70h, size=1, ie=0)
    { "DI", 0 },

    // EI (op=72h, size=1, ie=1)
    { "EI", 0 },

    // HALT (op=00h, size=1)
    { "HALT", 0 },

    // INC A (op=21h, size=1, cf, zf)
    // INC X (op=22h, size=1, cf, zf)
    // INC [expr] (op=23h, size=2, cf, zf)
    // INC [X+expr] (op=24h, size=2, cf, zf)
    { "INC", CF_USE1|CF_CHG1 },

    // INDEX addr (op=F0h-FFh, size=2, cf, zf)
    { "INDEX", CF_USE1 },

    // IORD addr (op=29h, size=2)
    { "IORD", CF_USE1 },

    // IOWR addr (op=2Ah, size=2)
    { "IOWR", CF_USE1 },

    // IOWX [X+expr] (op=39h, size=2)
    { "IOWX", CF_USE1 },

    // IPRET addr (op=1Eh, size=2)
    { "IPRET", CF_USE1|CF_STOP },

    // JACC addr (op=E0h-EFh, size=2, cf, zf)
    { "JACC", CF_USE1|CF_JUMP|CF_STOP },

    // JC addr (op=C0h-CFh, size=2)
    { "JC", CF_USE1 },

    // JMP addr (op=80h-8Fh, size=2)
    { "JMP", CF_USE1|CF_STOP },

    // JNC addr (op=D0h-DFh, size=2)
    { "JNC", CF_USE1 },

    // JNZ addr (op=B0h-BFh, size=2)
    { "JNZ", CF_USE1 },

    // JZ addr (op=A0h-AFh, size=2)
    { "JZ", CF_USE1 },

    // MOV A,expr (op=19h, size=2)
    // MOV A,[expr] (op=1Ah, size=2)
    // MOV A,[X+expr] (op=1Bh, size=2)
    // MOV [expr],A (op=31h, size=2)
    // MOV [X+expr],A (op=32h, size=2)
    // MOV X,expr (op=1Ch, size=2)
    // MOV X,[expr] (op=1Dh, size=2)
    // MOV A,X (op=40h, size=1)
    // MOV X,A (op=41h, size=1)
    // MOV PSP,A (op=60h, size=1)
    { "MOV", CF_USE1|CF_USE2|CF_CHG1 },

    // NOP (op=20h, size=1)
    { "NOP", 0 },

    // OR A,expr (op=0Dh, size=2, cf=0, zf)
    // OR A,[expr] (op=0Eh, size=2, cf=0, zf)
    // OR A,[X+expr] (op=0Fh, size=2, cf=0, zf)
    // OR [expr],A (op=33h, size=2, cf=0, zf)
    // OR [X+expr],A (op=34h, size=2, cf=0, zf)
    { "OR", CF_USE1|CF_USE2|CF_CHG1 },

    // POP A (op=2Bh, size=1)
    // POP X (op=2Ch, size=1)
    { "POP", CF_USE1|CF_CHG1 },

    // PUSH A (op=2Dh, size=1)
    // PUSH X (op=2Eh, size=1)
    { "PUSH", CF_USE1 },

    // RET (op=3Fh, size=1)
    { "RET", CF_STOP },

    // RETI (op=73h, size=1, cf, zf, ie=1)
    { "RETI", CF_STOP },

    // RLC A (op=3Dh, size=1, cf, zf)
    { "RLC", CF_USE1|CF_CHG1 },

    // RRC A (op=3Eh, size=1, cf, zf)
    { "RRC", CF_USE1|CF_CHG1 },

    // SUB A,expr (op=07h, size=2, cf, zf)
    // SUB A,[expr] (op=08h, size=2, cf, zf)
    // SUB A,[X+expr] (op=09h, size=2, cf, zf)
    { "SUB", CF_USE1|CF_USE2|CF_CHG1 },

    // SBB A,expr (op=0Ah, size=2, cf, zf)
    // SBB A,[expr] (op=0Bh, size=2, cf, zf)
    // SBB A,[X+expr] (op=0Ch, size=2, cf, zf)
    { "SBB", CF_USE1|CF_USE2|CF_CHG1 },

    // SWAP A,X (op=2Fh, size=1)
    // SWAP A,DSP (op=30h, size=1)
    { "SWAP", CF_USE1|CF_USE2|CF_CHG1|CF_CHG2 },

    // XOR A,expr (op=13h, size=2, cf=0, zf)
    // XOR A,[expr] (op=14h, size=2, cf=0, zf)
    // XOR A,[X+expr] (op=15h, size=2, cf=0, zf)
    // XOR [expr],A (op=37h, size=2, cf=0, zf)
    // XOR [X+expr],A (op=38h, size=2, cf=0, zf)
    { "XOR", CF_USE1|CF_USE2|CF_CHG1 },

    // XPAGE (op=1Fh, size=1)
    { "XPAGE", 0 }
};

CASSERT(qnumber(rgInstructions) == M8B_last);

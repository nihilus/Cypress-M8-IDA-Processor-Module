#ifndef INS_HPP_INCLUDED
#define INS_HPP_INCLUDED

extern instruc_t rgInstructions[];

enum instructno_t ENUM_SIZE(uint8)
{
    M8B_null = 0,
    M8B_ADD,
    M8B_ADC,
    M8B_AND,
    M8B_ASL,
    M8B_ASR,
    M8B_CALL,
    M8B_CMP,
    M8B_CPL,
    M8B_DEC,
    M8B_DI,
    M8B_EI,
    M8B_HALT,
    M8B_INC,
    M8B_INDEX,
    M8B_IORD,
    M8B_IOWR,
    M8B_IOWX,
    M8B_IPRET,
    M8B_JACC,
    M8B_JC,
    M8B_JMP,
    M8B_JNC,
    M8B_JNZ,
    M8B_JZ,
    M8B_MOV,
    M8B_NOP,
    M8B_OR,
    M8B_POP,
    M8B_PUSH,
    M8B_RET,
    M8B_RETI,
    M8B_RLC,
    M8B_RRC,
    M8B_SUB,
    M8B_SBB,
    M8B_SWAP,
    M8B_XOR,
    M8B_XPAGE,
    M8B_last
};

#endif

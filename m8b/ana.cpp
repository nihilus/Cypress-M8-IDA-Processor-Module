#include "m8b.hpp"

static inline void op_reg(op_t& x, regno_t n);
static inline void op_imm(op_t& x);
static inline void op_mem(op_t& x);
static inline void op_near(op_t& x, uint32 code);
static inline void op_displ(op_t& x);

static inline void op_reg(op_t& x, regno_t n)
{
    x.type = o_reg;
    x.dtyp = dt_byte;
    x.offb = 0;
    x.reg = n;
}

static inline void op_imm(op_t& x)
{
    x.type = o_imm;
    x.dtyp = dt_byte;
    x.offb = (char)cmd.size;
    x.value = ua_next_byte();
}

static inline void op_mem(op_t& x)
{
    x.type = o_mem;
    x.dtyp = dt_byte;
    x.offb = (char)cmd.size;
    x.addr = ua_next_byte();
}

static inline void op_near(op_t& x, uint32 code)
{
    x.type = o_near;
    x.dtyp = dt_code;
    x.offb = 0;
    x.addr = (cmd.ea & 0xF000) | ((code & 0xF) << 8) | ua_next_byte();
}

static inline void op_displ(op_t& x)
{
    x.type = o_displ;
    x.dtyp = dt_byte;
    x.offb = (char)cmd.size;
    x.addr = ua_next_byte();
    x.phrase = rX;
}

bool idaapi can_have_type(op_t& x)
{
    switch ( x.type )
    {
    case o_void:
        return false;
    case o_reg:
    case o_mem:
    case o_phrase:
    case o_displ:
    case o_imm:
    case o_far:
    case o_near:
    case o_idpspec0:
    case o_idpspec1:
    case o_idpspec2:
    case o_idpspec3:
    case o_idpspec4:
    case o_idpspec5:
    default:
        return true;
    }
}

int idaapi is_align_insn(ea_t ea)
{
    if (!decode_insn(ea)) return 0;

    switch (cmd.itype)
    {
    case M8B_NOP:
    case M8B_XPAGE:
        return cmd.size;
    default:
        return 0;
    }
}

int idaapi is_sane_insn(int nocrefs)
{
    ea_t ea, i;

    for (ea = cmd.ea, i = 0; i < 8 && get_byte(ea) != 0x00; ++i, ++ea);
    if (i == 8) return 0;
    for (ea = cmd.ea, i = 0; i < 8 && get_byte(ea) != 0xFF; ++i, ++ea);
    if (i == 8) return 0;

    return 1;
}

int idaapi ana()
{
    uint32 code = ua_next_byte();

    switch (code)
    {
    // ADD A,expr (op=01h, size=2, cf, zf)
    case 0x01:
        cmd.itype = M8B_ADD;
        op_reg(cmd.Op1, rA);
        op_imm(cmd.Op2);
        break;

    // ADD A,[expr] (op=02h, size=2, cf, zf)
    case 0x02:
        cmd.itype = M8B_ADD;
        op_reg(cmd.Op1, rA);
        op_mem(cmd.Op2);
        break;

    // ADD A,[X+expr] (op=03h, size=2, cf, zf)
    case 0x03:
        cmd.itype = M8B_ADD;
        op_reg(cmd.Op1, rA);
        op_displ(cmd.Op2);
        break;

    // ADC A,expr (op=04h, size=2, cf, zf)
    case 0x04:
        cmd.itype = M8B_ADC;
        op_reg(cmd.Op1, rA);
        op_imm(cmd.Op2);
        break;

    // ADC A,[expr] (op=05h, size=2, cf, zf)
    case 0x05:
        cmd.itype = M8B_ADC;
        op_reg(cmd.Op1, rA);
        op_mem(cmd.Op2);
        break;

    // ADC A,[X+expr] (op=06h, size=2, cf, zf)
    case 0x06:
        cmd.itype = M8B_ADC;
        op_reg(cmd.Op1, rA);
        op_displ(cmd.Op2);
        break;

    // AND A,expr (op=10h, size=2, cf=0, zf)
    case 0x10:
        cmd.itype = M8B_AND;
        op_reg(cmd.Op1, rA);
        op_imm(cmd.Op2);
        break;

    // AND A,[expr] (op=11h, size=2, cf=0, zf)
    case 0x11:
        cmd.itype = M8B_AND;
        op_reg(cmd.Op1, rA);
        op_mem(cmd.Op2);
        break;

    // AND A,[X+expr] (op=12h, size=2, cf=0, zf)
    case 0x12:
        cmd.itype = M8B_AND;
        op_reg(cmd.Op1, rA);
        op_displ(cmd.Op2);
        break;

    // AND [expr],A (op=35h, size=2, cf=0, zf)
    case 0x35:
        cmd.itype = M8B_AND;
        op_mem(cmd.Op1);
        op_reg(cmd.Op2, rA);
        break;

    // AND [X+expr],A (op=36h, size=2, cf=0, zf)
    case 0x36:
        cmd.itype = M8B_AND;
        op_displ(cmd.Op1);
        op_reg(cmd.Op2, rA);
        break;

    // ASL A (op=3Bh, size=1, cf, zf)
    case 0x3B:
        cmd.itype = M8B_ASL;
        op_reg(cmd.Op1, rA);
        break;

    // ASR A (op=3Ch, size=1, cf, zf)
    case 0x3C:
        cmd.itype = M8B_ASR;
        op_reg(cmd.Op1, rA);
        break;

    // CALL addr (op=90h-9Fh, size=2)
    case 0x90: case 0x91: case 0x92: case 0x93:
    case 0x94: case 0x95: case 0x96: case 0x97:
    case 0x98: case 0x99: case 0x9A: case 0x9B:
    case 0x9C: case 0x9D: case 0x9E: case 0x9F:
        cmd.itype = M8B_CALL;
        op_near(cmd.Op1, code);
        break;

    // CALL addr (op=50h-5Fh, size=2)
    case 0x50: case 0x51: case 0x52: case 0x53:
    case 0x54: case 0x55: case 0x56: case 0x57:
    case 0x58: case 0x59: case 0x5A: case 0x5B:
    case 0x5C: case 0x5D: case 0x5E: case 0x5F:
        cmd.itype = M8B_CALL;
        op_near(cmd.Op1, code);
        cmd.Op1.addr |= 0x1000;
        break;

    // CMP A,expr (op=16h, size=2, cf, zf)
    case 0x16:
        cmd.itype = M8B_CMP;
        op_reg(cmd.Op1, rA);
        op_imm(cmd.Op2);
        break;

    // CMP A,[expr] (op=17h, size=2, cf, zf)
    case 0x17:
        cmd.itype = M8B_CMP;
        op_reg(cmd.Op1, rA);
        op_mem(cmd.Op2);
        break;

    // CMP A,[X+expr] (op=18h, size=2, cf, zf)
    case 0x18:
        cmd.itype = M8B_CMP;
        op_reg(cmd.Op1, rA);
        op_displ(cmd.Op2);
        break;

    // CPL A (op=3Ah, size=1, cf=1, zf)
    case 0x3A:
        cmd.itype = M8B_CPL;
        op_reg(cmd.Op1, rA);
        break;

    // DEC A (op=25h, size=1, cf, zf)
    case 0x25:
        cmd.itype = M8B_DEC;
        op_reg(cmd.Op1, rA);
        break;

    // DEC X (op=26h, size=1, cf, zf)
    case 0x26:
        cmd.itype = M8B_DEC;
        op_reg(cmd.Op1, rX);
        break;

    // DEC [expr] (op=27h, size=2, cf, zf)
    case 0x27:
        cmd.itype = M8B_DEC;
        op_mem(cmd.Op1);
        break;

    // DEC [X+expr] (op=28h, size=2, cf, zf)
    case 0x28:
        cmd.itype = M8B_DEC;
        op_displ(cmd.Op1);
        break;

    // DI (op=70h, size=1, ie=0)
    case 0x70:
        cmd.itype = M8B_DI;
        cmd.Op1.type = o_void;
        break;

    // EI (op=72h, size=1, ie=1)
    case 0x72:
        cmd.itype = M8B_EI;
        cmd.Op1.type = o_void;
        break;

    // HALT (op=00h, size=1)
    case 0x00:
        cmd.itype = M8B_HALT;
        cmd.Op1.type = o_void;
        break;

    // INC A (op=21h, size=1, cf, zf)
    case 0x21:
        cmd.itype = M8B_INC;
        op_reg(cmd.Op1, rA);
        break;

    // INC X (op=22h, size=1, cf, zf)
    case 0x22:
        cmd.itype = M8B_INC;
        op_reg(cmd.Op1, rX);
        break;

    // INC [expr] (op=23h, size=2, cf, zf)
    case 0x23:
        cmd.itype = M8B_INC;
        op_mem(cmd.Op1);
        break;

    // INC [X+expr] (op=24h, size=2, cf, zf)
    case 0x24:
        cmd.itype = M8B_INC;
        op_displ(cmd.Op1);
        break;

    // INDEX addr (op=F0h-FFh, size=2, cf, zf)
    case 0xF0: case 0xF1: case 0xF2: case 0xF3:
    case 0xF4: case 0xF5: case 0xF6: case 0xF7:
    case 0xF8: case 0xF9: case 0xFA: case 0xFB:
    case 0xFC: case 0xFD: case 0xFE: case 0xFF:
        cmd.itype = M8B_INDEX;
        op_near(cmd.Op1, code);
        break;

    // IORD addr (op=29h, size=2)
    case 0x29:
        cmd.itype = M8B_IORD;
        op_mem(cmd.Op1);
        break;

    // IOWR addr (op=2Ah, size=2)
    case 0x2A:
        cmd.itype = M8B_IOWR;
        op_mem(cmd.Op1);
        break;

    // IOWX [X+expr] (op=39h, size=2)
    case 0x39:
        cmd.itype = M8B_IOWX;
        op_displ(cmd.Op1);
        break;

    // IPRET addr (op=1Eh, size=2)
    case 0x1E:
        cmd.itype = M8B_IPRET;
        op_mem(cmd.Op1);
        break;

    // JACC addr (op=E0h-EFh, size=2, cf, zf)
    case 0xE0: case 0xE1: case 0xE2: case 0xE3:
    case 0xE4: case 0xE5: case 0xE6: case 0xE7:
    case 0xE8: case 0xE9: case 0xEA: case 0xEB:
    case 0xEC: case 0xED: case 0xEE: case 0xEF:
        cmd.itype = M8B_JACC;
        op_near(cmd.Op1, code);
        break;

    // JC addr (op=C0h-CFh, size=2)
    case 0xC0: case 0xC1: case 0xC2: case 0xC3:
    case 0xC4: case 0xC5: case 0xC6: case 0xC7:
    case 0xC8: case 0xC9: case 0xCA: case 0xCB:
    case 0xCC: case 0xCD: case 0xCE: case 0xCF:
        cmd.itype = M8B_JC;
        op_near(cmd.Op1, code);
        break;

    // JMP addr (op=80h-8Fh, size=2)
    case 0x80: case 0x81: case 0x82: case 0x83:
    case 0x84: case 0x85: case 0x86: case 0x87:
    case 0x88: case 0x89: case 0x8A: case 0x8B:
    case 0x8C: case 0x8D: case 0x8E: case 0x8F:
        cmd.itype = M8B_JMP;
        op_near(cmd.Op1, code);
        break;

    // JNC addr (op=D0h-DFh, size=2)
    case 0xD0: case 0xD1: case 0xD2: case 0xD3:
    case 0xD4: case 0xD5: case 0xD6: case 0xD7:
    case 0xD8: case 0xD9: case 0xDA: case 0xDB:
    case 0xDC: case 0xDD: case 0xDE: case 0xDF:
        cmd.itype = M8B_JNC;
        op_near(cmd.Op1, code);
        break;

    // JNZ addr (op=B0h-BFh, size=2)
    case 0xB0: case 0xB1: case 0xB2: case 0xB3:
    case 0xB4: case 0xB5: case 0xB6: case 0xB7:
    case 0xB8: case 0xB9: case 0xBA: case 0xBB:
    case 0xBC: case 0xBD: case 0xBE: case 0xBF:
        cmd.itype = M8B_JNZ;
        op_near(cmd.Op1, code);
        break;

    // JZ addr (op=A0h-AFh, size=2)
    case 0xA0: case 0xA1: case 0xA2: case 0xA3:
    case 0xA4: case 0xA5: case 0xA6: case 0xA7:
    case 0xA8: case 0xA9: case 0xAA: case 0xAB:
    case 0xAC: case 0xAD: case 0xAE: case 0xAF:
        cmd.itype = M8B_JZ;
        op_near(cmd.Op1, code);
        break;

    // MOV A,expr (op=19h, size=2)
    case 0x19:
        cmd.itype = M8B_MOV;
        op_reg(cmd.Op1, rA);
        op_imm(cmd.Op2);
        break;

    // MOV A,[expr] (op=1Ah, size=2)
    case 0x1A:
        cmd.itype = M8B_MOV;
        op_reg(cmd.Op1, rA);
        op_mem(cmd.Op2);
        break;

    // MOV A,[X+expr] (op=1Bh, size=2)
    case 0x1B:
        cmd.itype = M8B_MOV;
        op_reg(cmd.Op1, rA);
        op_displ(cmd.Op2);
        break;

    // MOV [expr],A (op=31h, size=2)
    case 0x31:
        cmd.itype = M8B_MOV;
        op_mem(cmd.Op1);
        op_reg(cmd.Op2, rA);
        break;

    // MOV [X+expr],A (op=32h, size=2)
    case 0x32:
        cmd.itype = M8B_MOV;
        op_displ(cmd.Op1);
        op_reg(cmd.Op2, rA);
        break;

    // MOV X,expr (op=1Ch, size=2)
    case 0x1C:
        cmd.itype = M8B_MOV;
        op_reg(cmd.Op1, rX);
        op_imm(cmd.Op2);
        break;

    // MOV X,[expr] (op=1Dh, size=2)
    case 0x1D:
        cmd.itype = M8B_MOV;
        op_reg(cmd.Op1, rX);
        op_mem(cmd.Op2);
        break;

    // MOV A,X (op=40h, size=1)
    case 0x40:
        cmd.itype = M8B_MOV;
        op_reg(cmd.Op1, rA);
        op_reg(cmd.Op2, rX);
        break;

    // MOV X,A (op=41h, size=1)
    case 0x41:
        cmd.itype = M8B_MOV;
        op_reg(cmd.Op1, rX);
        op_reg(cmd.Op2, rA);
        break;

    // MOV PSP,A (op=60h, size=1)
    case 0x60:
        cmd.itype = M8B_MOV;
        op_reg(cmd.Op1, rPSP);
        op_reg(cmd.Op2, rA);
        break;

    // NOP (op=20h, size=1)
    case 0x20:
        cmd.itype = M8B_NOP;
        cmd.Op1.type = o_void;
        break;

    // OR A,expr (op=0Dh, size=2, cf=0, zf)
    case 0x0D:
        cmd.itype = M8B_OR;
        op_reg(cmd.Op1, rA);
        op_imm(cmd.Op2);
        break;

    // OR A,[expr] (op=0Eh, size=2, cf=0, zf)
    case 0x0E:
        cmd.itype = M8B_OR;
        op_reg(cmd.Op1, rA);
        op_mem(cmd.Op2);
        break;

    // OR A,[X+expr] (op=0Fh, size=2, cf=0, zf)
    case 0x0F:
        cmd.itype = M8B_OR;
        op_reg(cmd.Op1, rA);
        op_displ(cmd.Op2);
        break;

    // OR [expr],A (op=33h, size=2, cf=0, zf)
    case 0x33:
        cmd.itype = M8B_OR;
        op_mem(cmd.Op1);
        op_reg(cmd.Op2, rA);
        break;

    // OR [X+expr],A (op=34h, size=2, cf=0, zf)
    case 0x34:
        cmd.itype = M8B_OR;
        op_displ(cmd.Op1);
        op_reg(cmd.Op2, rA);
        break;

    // POP A (op=2Bh, size=1)
    case 0x2B:
        cmd.itype = M8B_POP;
        op_reg(cmd.Op1, rA);
        break;

    // POP X (op=2Ch, size=1)
    case 0x2C:
        cmd.itype = M8B_POP;
        op_reg(cmd.Op1, rX);
        break;

    // PUSH A (op=2Dh, size=1)
    case 0x2D:
        cmd.itype = M8B_PUSH;
        op_reg(cmd.Op1, rA);
        break;

    // PUSH X (op=2Eh, size=1)
    case 0x2E:
        cmd.itype = M8B_PUSH;
        op_reg(cmd.Op1, rX);
        break;

    // RET (op=3Fh, size=1)
    case 0x3F:
        cmd.itype = M8B_RET;
        cmd.Op1.type = o_void;
        break;

    // RETI (op=73h, size=1, cf, zf, ie=1)
    case 0x73:
        cmd.itype = M8B_RETI;
        cmd.Op1.type = o_void;
        break;

    // RLC A (op=3Dh, size=1, cf, zf)
    case 0x3D:
        cmd.itype = M8B_RLC;
        op_reg(cmd.Op1, rA);
        break;

    // RRC A (op=3Eh, size=1, cf, zf)
    case 0x3E:
        cmd.itype = M8B_RRC;
        op_reg(cmd.Op1, rA);
        break;

    // SUB A,expr (op=07h, size=2, cf, zf)
    case 0x07:
        cmd.itype = M8B_SUB;
        op_reg(cmd.Op1, rA);
        op_imm(cmd.Op2);
        break;

    // SUB A,[expr] (op=08h, size=2, cf, zf)
    case 0x08:
        cmd.itype = M8B_SUB;
        op_reg(cmd.Op1, rA);
        op_mem(cmd.Op2);
        break;

    // SUB A,[X+expr] (op=09h, size=2, cf, zf)
    case 0x09:
        cmd.itype = M8B_SUB;
        op_reg(cmd.Op1, rA);
        op_displ(cmd.Op2);
        break;

    // SBB A,expr (op=0Ah, size=2, cf, zf)
    case 0x0A:
        cmd.itype = M8B_SBB;
        op_reg(cmd.Op1, rA);
        op_imm(cmd.Op2);
        break;

    // SBB A,[expr] (op=0Bh, size=2, cf, zf)
    case 0x0B:
        cmd.itype = M8B_SBB;
        op_reg(cmd.Op1, rA);
        op_mem(cmd.Op2);
        break;

    // SBB A,[X+expr] (op=0Ch, size=2, cf, zf)
    case 0x0C:
        cmd.itype = M8B_SBB;
        op_reg(cmd.Op1, rA);
        op_displ(cmd.Op2);
        break;

    // SWAP A,X (op=2Fh, size=1)
    case 0x2F:
        cmd.itype = M8B_SWAP;
        op_reg(cmd.Op1, rA);
        op_reg(cmd.Op2, rX);
        break;

    // SWAP A,DSP (op=30h, size=1)
    case 0x30:
        cmd.itype = M8B_SWAP;
        op_reg(cmd.Op1, rA);
        op_reg(cmd.Op2, rDSP);
        break;

    // XOR A,expr (op=13h, size=2, cf=0, zf)
    case 0x13:
        cmd.itype = M8B_XOR;
        op_reg(cmd.Op1, rA);
        op_imm(cmd.Op2);
        break;

    // XOR A,[expr] (op=14h, size=2, cf=0, zf)
    case 0x14:
        cmd.itype = M8B_XOR;
        op_reg(cmd.Op1, rA);
        op_mem(cmd.Op2);
        break;

    // XOR A,[X+expr] (op=15h, size=2, cf=0, zf)
    case 0x15:
        cmd.itype = M8B_XOR;
        op_reg(cmd.Op1, rA);
        op_displ(cmd.Op2);
        break;

    // XOR [expr],A (op=37h, size=2, cf=0, zf)
    case 0x37:
        cmd.itype = M8B_XOR;
        op_mem(cmd.Op1);
        op_reg(cmd.Op2, rA);
        break;

    // XOR [X+expr],A (op=38h, size=2, cf=0, zf)
    case 0x38:
        cmd.itype = M8B_XOR;
        op_displ(cmd.Op1);
        op_reg(cmd.Op2, rA);
        break;

    // XPAGE (op=1Fh, size=1)
    case 0x1F:
        cmd.itype = M8B_XPAGE;
        cmd.Op1.type = o_void;
        break;

    default:
        return 0;
    }

    return cmd.size;
}

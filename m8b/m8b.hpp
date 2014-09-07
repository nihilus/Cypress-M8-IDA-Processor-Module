#ifndef M8B_HPP_INCLUDED
#define M8B_HPP_INCLUDED

#define PLFM_M8B 0x8783

#pragma warning(disable: 4267)
#include "idaidp.hpp"
#include "ins.hpp"
#include <diskio.hpp>
#pragma warning(default: 4267)

enum regno_t ENUM_SIZE(uint16) { rA = 0, rX, rDSP, rPSP, rVcs, rVds };

extern char szDevice[];
extern char szDeviceParams[];
extern netnode helper;

segment_t* segROM();
segment_t* segRAM();
segment_t* segIOP();
ea_t toROM(ea_t ea);
ea_t toRAM(ea_t ea);
ea_t toIOP(ea_t ea);

const char* get_port_sym(ea_t eaPort);
const char* get_portbit_sym(ea_t eaPort, size_t nBit);
bool get_portbits_sym(char szSym[MAXSTR], ea_t eaPort, size_t nMask);
bool is_port_sym(const char* szName);

void idaapi header();
void idaapi footer();

void idaapi segstart(ea_t ea);

int idaapi ana();
int idaapi emu();
void idaapi out();
bool idaapi outop(op_t& op);

bool idaapi can_have_type(op_t& x);
int idaapi is_align_insn(ea_t ea);
int idaapi is_sane_insn(int nocrefs);

#endif

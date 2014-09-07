#include "m8b.hpp"
#include "queue.hpp"
#include <frame.hpp>

static bool fFlow;

static void op_imm(int n);
static void op_emu(op_t& x, int fIsLoad);

static void op_imm(int n)
{
    doImmd(cmd.ea);

    if (isDefArg(uFlag, n)) return;

    switch (cmd.itype)
    {
    case M8B_ADD:
    case M8B_ADC:
    case M8B_SUB:
    case M8B_SBB:
        op_dec(cmd.ea, n);
        break;
    case M8B_CMP:
    case M8B_MOV:
    case M8B_AND:
    case M8B_OR:
    case M8B_XOR:
        op_num(cmd.ea, n);
        break;
    }
}

static void op_emu(op_t& x, int fIsLoad)
{
    char szLabel[128];
    cref_t ftype;
    ea_t ea;

    switch (x.type)
    {
    case o_reg:
    case o_phrase:
        return;
    case o_imm:
        if (!fIsLoad) break;
        op_imm(cmd.ea);
        return;
    case o_displ:
    case o_mem:
        switch (cmd.itype)
        {
        case M8B_IORD:
        case M8B_IOWR:
        case M8B_IOWX:
        case M8B_IPRET:
            ea = toIOP(x.addr);
            if (ea != BADADDR)
            {
                ua_dodata2(x.offb, ea, x.dtyp);
                if (!fIsLoad) doVar(ea);
                ua_add_dref(x.offb, ea, cmd.itype == M8B_IORD ? dr_R : dr_W);
            }
            break;
        default:
            ea = toRAM(x.addr);
            if (ea != BADADDR)
            {
                if (!has_any_name(get_flags_novalue(ea)))
                {
                    qsnprintf(szLabel, sizeof(szLabel), "ram_%0.2X", x.addr);
                    set_name(ea, szLabel, SN_NOWARN);
                }
                ua_dodata2(x.offb, ea, x.dtyp);
                if (!fIsLoad) doVar(ea);
                ua_add_dref(x.offb, ea, cmd.itype == M8B_IORD ? dr_R : dr_W);
            }
        }
        return;
    case o_near:
        ea = toROM(x.addr);
        if (ea != BADADDR)
        {
            switch (cmd.itype)
            {
            case M8B_INDEX:
                if (!has_any_name(get_flags_novalue(ea)))
                {
                    qsnprintf(szLabel, sizeof(szLabel), "tbl_%0.4X", x.addr);
                    set_name(ea, szLabel, SN_NOWARN);
                }
                ua_add_dref(x.offb, ea, dr_R);
                break;
            default:
                ftype = fl_JN;
                if (InstrIsSet(cmd.itype, CF_CALL))
                {
                    if (!func_does_return(ea))
                        fFlow = false;
                    ftype = fl_CN;
                }
                ua_add_cref(x.offb, ea, ftype);
            }
        }
        return;
    }

    warning("%a: %s,%d: bad optype %d", cmd.ea, cmd.get_canon_mnem(), x.n, x.type);
}

int idaapi emu()
{
    char szLabel[MAXSTR];
    insn_t saved;
    segment_t* pSegment;
    ea_t ea, length, offset;
    flags_t flags;
    uint32 dwFeature, i;

    dwFeature = cmd.get_canon_feature();
    fFlow = !(dwFeature & CF_STOP);

    if (dwFeature & CF_USE1) op_emu(cmd.Op1, 1);
    if (dwFeature & CF_USE2) op_emu(cmd.Op2, 1);

    if (dwFeature & CF_CHG1) op_emu(cmd.Op1, 0);
    if (dwFeature & CF_CHG2) op_emu(cmd.Op2, 0);

    saved = cmd;
    switch (cmd.itype)
    {
    case M8B_MOV:
        if (!cmd.Op1.is_reg(rPSP))
            break;
    case M8B_SWAP:
        if (cmd.itype == M8B_SWAP && !cmd.Op2.is_reg(rDSP))
            break;

        for (i = 0; i < 5; ++i)
        {
            ea = decode_prev_insn(cmd.ea);
            if (ea == BADADDR) break;
            if (cmd.itype == M8B_MOV && cmd.Op1.is_reg(rA) && cmd.Op2.type == o_imm)
            {
                ea = toRAM(cmd.Op2.value);
                if (ea != BADADDR)
                {
                    qsnprintf(szLabel, sizeof(szLabel), "%s_%0.2X", cmd.itype == M8B_MOV ? "psp" : "dsp", cmd.Op2.value);
                    ua_add_dref(cmd.Op2.offb, ea, dr_O);
                    set_name(ea, szLabel, SN_NOWARN);
                }
                break;
            }
        }
        break;
    case M8B_JACC:
        pSegment = getseg(cmd.ea);
        if (!pSegment) break;
        length = pSegment->endEA - cmd.ea;
        if (length > 256) length = 256;
        for (offset = 2; offset < length; offset += 2)
        {
            ea = toROM(saved.Op1.addr + offset);
            if (ea == BADADDR) break;
            flags = getFlags(ea);
            if (!hasValue(flags) || (has_any_name(flags) || hasRef(flags)) || !create_insn(ea)) break;
            switch (cmd.itype)
            {
            case M8B_JMP:
            case M8B_RET:
            case M8B_RETI:
            case M8B_IPRET:
                add_cref(saved.ea, ea, fl_JN);
                break;
            default:
                offset = length;
            }
        }
        break;
    case M8B_IORD:
    case M8B_IOWR:
    case M8B_IOWX:
        for (i = 0; i < 5; ++i)
        {
            ea = (saved.itype == M8B_IORD) ? decode_insn(cmd.ea + cmd.size) : decode_prev_insn(cmd.ea);
            if (ea == BADADDR) break;
            if (cmd.Op1.is_reg(rA) && cmd.Op2.type == o_imm)
            {
                qsnprintf(szLabel, sizeof(szLabel), "[A=%0.2Xh] ", cmd.Op2.value);
                if (get_portbits_sym(szLabel + qstrlen(szLabel), saved.Op1.addr, cmd.Op2.value))
                    set_cmt(saved.ea, szLabel, false);
                break;
            }
        }
    }
    cmd = saved;

    if ((cmd.ea & 0xFF) == 0xFF)
    {
        switch (cmd.itype)
        {
        case M8B_RET:
        case M8B_RETI:
        case M8B_XPAGE:
            break;
        default:
            QueueMark(Q_noValid, cmd.ea);
        }
    }

    if (fFlow) ua_add_cref(0, cmd.ea + cmd.size, fl_F);

    return 1;
}

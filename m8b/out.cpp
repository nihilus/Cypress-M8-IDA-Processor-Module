#include "m8b.hpp"

static void out_bad_address(ea_t addr)
{
    out_tagon(COLOR_ERROR);
    OutLong(addr, 16);
    out_tagoff(COLOR_ERROR);
    QueueMark(Q_noName, cmd.ea);
}

bool idaapi outop(op_t& x)
{
    char szValue[MAXSTR];
    const char* szSymbol;
    ea_t ea;

    switch (x.type)
    {
    case o_void:
        return false;

    case o_reg:
        out_register(ph.regNames[x.reg]);
        break;

    case o_phrase:
        out_symbol('[');
        out_register(ph.regNames[x.phrase]);
        out_symbol(']');
        break;

    case o_displ:
        out_symbol('[');
        out_register(ph.regNames[x.phrase]);
        out_symbol('+');
        if (cmd.itype == M8B_IOWX)
        {
            szSymbol = get_port_sym(x.addr);
            if (szSymbol)
            {
                out_addr_tag(cmd.ea);
                out_line(szSymbol, COLOR_IMPNAME);
            }
            else
                OutValue(x, OOF_ADDR | OOFS_NOSIGN | OOFW_IMM);
        }
        else
        {
            ea = toRAM(x.addr);
            if (ea == BADADDR)
                out_bad_address(x.addr);
            else if (get_name_expr(cmd.ea + x.offb, x.n, ea, x.addr, szValue, sizeof(szValue)) > 0)
                OutLine(szValue);
            else
                OutValue(x, OOF_ADDR | OOFS_NOSIGN | OOFW_IMM);
        }
        out_symbol(']');
        break;

    case o_imm:
        OutValue(x, OOFS_NOSIGN | OOFW_IMM);
        break;

    case o_mem:
        switch (cmd.itype)
        {
        case M8B_IORD:
        case M8B_IOWR:
        case M8B_IPRET:
            ea = toIOP(x.addr);
            if (ea == BADADDR)
                out_bad_address(x.addr);
            else if (get_name_expr(cmd.ea + x.offb, x.n, ea, x.addr, szValue, sizeof(szValue)) > 0)
                OutLine(szValue);
            else
                OutValue(x, OOF_ADDR | OOFS_NOSIGN | OOFW_IMM);
            break;

        default:
            out_symbol('[');
            ea = toRAM(x.addr);
            if (ea == BADADDR)
                out_bad_address(x.addr);
            else if (get_name_expr(cmd.ea + x.offb, x.n, ea, x.addr, szValue, sizeof(szValue)) > 0)
                OutLine(szValue);
            else
                OutValue(x, OOF_ADDR | OOFS_NOSIGN | OOFW_IMM);
            out_symbol(']');
        }
        break;

    case o_near:
        ea = toROM(x.addr);
        if (ea == BADADDR)
            out_bad_address(x.addr);
        else if (get_name_expr(cmd.ea + x.offb, x.n, ea, x.addr, szValue, sizeof(szValue)) <= 0)
        {
            OutValue(x, OOF_ADDR | OOFS_NOSIGN | OOFW_16);
            QueueMark(Q_noName, cmd.ea);
        }
        else
            OutLine(szValue);
        break;

     default:
         warning("out: %a: bad optype %d", cmd.ea, x.type);
    }

    return true;
}

void idaapi out()
{
    char szLine[MAXSTR];

    init_output_buffer(szLine, sizeof(szLine));

    if (!has_any_name(uFlag) && helper.altval(cmd.ea))
    {
        btoa(szLine, sizeof(szLine), cmd.ip);
        printf_line(inf.indent, COLSTR("%s %s", SCOLOR_ASMDIR), ash.origin, szLine);
    }

    OutMnem();

    out_one_operand(0);

    if (cmd.Op2.type != o_void)
    {
        out_symbol(',');
        OutChar(' ');
        out_one_operand(1);
    }

    if (isVoid(cmd.ea, uFlag, 0)) OutImmChar(cmd.Op1);
    if (isVoid(cmd.ea, uFlag, 1)) OutImmChar(cmd.Op2);

    term_output_buffer();
    gl_comm = 1;

    MakeLine(szLine);
}

void idaapi header()
{
    uint32 nCPU;

    gen_cmt_line("Processor:        %s [%s]", szDevice[0] ? szDevice : inf.procName, szDeviceParams);
    gen_cmt_line("Processor:        %s", inf.procName);
    gen_cmt_line("Target assembler: %s", ash.name);
    if (ash.header != NULL)
    {
        for( const char *const *ptr=ash.header; *ptr != NULL; ptr++ )
            printf_line(inf.indent, COLSTR("%s", SCOLOR_ASMDIR), *ptr);
    }

    MakeNull();

    if (qstrlen(szDevice) < 4 || qsscanf(szDevice + 4, "%u", &nCPU) != 1)
        nCPU = 63000;

    printf_line(inf.indent, COLSTR("CPU %u", SCOLOR_ASMDIR), nCPU);
}

void idaapi footer()
{
    gen_cmt_line("end of file");
}

void idaapi segstart(ea_t ea)
{
    char szSegmentName[MAXNAMELEN], szNumber[MAX_NUMBUF];
    segment_t* pSegment;

    pSegment = getseg(ea);

    if (is_spec_segm(pSegment->type)) return;

    get_segm_name(pSegment, szSegmentName, sizeof(szSegmentName));

    switch (pSegment->type)
    {
    case SEG_CODE:
        printf_line(inf.indent, COLSTR("CSEG", SCOLOR_ASMDIR) " " COLSTR("%s %s", SCOLOR_AUTOCMT), ash.cmnt, szSegmentName);
        break;
    case SEG_DATA:
        printf_line(inf.indent, COLSTR("DSEG", SCOLOR_ASMDIR) " " COLSTR("%s %s", SCOLOR_AUTOCMT), ash.cmnt, szSegmentName);
        break;
    default:
        return;
    }

    if (pSegment->orgbase != 0)
    {
        btoa(szNumber, sizeof(szNumber), pSegment->orgbase);
        printf_line(inf.indent, COLSTR("%s %s", SCOLOR_ASMDIR), ash.origin, szNumber);
    }
}

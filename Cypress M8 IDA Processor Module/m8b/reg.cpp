#include "m8b.hpp"
#include <entry.hpp>
#include <srarea.hpp>
#include "idp.hpp"

#define SEGNAME_ROM   "ROM"
#define SEGNAME_RAM   "RAM"
#define SEGNAME_IOP   "IOP"
#define DEVICEPARAMS  SEGNAME_ROM "=%lu " SEGNAME_RAM "=%lu"
#define NONEPROC      "NONE"

netnode helper;
char szDevice[MAXSTR] = "";
char szDeviceParams[MAXSTR] = "";

static size_t cbROM = 0;
static size_t cbRAM = 0;

static size_t nIOPorts;
static ioport_t* pIOPorts;
static char szCfgFile[] = "m8b.cfg";

static const char* rgszRegs[] = { "A", "X", "DSP", "PSP", "cs", "ds" };

static const char* rgszShortNames[] = { "M8B", NULL };
static const char* rgszLongNames[]  = { "Cypress enCoRe/M8 USB", NULL };

static uchar rgbyRetCode1[] = { 0x3F };
static uchar rgbyRetCode2[] = { 0x73 };
static uchar rgbyRetCode3[] = { 0x1E };

static bytes_t rgRetCodes[] =
{
    { sizeof(rgbyRetCode1), rgbyRetCode1 },
    { sizeof(rgbyRetCode2), rgbyRetCode2 },
    { sizeof(rgbyRetCode3), rgbyRetCode3 },
    { 0, NULL }
};

typedef struct cfg_entry_t
{
    qstring strName;
    qstring strComment;
    ea_t eaLocation;
}
cfg_entry;

static qvector<cfg_entry> qvEntries;
static qvector<cfg_entry> qvAliases;

static int idaapi notify(processor_t::idp_notify msgid, ...);
static const char* idaapi set_idp_options(const char* szKeyword, int, const void*);
static const char* idaapi parse_area_line(const char* szLine, char* szDeviceParams, size_t cbDeviceParams);
static const char* idaapi parse_area_line0(const char* szLine, char* szDeviceParams, size_t cbDeviceParams);
static const char *idaapi parse_callback(const ioport_t* , size_t, const char* szLine);
static bool parse_config_file();
static void set_device_name(const char* szName);
static void setup_device();
static void create_mappings();
static inline ea_t map_addr(ea_t ea, const char* szSegmentName);

segment_t* segROM() { return get_segm_by_name(SEGNAME_ROM); }
segment_t* segRAM() { return get_segm_by_name(SEGNAME_RAM); }
segment_t* segIOP() { return get_segm_by_name(SEGNAME_IOP); }
ea_t toROM(ea_t ea) { return map_addr(ea, SEGNAME_ROM); }
ea_t toRAM(ea_t ea) { return map_addr(ea, SEGNAME_RAM); }
ea_t toIOP(ea_t ea) { return map_addr(ea, SEGNAME_IOP); }

const char* get_port_sym(ea_t eaPort)
{
  const ioport_t* pPort = find_ioport(pIOPorts, nIOPorts, eaPort);
  return pPort ? pPort->name : NULL;
}

const char* get_portbit_sym(ea_t eaPort, size_t nBit)
{
  const ioport_bit_t* pBit = find_ioport_bit(pIOPorts, nIOPorts, eaPort, nBit);
  return pBit ? pBit->name : NULL;
}

bool get_portbits_sym(char szSym[MAXSTR], ea_t eaPort, size_t nMask)
{
    size_t nBit;
    const char* szName;
    char szNumber[MAX_NUMBUF];

    *szSym = '\0';

    for (nBit = 0; nMask && nBit < 32; ++nBit)
    {
        if (nMask & (0x1 << nBit))
        {
            szName = get_portbit_sym(eaPort, nBit);
            if (szName)
            {
                nMask &= ~(0x1 << nBit);
                if (*szSym) qstrncat(szSym, "|", MAXSTR);
                qstrncat(szSym, szName, MAXSTR);
            }
        }
    }

    if (nMask && *szSym)
    {
        qsnprintf(szNumber, sizeof(szNumber), "|%0.2Xh", nMask);
        qstrncat(szSym, szNumber, MAXSTR);
    }

    return *szSym != '\0';
}

bool is_port_sym(const char* szName)
{
    size_t i, j;
    const ioport_t* pPort;
    const ioport_bit_t* pBit;

    for (i = 0; i < nIOPorts; ++i)
    {
        pPort = pIOPorts + i;

        if (!qstrcmp(pPort->name, szName))
            return true;

        if (pPort->bits)
        {
            for (j = 0; j < sizeof(ioport_bits_t)/sizeof(ioport_bit_t); ++j)
            {
                pBit = (*pPort->bits) + j;

                if (pBit->name && !qstrcmp(pBit->name, szName))
                    return true;
            }
        }
    }

    return false;
}

static int idaapi notify(processor_t::idp_notify msgid, ...)
{
    int code;
    segment_t* pSegment;
    va_list va;
    va_start(va, msgid);

    code = invoke_callbacks(HT_IDP, msgid, va);
    if (code) return code;

    switch (msgid)
    {
    case processor_t::init:
        helper.create("$ m8b");
        break;

    case processor_t::term:
        free_ioports(pIOPorts, nIOPorts);
        break;

    case processor_t::newfile:
        pSegment = get_first_seg();
        if (pSegment)
        {
            set_segm_name(pSegment, SEGNAME_ROM);
            helper.altset(-1, pSegment->startEA);
        }
        setup_device();
        create_mappings();
        break;

    case processor_t::oldfile:
        if (helper.supval(-1, szDevice, sizeof(szDevice)) > 0 )
            set_device_name(szDevice);
        break;

    case processor_t::is_sane_insn:
        return is_sane_insn(va_arg(va, int));
    }

    va_end(va);

    return 1;
}

static const char* idaapi set_idp_options(const char* szKeyword, int, const void*)
{
    if (szKeyword) return IDPOPT_BADKEY;
    setup_device();
    return IDPOPT_OK;
}

static const char* idaapi parse_area_line0(const char* szLine, char* szDeviceParams, size_t cbDeviceParams)
{
    parse_area_line(szLine, szDeviceParams, cbDeviceParams);
    return NULL;
}

static const char* idaapi parse_area_line(const char* szLine, char* szDeviceParams, size_t cbDeviceParams)
{
    char szSegmentName[MAXSTR], szSegmentClass[MAXSTR];
    ea_t eaFrom, eaTo;
    size_t size;

    if (sscanf(szLine, "area %s %s %" FMT_EA "i:%" FMT_EA "i", szSegmentClass, szSegmentName, &eaFrom, &eaTo) == 4)
    {
        cbROM = cbRAM = 0;

        qsscanf(szDeviceParams, DEVICEPARAMS, &cbROM, &cbRAM);
        size = (size_t)(eaTo - eaFrom);

        if (stristr(szSegmentName, SEGNAME_ROM)) cbROM += size;
        else if (stristr(szSegmentName, SEGNAME_RAM)) cbRAM += size;

        if (cbROM || cbRAM)
            qsnprintf(szDeviceParams, cbDeviceParams, DEVICEPARAMS, cbROM, cbRAM);
        else
            szDeviceParams[0] = '\0';

        return NULL;
    }

    return "syntax error";
}

static const char *idaapi parse_callback(const ioport_t* , size_t, const char* szLine)
{
    cfg_entry entry;
    char szId[MAXSTR];
    const char* szComment;
    ea_t ea;
    size_t cch;

    if (qsscanf(szLine, "entry %s %" FMT_EA "i%n", szId, &ea, &cch) == 2)
    {
        szComment = skipSpaces(szLine + cch);
        entry.strName = szId;
        entry.strComment = *szComment ? szComment : "";
        entry.eaLocation = ea;
        qvEntries.push_back(entry);
        return NULL;
    }

    if (qsscanf(szLine, "alias %s %" FMT_EA "i%n", szId, &ea, &cch) == 2)
    {
        szComment = skipSpaces(szLine + cch);
        entry.strName = szId;
        entry.strComment = *szComment ? szComment : "";
        entry.eaLocation = ea;
        qvAliases.push_back(entry);
        return NULL;
    }

    return parse_area_line(szLine, szDeviceParams, sizeof(szDeviceParams));
}

static bool parse_config_file()
{
    char szPath[QMAXPATH];

    if (!qstrcmp(szDevice, NONEPROC))
        return true;

    if (!getsysfile(szPath, sizeof(szPath), szCfgFile, CFG_SUBDIR))
    {
        warning("ICON ERROR\nCan not open %s, I/O port definitions are not loaded", szCfgFile);
        return false;
    }

    szDeviceParams[0] = '\0';

    free_ioports(pIOPorts, nIOPorts);
    qvEntries.clear();
    qvAliases.clear();
    pIOPorts = read_ioports(&nIOPorts, szPath, szDevice, sizeof(szDevice), parse_callback);

    return true;
}

static void set_device_name(const char* szName)
{
    if (szName)
    {
        qstrncpy(szDevice, szName, sizeof(szDevice));
        helper.supset(-1, szDevice);
    }
}

static void setup_device()
{
    segment_t* pSegment;
    ea_t ea;

    if (!choose_ioport_device(szCfgFile, szDevice, sizeof(szDevice), parse_area_line0))
        return;

    set_device_name(szDevice);
    parse_config_file();

    if (!get_first_seg())
        return;

    noUsed(0, BADADDR);

    pSegment = getseg(helper.altval(-1));
    if (!pSegment) pSegment = get_first_seg();

    if (pSegment)
    {
        if (pSegment->size() > cbROM)
            warning("The input file is bigger than the ROM size of the current device");

        set_segm_end(pSegment->startEA, pSegment->startEA + cbROM, SEGMOD_KILL);
        set_segm_name(pSegment, SEGNAME_ROM);
    }

    pSegment = segRAM();
    if (!pSegment && cbRAM)
    {
        ea = (inf.maxEA + 0xFFFFF) & ~0xFFFFF;
        add_segm(ea >> 4, ea, ea + cbRAM, SEGNAME_RAM, "DATA");
        pSegment = getseg(ea);
    }

    if (pSegment)
    {
        ea = pSegment->startEA;
        set_default_dataseg(pSegment->sel);
        set_segm_end(ea, ea + cbRAM, SEGMOD_KILL);
    }

    pSegment = segIOP();
    if (!pSegment)
    {
        ea = (inf.maxEA + 0xFFFFF) & ~0xFFFFF;
        add_segm(ea >> 4, ea, ea + 0x100, SEGNAME_IOP, "XTRN");
        pSegment = getseg(ea);
    }

    if (pSegment)
    {
        ea = pSegment->startEA;
        set_segm_end(ea, ea + 0x100, SEGMOD_KILL);
    }
}

static void create_mappings()
{
    char szComment[MAXSTR];
    segment_t* pSegment;
    ioport_t* pPort;
    ea_t ea;
    uint8 opcode;
    bool fJmp0, fJmp1;
    size_t i;

    pSegment = segROM();
    if (pSegment)
    {
        for (i = 0; i < qvEntries.size(); ++i)
        {
            ea = toEA(pSegment->sel, qvEntries[i].eaLocation);

            if (isEnabled(ea))
            {
                fJmp1 = true;

                opcode = get_byte(ea);
                fJmp0 = opcode >= 0x80 && opcode <= 0x8F;
                if (ea >= get_segm_base(pSegment) + 2)
                {
                    opcode = get_byte(ea - 2);
                    fJmp1 = opcode >= 0x80 && opcode <= 0x8F;
                }

                if (fJmp0) create_insn(ea);

                if (fJmp1)
                    helper.altset(ea, 1);
                else if (fJmp0)
                    ea = get_first_fcref_from(ea);
                else
                    ea = BADADDR;

                if (ea != BADADDR)
                {
                    add_entry(ea, ea, qvEntries[i].strName.c_str(), true);
                    if (!qvEntries[i].strComment.empty()) set_cmt(ea, qvEntries[i].strComment.c_str(), false);
                }
            }
        }
    }

    pSegment = segRAM();
    if (pSegment)
    {
        for (i = 0; i < qvAliases.size(); ++i)
        {
            ea = toEA(pSegment->sel, qvAliases[i].eaLocation);
            if (isEnabled(ea))
            {
                set_name(ea, qvAliases[i].strName.c_str(), SN_NOWARN);
                if (!qvAliases[i].strComment.empty()) set_cmt(ea, qvAliases[i].strComment.c_str(), false);
            }
        }
    }

    pSegment = segIOP();
    if (pSegment)
    {
        for (i = 0; i < nIOPorts; ++i)
        {
            pPort = pIOPorts + i;
            ea = toEA(pSegment->sel, pPort->address);
            if (isEnabled(ea))
            {
                set_name(ea, pPort->name, SN_NOWARN);
                if (pPort->cmt)
                {
                    qsnprintf(szComment, sizeof(szComment), "%0.2Xh/%u %s", pPort->address, pPort->address, pPort->cmt);
                    set_cmt(ea, szComment, false);
                }
            }
        }
    }
}

static inline ea_t map_addr(ea_t ea, const char* szSegmentName)
{
    if (!szSegmentName) return BADADDR;
    segment_t* pSegment = get_segm_by_name(szSegmentName);
    if (!pSegment) return BADADDR;
    return toEA(pSegment->sel, ea);
}

//-----------------------------------------------------------------------
//           CYASM assembler
//-----------------------------------------------------------------------
static asm_t cyasm =
{
    AS_COLON|AS_N2CHR|ASH_HEXF0|ASD_DECF0|ASB_BINF0|AS_ONEDUP,
    0,
    "CYASM Assembler",
    0,
    NULL,         // header lines
    NULL,         // no bad instructions
    "ORG",        // org
    NULL,         // end
    ";",          // comment string
    '"',          // string delimiter
    '\'',         // char delimiter
    "\"'",        // special symbols in char and string constants
    "DS",         // ascii string directive
    "DB",         // byte directive
    "DW",         // word directive
    NULL,         // double words
    NULL,         // no qwords
    NULL,         // oword  (16 bytes)
    NULL,         // float  (4 bytes)
    NULL,         // double (8 bytes)
    NULL,         // tbyte  (10/12 bytes)
    NULL,         // packed decimal real
    NULL,         // arrays (#h,#d,#v,#s(...)
    "BLKB %s",    // uninited arrays
    NULL,         // equ
    NULL,         // 'seg' prefix (example: push seg seg001)
    NULL,         // Pointer to checkarg_preline() function.
    NULL,         // char *(*checkarg_atomprefix)(char *operand,void *res); // if !NULL, is called before each atom
    NULL,         // const char **checkarg_operations;
    NULL,         // translation to use in character and string constants.
    NULL,         // current IP (instruction pointer)
    NULL,         // func_header
    NULL,         // func_footer
    NULL,         // "public" name keyword
    NULL,         // "weak"   name keyword
    ";",          // "extrn"  name keyword
    NULL,         // "comm" (communal variable)
    NULL,         // get_type_name
    NULL,         // "align" keyword
    '(', ')',     // lbrace, rbrace
    NULL,         // mod
    "&",          // and
    "|",          // or
    "^",          // xor
    "~",          // not
    "<<",         // shl
    ">>",         // shr
    NULL,         // sizeof
};

static asm_t *rgAssembler[] = { &cyasm, NULL };

//-----------------------------------------------------------------------
//      Cypress enCoRe/M8 processor definition
//-----------------------------------------------------------------------
processor_t LPH =
{
    IDP_INTERFACE_VERSION,
    PLFM_M8B,                   // id
    PRN_HEX|PR_BINMEM|PR_NO_SEGMOVE|PR_RNAMESOK,
    8,                          // 8 bits in a byte for code segments
    8,                          // 8 bits in a byte for other segments
    rgszShortNames,
    rgszLongNames,
    rgAssembler,
    notify,
    header,
    footer,
    segstart,
    std_gen_segm_footer,
    NULL,                       // assumes
    ana,
    emu,
    out,
    outop,
    intel_data,
    NULL,                       // int  (*cmp_opnd)(op_t &op1,op_t &op2);
                                // returns 1 - equal operands
    can_have_type,              // returns 1 - operand can have
                                // a user-defined type
    qnumber(rgszRegs),          // number of registers
    rgszRegs,
    NULL,
    0,
    NULL,
    NULL,
    NULL,
    rVcs,                       // first
    rVds,                       // last
    0,                          // size of a segment register
    rVcs, rVds,
    NULL,                       // No known code start sequences
    rgRetCodes,                 // 'Return' instruction codes
    M8B_null,
    M8B_last,
    rgInstructions,
    NULL,                       // int  (*is_far_jump)(int icode);
    NULL,                       // Translation function for offsets
    0,                          // int tbyte_size;
    NULL,                       // int (*realcvt)(void *m, ushort *e, ushort swt);
    { 0, 0, 0, 0 },             // char real_width[4];
                                // number of symbols after decimal point
                                // 2byte float (0-does not exist)
                                // normal float
                                // normal double
                                // long double
    NULL,                       // int (*is_switch)(switch_info_t *si);
    NULL,                       // long (*gen_map_file)(FILE *fp);
    NULL,                       // ea_t (*extract_address)(ea_t ea,const char *string,int x);
    NULL,                       // int (*is_sp_based)(op_t &x);
    NULL,                       // int (*create_func_frame)(func_t *pfn);
    NULL,                       // int (*get_frame_retsize(func_t *pfn)
    NULL,                       // void (*gen_stkvar_def)(char *buf,const member_t *mptr,sval_t v);
    gen_spcdef,                 // Generate text representation of an item in a special segment
    M8B_RET,                    // Icode of return instruction. It is ok to give any of possible return instructions
    set_idp_options,            // const char *(*set_idp_options)(const char *keyword,int value_type,const void *value);
    is_align_insn,              // int (*is_align_insn)(ea_t ea);
    NULL,                       // mvm_t *mvm;
};

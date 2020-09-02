module het.opencl;

public import het.utils;
import std.traits, core.sys.windows.windows;

//todo: profiling ezzel -> clGetEventProfilingInfo
//todo: opencl errorokat megmutatni a beagyazott forrasban pont ugy, mint gcnasm-nal
//todo: clCreateCommandQueue is deprecated. It is suggested that "clCreateCommandQueueWithProperties" is used instead.
//todo: gcn // comment kezeles
//todo: vDIn[6*16] -> ezt egye meg a regPool alloc!

//todo: gprs allocator
/+
immutable gprsTestSrc = q{
  scalar{
    /* comment */
    sTmp0 = %s0;
    sTmp1 = %s1;
    ulong sUserSGPR = %s[4:5];
    uint sWFID = %s6;
    ulong sBuf0, sBuf1, sBuf2, sCodeBase;
    uint sLoopIdx, s_1000193;
    ucent sRSRC;
    ulong sRet0, sRoutine0;

    uint[8] sParams0;

    sCmd          = %sParams0[0]
    sLoopCnt      = %sParams0[1]
    sDummy2       = %sParams0[2]
    sDummy3       = %sParams0[3]

    sDagCnt       = %sParams0[4]
    sInvDagCnt    = %sParams0[5]
    sDummy6       = %sParams0[6]
    sDummy7       = %sParams0[7]
  }

  vector uint GID = %v0, vTmp0;
  vector:
    uint GID = %v0, vTmp0;
    ulong vAddr;

    uint v_193, vRnd, vTmp1, vAddTIDAdjust;

    uint[32] vMix;
    uint vS0, vDagBaseOfs;
    uint[4] vDagData, vDagTmp, vDagIdx;
};

struct GprsParserAttr{

  bool isV, isS;
  int align_=-1;
}

void parseGprsAllocations(string src){
  import hetlib.tokenizer;

  Token[] tokens;
  auto err = tokenize("", src, tokens);
  enforce(err.empty, "GRPS Allocator parser error: "~err);

  tokes = tokens.filter!"!isComment".array;

  //tokens.each!writeln;

  GprsParserAttrs[] attrList;

  while(!tokens.empty){
    ref t(){ return tokens[0]; }

    void processAttr(){

    }

    if(t.isComment){
      //nothing
    }else if(t.isIdentifier){
      if(t.source=="vector") attr('v'); else
      if(t.source=="scalar") attr('s'); else
      if(t.source=="align") attr('a'); else

    }

    }else if(t.isIdentifier("scalar")){

    t.writeln;
    tokens = tokens[1..$];
  }



  tokens.each!writeln;
}
+/


immutable
  gcnBeginMarker = "s_cmp_eq_u32 s0, 0x377d739e;",
  gcnEndMarker   = "s_cmp_eq_u32 s0, 0x377d739f;";

const string gcnPrototypeCode20 = q{
.amdcl2
.arch GCN1.2
.64bit
.kernel kernel1
  .config
    .dims x
    .cws 64, 1, 1
    .sgprsnum 13
    .vgprsnum 5
    .floatmode 0xc0  /* c1 for x86 compatible float mode */
    .dx10clamp
    .ieeemode
    .priority 0
    .useargs
    .arg _.global_offset_0, "size_t", long
    .arg _.global_offset_1, "size_t", long
    .arg _.global_offset_2, "size_t", long
    .arg _.printf_buffer, "size_t", void*, global, , rdonly
    .arg _.vqueue_pointer, "size_t", long
    .arg _.aqlwrap_pointer, "size_t", long
    .arg a1, "int*", int*, global,
    .arg cb, "int*", int*, constant, const, rdonly
  .text
    s_lshl_b32      s0, s6, 6              /*s6:WFID*/
    v_add_u32       v0, vcc, s0, v0        /*v0:GID base*/
    s_load_dwordx2  s[0:1], s[4:5], 0x0    /*s0: ndrange.base, s1 is never used*/
    s_load_dwordx4  s[4:7], s[4:5], 0x30   /*s[4:5]: a1,  s[6:7]: cb*/
    s_waitcnt       lgkmcnt(0)

    v_add_u32       v1, s[2:3], v0, s0     /*s[2:3] never used    GID = GID.base+ndRange.base*/
    v_mov_b32       v0, 0
    v_ashrrev_i64   v[0:1], 30, v[0:1]     /* v[0:1] = (GID.base+ndRange.base)<<2 */

    v_add_u32       v2, vcc, s6, v0
    v_mov_b32       v3, s7
    v_addc_u32      v3, vcc, v3, v1, vcc  /* v[2:3] = s[6:7]+v[0:1] */

    v_add_u32       v0, vcc, s4, v0
    v_mov_b32       v4, s5
    v_addc_u32      v1, vcc, v4, v1, vcc   /*v[0:1] += s[4:5] address of a1[gid]*/

    flat_load_dword v2, v[2:3]             /*load cb*/
    flat_load_dword v3, v[0:1]             /*load a1*/
    s_waitcnt       vmcnt(0) & lgkmcnt(0)
    v_add_u32       v2, vcc, v3, v2        /*a1[gid] + cb[gid]*/
    flat_store_dword v[0:1], v2
    s_endpgm
};

// Types /////////////////////////////////////////////////

class OpenCL_error:Exception { //todo: update this with line info
  this(string s){ super(s); }
}

alias cl_platform_id    = Typedef!(void*, null, "cl_platform_id"  );
alias cl_device_id      = Typedef!(void*, null, "cl_device_id"    );
alias cl_context        = Typedef!(void*, null, "cl_context"      );
alias cl_command_queue  = Typedef!(void*, null, "cl_command_queue");
alias cl_mem            = Typedef!(void*, null, "cl_mem"          );
alias cl_program        = Typedef!(void*, null, "cl_program"      );
alias cl_kernel         = Typedef!(void*, null, "cl_kernel"       );
alias cl_event          = Typedef!(void*, null, "cl_event"        );
alias cl_sampler        = Typedef!(void*, null, "cl_sampler"      );

alias cl_bool                     = uint;
alias cl_bitfield                 = ulong;
alias cl_device_type              = cl_bitfield;
alias cl_device_fp_config         = cl_bitfield;
alias cl_device_exec_capabilities = cl_bitfield;
alias cl_command_queue_properties = cl_bitfield;
alias cl_context_properties       = int*;
alias cl_mem_flags                = cl_bitfield;
alias cl_map_flags                = cl_bitfield;
alias cl_build_status             = int;
//all other types are uints

struct cl_image_format { align(1): uint image_channel_order, image_channel_data_type; }
struct cl_buffer_region{ align(1): size_t origin, size; }

// Enums ////////////////////////////////////////////////

enum{// Error Codes
  CL_SUCCESS                                   = 0,
  CL_DEVICE_NOT_FOUND                          = -1,
  CL_DEVICE_NOT_AVAILABLE                      = -2,
  CL_DEVICE_COMPILER_NOT_AVAILABLE             = -3,
  CL_MEM_OBJECT_ALLOCATION_FAILURE             = -4,
  CL_OUT_OF_RESOURCES                          = -5,
  CL_OUT_OF_HOST_MEMORY                        = -6,
  CL_PROFILING_INFO_NOT_AVAILABLE              = -7,
  CL_MEM_COPY_OVERLAP                          = -8,
  CL_IMAGE_FORMAT_MISMATCH                     = -9,
  CL_IMAGE_FORMAT_NOT_SUPPORTED                = -10,
  CL_BUILD_PROGRAM_FAILURE                     = -11,
  CL_MAP_FAILURE                               = -12,
  CL_MISALIGNED_SUB_BUFFER_OFFSET              = -13,
  CL_EXEC_STATUS_ERROR_FOR_EVENTS_IN_WAIT_LIST = -14,
  CL_INVALID_VALUE                             = -30,
  CL_INVALID_DEVICE_TYPE                       = -31,
  CL_INVALID_PLATFORM                          = -32,
  CL_INVALID_DEVICE                            = -33,
  CL_INVALID_CONTEXT                           = -34,
  CL_INVALID_QUEUE_PROPERTIES                  = -35,
  CL_INVALID_COMMAND_QUEUE                     = -36,
  CL_INVALID_HOST_PTR                          = -37,
  CL_INVALID_MEM_OBJECT                        = -38,
  CL_INVALID_IMAGE_FORMAT_DESCRIPTOR           = -39,
  CL_INVALID_IMAGE_SIZE                        = -40,
  CL_INVALID_SAMPLER                           = -41,
  CL_INVALID_BINARY                            = -42,
  CL_INVALID_BUILD_OPTIONS                     = -43,
  CL_INVALID_PROGRAM                           = -44,
  CL_INVALID_PROGRAM_EXECUTABLE                = -45,
  CL_INVALID_KERNEL_NAME                       = -46,
  CL_INVALID_KERNEL_DEFINITION                 = -47,
  CL_INVALID_KERNEL                            = -48,
  CL_INVALID_ARG_INDEX                         = -49,
  CL_INVALID_ARG_VALUE                         = -50,
  CL_INVALID_ARG_SIZE                          = -51,
  CL_INVALID_KERNEL_ARGS                       = -52,
  CL_INVALID_WORK_DIMENSION                    = -53,
  CL_INVALID_WORK_GROUP_SIZE                   = -54,
  CL_INVALID_WORK_ITEM_SIZE                    = -55,
  CL_INVALID_GLOBAL_OFFSET                     = -56,
  CL_INVALID_EVENT_WAIT_LIST                   = -57,
  CL_INVALID_EVENT                             = -58,
  CL_INVALID_OPERATION                         = -59,
  CL_INVALID_GL_OBJECT                         = -60,
  CL_INVALID_BUFFER_SIZE                       = -61,
  CL_INVALID_MIP_LEVEL                         = -62,
  CL_INVALID_GLOBAL_WORK_SIZE                  = -63,
  CL_INVALID_PROPERTY                          = -64,}

enum{// cl_bool
  CL_FALSE = 0,
  CL_TRUE  = 1,}

enum{// cl_platform_info
  CL_PLATFORM_PROFILE    = 0x0900,
  CL_PLATFORM_VERSION    = 0x0901,
  CL_PLATFORM_NAME       = 0x0902,
  CL_PLATFORM_VENDOR     = 0x0903,
  CL_PLATFORM_EXTENSIONS = 0x0904,}

enum{// cl_device_type - bitfield
  CL_DEVICE_TYPE_DEFAULT     = 1 << 0,
  CL_DEVICE_TYPE_CPU         = 1 << 1,
  CL_DEVICE_TYPE_GPU         = 1 << 2,
  CL_DEVICE_TYPE_ACCELERATOR = 1 << 3,
  CL_DEVICE_TYPE_ALL         = 0xFFFFFFFF,}

enum{// cl_device_info
  CL_DEVICE_TYPE_INFO                     = 0x1000, // CL_DEVICE_TYPE
  CL_DEVICE_VENDOR_ID                     = 0x1001,
  CL_DEVICE_MAX_COMPUTE_UNITS             = 0x1002,
  CL_DEVICE_MAX_WORK_ITEM_DIMENSIONS      = 0x1003,
  CL_DEVICE_MAX_WORK_GROUP_SIZE           = 0x1004,
  CL_DEVICE_MAX_WORK_ITEM_SIZES           = 0x1005,
  CL_DEVICE_PREFERRED_VECTOR_WIDTH_CHAR   = 0x1006,
  CL_DEVICE_PREFERRED_VECTOR_WIDTH_SHORT  = 0x1007,
  CL_DEVICE_PREFERRED_VECTOR_WIDTH_INT    = 0x1008,
  CL_DEVICE_PREFERRED_VECTOR_WIDTH_LONG   = 0x1009,
  CL_DEVICE_PREFERRED_VECTOR_WIDTH_FLOAT  = 0x100A,
  CL_DEVICE_PREFERRED_VECTOR_WIDTH_DOUBLE = 0x100B,
  CL_DEVICE_MAX_CLOCK_FREQUENCY           = 0x100C,
  CL_DEVICE_ADDRESS_BITS                  = 0x100D,
  CL_DEVICE_MAX_READ_IMAGE_ARGS           = 0x100E,
  CL_DEVICE_MAX_WRITE_IMAGE_ARGS          = 0x100F,
  CL_DEVICE_MAX_MEM_ALLOC_SIZE            = 0x1010,
  CL_DEVICE_IMAGE2D_MAX_WIDTH             = 0x1011,
  CL_DEVICE_IMAGE2D_MAX_HEIGHT            = 0x1012,
  CL_DEVICE_IMAGE3D_MAX_WIDTH             = 0x1013,
  CL_DEVICE_IMAGE3D_MAX_HEIGHT            = 0x1014,
  CL_DEVICE_IMAGE3D_MAX_DEPTH             = 0x1015,
  CL_DEVICE_IMAGE_SUPPORT                 = 0x1016,
  CL_DEVICE_MAX_PARAMETER_SIZE            = 0x1017,
  CL_DEVICE_MAX_SAMPLERS                  = 0x1018,
  CL_DEVICE_MEM_BASE_ADDR_ALIGN           = 0x1019,
  CL_DEVICE_MIN_DATA_TYPE_ALIGN_SIZE      = 0x101A,
  CL_DEVICE_SINGLE_FP_CONFIG              = 0x101B,
  CL_DEVICE_GLOBAL_MEM_CACHE_TYPE         = 0x101C,
  CL_DEVICE_GLOBAL_MEM_CACHELINE_SIZE     = 0x101D,
  CL_DEVICE_GLOBAL_MEM_CACHE_SIZE         = 0x101E,
  CL_DEVICE_GLOBAL_MEM_SIZE               = 0x101F,
  CL_DEVICE_MAX_CONSTANT_BUFFER_SIZE      = 0x1020,
  CL_DEVICE_MAX_CONSTANT_ARGS             = 0x1021,
  CL_DEVICE_LOCAL_MEM_TYPE_INFO           = 0x1022, // CL_DEVICE_LOCAL_MEM_TYPE
  CL_DEVICE_LOCAL_MEM_SIZE                = 0x1023,
  CL_DEVICE_ERROR_CORRECTION_SUPPORT      = 0x1024,
  CL_DEVICE_PROFILING_TIMER_RESOLUTION    = 0x1025,
  CL_DEVICE_ENDIAN_LITTLE                 = 0x1026,
  CL_DEVICE_AVAILABLE                     = 0x1027,
  CL_DEVICE_COMPILER_AVAILABLE            = 0x1028,
  CL_DEVICE_EXECUTION_CAPABILITIES        = 0x1029,
  CL_DEVICE_QUEUE_PROPERTIES              = 0x102A,
  CL_DEVICE_NAME                          = 0x102B,
  CL_DEVICE_VENDOR                        = 0x102C,
  CL_DRIVER_VERSION                       = 0x102D,
  CL_DEVICE_PROFILE                       = 0x102E,
  CL_DEVICE_VERSION                       = 0x102F,
  CL_DEVICE_EXTENSIONS                    = 0x1030,
  CL_DEVICE_PLATFORM                      = 0x1031,
  CL_DEVICE_PREFERRED_VECTOR_WIDTH_HALF   = 0x1034,
  CL_DEVICE_HOST_UNIFIED_MEMORY           = 0x1035,
  CL_DEVICE_NATIVE_VECTOR_WIDTH_CHAR      = 0x1036,
  CL_DEVICE_NATIVE_VECTOR_WIDTH_SHORT     = 0x1037,
  CL_DEVICE_NATIVE_VECTOR_WIDTH_INT       = 0x1038,
  CL_DEVICE_NATIVE_VECTOR_WIDTH_LONG      = 0x1039,
  CL_DEVICE_NATIVE_VECTOR_WIDTH_FLOAT     = 0x103A,
  CL_DEVICE_NATIVE_VECTOR_WIDTH_DOUBLE    = 0x103B,
  CL_DEVICE_NATIVE_VECTOR_WIDTH_HALF      = 0x103C,
  CL_DEVICE_OPENCL_C_VERSION              = 0x103D,}

enum{// cl_device_fp_config - bitfield
  CL_FP_DENORM           = 1 << 0,
  CL_FP_INF_NAN          = 1 << 1,
  CL_FP_ROUND_TO_NEAREST = 1 << 2,
  CL_FP_ROUND_TO_ZERO    = 1 << 3,
  CL_FP_ROUND_TO_INF     = 1 << 4,
  CL_FP_FMA              = 1 << 5,
  CL_FP_SOFT_FLOAT       = 1 << 6,}

enum{// cl_device_mem_cache_type
  CL_NONE             = 0x0,
  CL_READ_ONLY_CACHE  = 0x1,
  CL_READ_WRITE_CACHE = 0x2,}

enum{// cl_device_local_mem_type
  CL_LOCAL  = 0x1,
  CL_GLOBAL = 0x2,}

enum{// cl_device_exec_capabilities - bitfield
  CL_EXEC_KERNEL        = 1 << 0,
  CL_EXEC_NATIVE_KERNEL = 1 << 1,}

enum{// cl_command_queue_properties - bitfield
  CL_QUEUE_OUT_OF_ORDER_EXEC_MODE_ENABLE = 1 << 0,
  CL_QUEUE_PROFILING_ENABLE              = 1 << 1,}

enum{// cl_context_info
  CL_CONTEXT_REFERENCE_COUNT = 0x1080,
  CL_CONTEXT_DEVICES         = 0x1081,
  CL_CONTEXT_PROPERTIES_INFO = 0x1082, // CL_CONTEXT_PROPERTIES
  CL_CONTEXT_NUM_DEVICES     = 0x1083,}

enum{// cl_context_properties
  CL_CONTEXT_PLATFORM_INFO  = 0x1084,} // CL_CONTEXT_PLATFORM

enum{// cl_command_queue_info
  CL_QUEUE_CONTEXT         = 0x1090,
  CL_QUEUE_DEVICE          = 0x1091,
  CL_QUEUE_REFERENCE_COUNT = 0x1092,
  CL_QUEUE_PROPERTIES      = 0x1093,}

enum{// cl_mem_flags - bitfield
  CL_MEM_READ_WRITE     = 1 << 0,
  CL_MEM_WRITE_ONLY     = 1 << 1,
  CL_MEM_READ_ONLY      = 1 << 2,
  CL_MEM_USE_HOST_PTR   = 1 << 3,
  CL_MEM_ALLOC_HOST_PTR = 1 << 4,
  CL_MEM_COPY_HOST_PTR  = 1 << 5,}

enum{// cl_channel_order
  CL_R         = 0x10B0,
  CL_A         = 0x10B1,
  CL_RG        = 0x10B2,
  CL_RA        = 0x10B3,
  CL_RGB       = 0x10B4,
  CL_RGBA      = 0x10B5,
  CL_BGRA      = 0x10B6,
  CL_ARGB      = 0x10B7,
  CL_INTENSITY = 0x10B8,
  CL_LUMINANCE = 0x10B9,
  CL_Rx        = 0x10BA,
  CL_RGx       = 0x10BB,
  CL_RGBx      = 0x10BC,}

enum{// cl_channel_type
  CL_SNORM_INT8       = 0x10D0,
  CL_SNORM_INT16      = 0x10D1,
  CL_UNORM_INT8       = 0x10D2,
  CL_UNORM_INT16      = 0x10D3,
  CL_UNORM_SHORT_565  = 0x10D4,
  CL_UNORM_SHORT_555  = 0x10D5,
  CL_UNORM_INT_101010 = 0x10D6,
  CL_SIGNED_INT8      = 0x10D7,
  CL_SIGNED_INT16     = 0x10D8,
  CL_SIGNED_INT32     = 0x10D9,
  CL_UNSIGNED_INT8    = 0x10DA,
  CL_UNSIGNED_INT16   = 0x10DB,
  CL_UNSIGNED_INT32   = 0x10DC,
  CL_HALF_FLOAT       = 0x10DD,
  CL_FLOAT_TYPE       = 0x10DE,}

enum{// cl_mem_object_type
  CL_MEM_OBJECT_BUFFER  = 0x10F0,
  CL_MEM_OBJECT_IMAGE2D = 0x10F1,
  CL_MEM_OBJECT_IMAGE3D = 0x10F2,}

enum{// cl_mem_info
  CL_MEM_TYPE                 = 0x1100,
  CL_MEM_FLAGS_INFO           = 0x1101,
  CL_MEM_SIZE                 = 0x1102,
  CL_MEM_HOST_PTR             = 0x1103,
  CL_MEM_MAP_COUNT            = 0x1104,
  CL_MEM_REFERENCE_COUNT      = 0x1105,
  CL_MEM_CONTEXT              = 0x1106,
  CL_MEM_ASSOCIATED_MEMOBJECT = 0x1107,
  CL_MEM_OFFSET               = 0x1108,}

enum{// cl_image_info
  CL_IMAGE_FORMAT_INFO  = 0x1110,
  CL_IMAGE_ELEMENT_SIZE = 0x1111,
  CL_IMAGE_ROW_PITCH    = 0x1112,
  CL_IMAGE_SLICE_PITCH  = 0x1113,
  CL_IMAGE_WIDTH        = 0x1114,
  CL_IMAGE_HEIGHT       = 0x1115,
  CL_IMAGE_DEPTH        = 0x1116,}

enum{// cl_addressing_mode
  CL_ADDRESS_NONE            = 0x1130,
  CL_ADDRESS_CLAMP_TO_EDGE   = 0x1131,
  CL_ADDRESS_CLAMP           = 0x1132,
  CL_ADDRESS_REPEAT          = 0x1133,
  CL_ADDRESS_MIRRORED_REPEAT = 0x1134,}

enum{// cl_filter_mode
  CL_FILTER_NEAREST = 0x1140,
  CL_FILTER_LINEAR  = 0x1141,}

enum{// cl_sampler_info
  CL_SAMPLER_REFERENCE_COUNT   = 0x1150,
  CL_SAMPLER_CONTEXT           = 0x1151,
  CL_SAMPLER_NORMALIZED_COORDS = 0x1152,
  CL_SAMPLER_ADDRESSING_MODE   = 0x1153,
  CL_SAMPLER_FILTER_MODE       = 0x1154,}

enum{// cl_map_flags - bitfield
  CL_MAP_READ  = (1 << 0),
  CL_MAP_WRITE = (1 << 1),}

enum{// cl_program_info
  CL_PROGRAM_REFERENCE_COUNT = 0x1160,
  CL_PROGRAM_CONTEXT         = 0x1161,
  CL_PROGRAM_NUM_DEVICES     = 0x1162,
  CL_PROGRAM_DEVICES         = 0x1163,
  CL_PROGRAM_SOURCE          = 0x1164,
  CL_PROGRAM_BINARY_SIZES    = 0x1165,
  CL_PROGRAM_BINARIES        = 0x1166,
  CL_PROGRAM_KERNEL_NAMES    = 4456,}

enum{// cl_program_build_info
  CL_PROGRAM_BUILD_STATUS  = 0x1181,
  CL_PROGRAM_BUILD_OPTIONS = 0x1182,
  CL_PROGRAM_BUILD_LOG     = 0x1183,}

enum{// cl_build_status
  CL_BUILD_SUCCESS     = 0,
  CL_BUILD_NONE        = -1,
  CL_BUILD_ERROR       = -2,
  CL_BUILD_IN_PROGRESS = -3,}

enum{// cl_kernel_info
  CL_KERNEL_FUNCTION_NAME   = 0x1190,
  CL_KERNEL_NUM_ARGS        = 0x1191,
  CL_KERNEL_REFERENCE_COUNT = 0x1192,
  CL_KERNEL_CONTEXT         = 0x1193,
  CL_KERNEL_PROGRAM         = 0x1194,}

enum{// cl_kernel_work_group_info
  CL_KERNEL_WORK_GROUP_SIZE                    = 0x11B0,
  CL_KERNEL_COMPILE_WORK_GROUP_SIZE            = 0x11B1,
  CL_KERNEL_LOCAL_MEM_SIZE                     = 0x11B2,
  CL_KERNEL_PREFERRED_WORK_GROUP_SIZE_MULTIPLE = 0x11B3,
  CL_KERNEL_PRIVATE_MEM_SIZE                   = 0x11B4,}

enum{// cl_event_info
  CL_EVENT_COMMAND_QUEUE            = 0x11D0,
  CL_EVENT_COMMAND_TYPE             = 0x11D1,
  CL_EVENT_REFERENCE_COUNT          = 0x11D2,
  CL_EVENT_COMMAND_EXECUTION_STATUS = 0x11D3,
  CL_EVENT_CONTEXT                  = 0x11D4,}

enum{// cl_command_type
  CL_COMMAND_NDRANGE_KERNEL       = 0x11F0,
  CL_COMMAND_TASK                 = 0x11F1,
  CL_COMMAND_NATIVE_KERNEL        = 0x11F2,
  CL_COMMAND_READ_BUFFER          = 0x11F3,
  CL_COMMAND_WRITE_BUFFER         = 0x11F4,
  CL_COMMAND_COPY_BUFFER          = 0x11F5,
  CL_COMMAND_READ_IMAGE           = 0x11F6,
  CL_COMMAND_WRITE_IMAGE          = 0x11F7,
  CL_COMMAND_COPY_IMAGE           = 0x11F8,
  CL_COMMAND_COPY_IMAGE_TO_BUFFER = 0x11F9,
  CL_COMMAND_COPY_BUFFER_TO_IMAGE = 0x11FA,
  CL_COMMAND_MAP_BUFFER           = 0x11FB,
  CL_COMMAND_MAP_IMAGE            = 0x11FC,
  CL_COMMAND_UNMAP_MEM_OBJECT     = 0x11FD,
  CL_COMMAND_MARKER               = 0x11FE,
  CL_COMMAND_ACQUIRE_GL_OBJECTS   = 0x11FF,
  CL_COMMAND_RELEASE_GL_OBJECTS   = 0x1200,
  CL_COMMAND_READ_BUFFER_RECT     = 0x1201,
  CL_COMMAND_WRITE_BUFFER_RECT    = 0x1202,
  CL_COMMAND_COPY_BUFFER_RECT     = 0x1203,
  CL_COMMAND_USER                 = 0x1204,}

enum{// command execution status
  CL_COMPLETE  = 0x0,
  CL_RUNNING   = 0x1,
  CL_SUBMITTED = 0x2,
  CL_QUEUED    = 0x3,}

enum{// cl_buffer_create_type
  CL_BUFFER_CREATE_TYPE_REGION = 0x1220,}

enum{// cl_profiling_info
  CL_PROFILING_COMMAND_QUEUED = 0x1280,
  CL_PROFILING_COMMAND_SUBMIT = 0x1281,
  CL_PROFILING_COMMAND_START  = 0x1282,
  CL_PROFILING_COMMAND_END    = 0x1283,}

// CL helper functions //////////////////////////////////////////////

private string clErrorStr(int e){ //todo: erre csinalni egy automata formazot
  switch(e){
    default: return format("UNKNOWN(%d)", e);
    case CL_SUCCESS: return "SUCCESS";
    case CL_DEVICE_NOT_FOUND: return "DEVICE_NOT_FOUND";
    case CL_DEVICE_NOT_AVAILABLE: return "DEVICE_NOT_AVAILABLE";
    case CL_DEVICE_COMPILER_NOT_AVAILABLE: return "DEVICE_COMPILER_NOT_AVAILABLE";
    case CL_MEM_OBJECT_ALLOCATION_FAILURE: return "MEM_OBJECT_ALLOCATION_FAILURE";
    case CL_OUT_OF_RESOURCES: return "OUT_OF_RESOURCES";
    case CL_OUT_OF_HOST_MEMORY: return "OUT_OF_HOST_MEMORY";
    case CL_PROFILING_INFO_NOT_AVAILABLE: return "PROFILING_INFO_NOT_AVAILABLE";
    case CL_MEM_COPY_OVERLAP: return "MEM_COPY_OVERLAP";
    case CL_IMAGE_FORMAT_MISMATCH: return "CL_IMAGE_FORMAT_MISMATCH";
    case CL_IMAGE_FORMAT_NOT_SUPPORTED: return "CL_IMAGE_FORMAT_NOT_SUPPORTED";
    case CL_BUILD_PROGRAM_FAILURE: return "BUILD_PROGRAM_FAILURE";
    case CL_MAP_FAILURE: return "MAP_FAILURE";
    case CL_MISALIGNED_SUB_BUFFER_OFFSET: return "MISALIGNED_SUB_BUFFER_OFFSET";
    case CL_EXEC_STATUS_ERROR_FOR_EVENTS_IN_WAIT_LIST: return "EXEC_STATUS_ERROR_FOR_EVENTS_IN_WAIT_LIST";
    case CL_INVALID_VALUE: return "INVALID_VALUE";
    case CL_INVALID_DEVICE_TYPE: return "INVALID_DEVICE_TYPE";
    case CL_INVALID_PLATFORM: return "INVALID_PLATFORM";
    case CL_INVALID_DEVICE: return "INVALID_DEVICE";
    case CL_INVALID_CONTEXT: return "INVALID_CONTEXT";
    case CL_INVALID_QUEUE_PROPERTIES: return "INVALID_QUEUE_PROPERTIES";
    case CL_INVALID_COMMAND_QUEUE: return "INVALID_COMMAND_QUEUE";
    case CL_INVALID_HOST_PTR: return "INVALID_HOST_PTR";
    case CL_INVALID_MEM_OBJECT: return "INVALID_MEM_OBJECT";
    case CL_INVALID_IMAGE_FORMAT_DESCRIPTOR: return "INVALID_IMAGE_FORMAT_DESCRIPTOR";
    case CL_INVALID_IMAGE_SIZE: return "INVALID_IMAGE_SIZE";
    case CL_INVALID_SAMPLER: return "INVALID_SAMPLER";
    case CL_INVALID_BINARY: return "INVALID_BINARY";
    case CL_INVALID_BUILD_OPTIONS: return "INVALID_BUILD_OPTIONS";
    case CL_INVALID_PROGRAM: return "INVALID_PROGRAM";
    case CL_INVALID_PROGRAM_EXECUTABLE: return "INVALID_PROGRAM_EXECUTABLE";
    case CL_INVALID_KERNEL_NAME: return "INVALID_KERNEL_NAME";
    case CL_INVALID_KERNEL_DEFINITION: return "INVALID_KERNEL_DEFINITION";
    case CL_INVALID_KERNEL: return "INVALID_KERNEL";
    case CL_INVALID_ARG_INDEX: return "INVALID_ARG_INDEX";
    case CL_INVALID_ARG_VALUE: return "INVALID_ARG_VALUE";
    case CL_INVALID_ARG_SIZE: return "INVALID_ARG_SIZE";
    case CL_INVALID_KERNEL_ARGS: return "INVALID_KERNEL_ARGS";
    case CL_INVALID_WORK_DIMENSION: return "INVALID_WORK_DIMENSION";
    case CL_INVALID_WORK_GROUP_SIZE: return "INVALID_WORK_GROUP_SIZE";
    case CL_INVALID_WORK_ITEM_SIZE: return "INVALID_WORK_ITEM_SIZE";
    case CL_INVALID_GLOBAL_OFFSET: return "INVALID_GLOBAL_OFFSET";
    case CL_INVALID_EVENT_WAIT_LIST: return "INVALID_EVENT_WAIT_LIST";
    case CL_INVALID_EVENT: return "INVALID_EVENT";
    case CL_INVALID_OPERATION: return "INVALID_OPERATION";
    case CL_INVALID_GL_OBJECT: return "INVALID_GL_OBJECT";
    case CL_INVALID_BUFFER_SIZE: return "INVALID_BUFFER_SIZE";
    case CL_INVALID_MIP_LEVEL: return "INVALID_MIP_LEVEL";
    case CL_INVALID_GLOBAL_WORK_SIZE: return "INVALID_GLOBAL_WORK_SIZE";
    case CL_INVALID_PROPERTY: return "INVALID_PROPERTY";
  }
}

// CL class /////////////////////////////////////////////////////////

//global access for all OpenCL functionality
alias cl = Singleton!CLFuncts;
//Note: clf must not be freed up with a finalizer, because GC can call it from the cl objects.

class CLFuncts{
private: //original opengl api calls, private helpers
  extern(Windows){
    int function(uint, cl_platform_id*, uint*)                                     clGetPlatformIDs;
    int function(const cl_platform_id, cl_device_type, uint, cl_device_id*, uint*) clGetDeviceIDs;
    int function(const cl_device_id, int, size_t, void*, size_t*)                  clGetDeviceInfo;
    int function(const cl_device_id) clReleaseDevice;

    cl_context function(void* properties, size_t num_devices, const cl_device_id*, void* pfn_notify, void* user_data, int* errcode_ret) clCreateContext;

    int function(const cl_context) clReleaseContext;
    cl_command_queue function(const cl_context, const cl_device_id, cl_command_queue_properties, int* errcode_ret) clCreateCommandQueue;
    int function(const cl_command_queue) clReleaseCommandQueue;

    cl_program function(const cl_context, size_t, const cl_device_id*, size_t*, void*, int*, int*) clCreateProgramWithBinary;
    cl_program function(const cl_context, size_t, const(char)**, size_t*, int*) clCreateProgramWithSource;
    int function(const cl_program program, size_t num_devices, const cl_device_id* device_list, char* options, void* pfn_notify, void* user_data) clBuildProgram;
    int function(const cl_program program, const cl_device_id device, int param_name, size_t value_size, char* value, size_t* value_size_ret) clGetProgramBuildInfo;
    int function(const cl_program, int name, size_t value_size, void* value, size_t* value_size_ret) clGetProgramInfo;
    int function(const cl_program) clReleaseProgram;

    cl_kernel function(const cl_program, const char* name, int* err) clCreateKernel;
    int function(const cl_kernel, const cl_device_id, int name, size_t value_size, void* value, size_t* value_size_ret) clGetKernelWorkGroupInfo;
    int function(const cl_kernel, uint, size_t, const void*) clSetKernelArg;
    int function(const cl_command_queue, const cl_kernel, size_t work_dim, const size_t* global_ofs, const size_t* global_size, const size_t* local_size,
                 size_t num_events_in_wait_list, const cl_event* event_wait_list, cl_event* event) clEnqueueNDRangeKernel;
    int function(const cl_kernel) clReleaseKernel;

    cl_mem function(const cl_context, cl_mem_flags, size_t size, void* host_ptr, int* err_ret) clCreateBuffer;

    void* function(const cl_command_queue queue, const cl_mem buffer, cl_bool blocking_map, cl_map_flags,
      size_t offset, size_t cb, size_t num_events_in_wait_list, const cl_event* event_wait_list, cl_event* event, int* errcode_ret) clEnqueueMapBuffer;

    int function(const cl_command_queue, const cl_mem buffer, cl_bool blocking_write,
      size_t offset, size_t cb, const void* ptr, size_t num_events_in_wait_list, const cl_event* event_wait_list, cl_event* event) clEnqueueWriteBuffer;

    int function(const cl_command_queue, const cl_mem, void* mapped_ptr, size_t num_events_in_wait_list, const cl_event* event_wait_list, cl_event* event) clEnqueueUnmapMemObject;
    int function(const cl_mem) clReleaseMemObject;

    int function(const cl_command_queue) clFinish, clFlush;

    int function(const cl_event, int name, size_t size, void* value, size_t* size_ret) clGetEventInfo;
    int function(size_t num_events, const cl_event*) clWaitForEvents;
    int function(const cl_event) clReleaseEvent;
  }

  static void enforce(bool b, lazy string s, string file = __FILE__, int line = __LINE__){ if(!b) throw new Exception("OpenCL error: "~s, file, line); }

  void loadFuncts() //must be called right after it got an active opengl contect
  {
    if(!&clGetPlatformIDs) return; //only if needed

    //tweak environment variables to access all the GPU mem
    ["GPU_MAX_HEAP_SIZE", "GPU_MAX_ALLOC_PERCENT", "GPU_SINGLE_ALLOC_PERCENT"].each!(s => environment[s] = "100");

    enum dllName = "OpenCL.dll";
    auto hModule = loadLibrary(dllName);

    //getProcAddress: works with opengl32.dll exports and also with wgl extensions
    void GPA(T)(ref T func, string name){
      alias t = typeof(func);
      func = cast(t)GetProcAddress(hModule, toStringz(name));
      enforce(func !is null, "getProcAddress fail: "~name);
    }

    //load all the function pointers in this class
    mixin([FieldNameTuple!CLFuncts].filter!(x => x.startsWith("cl"))
                                   .map!(x => `GPA(`~x~`,"`~x~`");` )
                                   .join);
  }
public:
  this(){
    loadFuncts;
  }

  ~this(){
    foreach(ref d; devices_) d.destroy;
    devices_ = [];
  }

  private bool initialized;
  private CLDevice[] devices_; //kell a static, mert kulonben

  CLDevice[] devices(){
    if(chkSet(initialized)){
      foreach(plt; getPlatformIDs(1)){
        auto devs = getDeviceIDs(plt, CL_DEVICE_TYPE_GPU);
        if(!devs.empty){ //got the gpu category
          foreach(idx, id; devs) devices_ ~= new CLDevice(idx.to!int, id);
          devices_ = devices_.sort!"a.info.vendorID<b.info.vendorID".array;
          break;
        }
      }
    }
    return devices_;
  }

  void clChk(string file = __FILE__, int line = __LINE__)(int err){
    if(err) throw new Exception(clErrorStr(err), file, line);
  }

  cl_platform_id[] getPlatformIDs(uint nMax=8){
    auto plts = new cl_platform_id[nMax];  uint n;
    clChk(clGetPlatformIDs(nMax, &plts[0], &n));
    return plts[0..n];
  }

  cl_device_id[] getDeviceIDs(cl_platform_id platform, cl_device_type device_type){
    uint n;
    clChk(clGetDeviceIDs(platform, device_type, 0, null, &n));
    auto devs = new cl_device_id[n];
    if(n) clChk(clGetDeviceIDs(platform, device_type, n, &devs[0], &n));
    return devs;
  }

  void releaseDevice(ref cl_device_id d){ clChk(clReleaseDevice(d));  d = null; }

  auto getDeviceInfo_int (const cl_device_id id, int name) { int        i; clChk(clGetDeviceInfo(id, name, i.sizeof, &i, null)); return i      ; }
  auto getDeviceInfo_long(const cl_device_id id, int name) { long       L; clChk(clGetDeviceInfo(id, name, L.sizeof, &L, null)); return L      ; }
  auto getDeviceInfo_str (const cl_device_id id, int name) { char[4096] s; clChk(clGetDeviceInfo(id, name, s.sizeof, &s, null)); return (&s[0]).toStr; }

  auto createContext(const cl_device_id[] devices){
    int err;
    auto ctx = clCreateContext(null, devices.length, devices.ptr, null, null, &err);
    clChk(err);
    return ctx;
  }
  void releaseContext(ref cl_context ctx){ clChk(clReleaseContext(ctx));  ctx = null; }

  auto createCommandQueue(const cl_context ctx, const cl_device_id id, cl_command_queue_properties props=0){
    int err;
    auto que = clCreateCommandQueue(ctx, id, props, &err);
    clChk(err);
    return que;
  }
  void releaseCommandQueue(ref cl_command_queue que){ clChk(clReleaseCommandQueue(que)); }

  auto createProgramWithBinary(cl_context context, cl_device_id[] devices, const void[] binary, int* binary_status=null){
    int err;
    size_t len = binary.length;
    const(void)* b = binary.ptr;
    auto p = clCreateProgramWithBinary(context, devices.length, devices.ptr, &len, &b, binary_status, &err);
    clChk(err);
    return p;
  }

  auto createProgramWithSource(cl_context ctx, string src){
    int err;
    size_t len = src.length;
    const(char)* s = src.ptr;
    auto p = clCreateProgramWithSource(ctx, 1, &s, &len, &err);
    clChk(err);
    return p;
  }

  void buildProgram(string file=__FILE__, int line=__LINE__)(const cl_program program, cl_device_id[] devices, string options){
    int err = clBuildProgram(program, devices.length, devices.ptr, cast(char*)options.toStringz, null, null);
    if(err==CL_SUCCESS) return;
    if(err==CL_BUILD_PROGRAM_FAILURE){
      string info = getProgramBuildInfo!(file, line)(program, devices[0], CL_PROGRAM_BUILD_LOG);
      enum maxLen = 8192;
      if(info.length>maxLen) info = info[0..maxLen]~"...";
      throw new Exception("CL_BUILD_PROGRAM_FAILURE\r\n"~info, file, line);
    }
    clChk!(file, line)(err);
  }

  string getProgramBuildInfo(string file=__FILE__, int line=__LINE__)(const cl_program program, cl_device_id device, int name){
    size_t len;
    clChk!(file, line)(clGetProgramBuildInfo(program, device, name, 0, null, &len));
    auto buf = new char[len];
    clChk!(file, line)(clGetProgramBuildInfo(program, device, name, buf.length, buf.ptr, &len));
    return buf[0..max(len, 1)-1].to!string;
  }

  string[] getProgramInfo_kernels(const cl_program prg){
    size_t n;
    auto c = new char[0x200];
    clChk(clGetProgramInfo(prg, CL_PROGRAM_KERNEL_NAMES, c.length, c.ptr, &n));
    return c[0..max(n, 1)-1].to!string.split(";");
  }

  string getProgramInfo_binary(const cl_program prg){
    size_t n;
    clChk(clGetProgramInfo(prg, CL_PROGRAM_BINARY_SIZES, n.sizeof, &n, null));
    auto buf = new char[n];
    char* bufp = buf.ptr;
    clChk(clGetProgramInfo(prg, CL_PROGRAM_BINARIES, bufp.sizeof, &bufp, null));
    return buf.to!string;
  }

  void releaseProgram(ref cl_program p){ clChk(clReleaseProgram(p));  p = null; }

  auto createKernel(const  cl_program prg, string name){
    int err;
    auto k = clCreateKernel(prg, name.ptr, &err);
    clChk(err);
    return k;
  }

  size_t getPreferredWorkGroupSize(const cl_kernel kernel, const cl_device_id device){
    size_t[3] a;
    clChk(clGetKernelWorkGroupInfo(kernel, device, CL_KERNEL_COMPILE_WORK_GROUP_SIZE, a.sizeof, &a, null));
    return a[0] ? a[0] : 64;
  }

  void setKernelArg(const cl_kernel kernel, uint idx, size_t size, const void* arg){
    clChk(clSetKernelArg(kernel, idx, size, arg));
  }

  cl_event enqueueNDRangeKernel(const cl_command_queue queue, const cl_kernel kernel, const size_t[] global_ofs, const size_t[] global_size, const size_t[] local_size, const cl_event[] event_wait_list=[]){
    enforce(global_ofs.length==global_size.length && global_ofs.length==local_size.length, "enqueueNDRangeKernel() work dimension mismatch");
    cl_event event;
    clChk(clEnqueueNDRangeKernel(queue, kernel, global_ofs.length, global_ofs.ptr, global_size.ptr, local_size.ptr, event_wait_list.length, event_wait_list.ptr, &event));
    return event;
  }

  cl_event enqueueNDRangeKernel(const cl_command_queue queue, const cl_kernel kernel, size_t global_ofs, size_t global_size, size_t local_size,
                                const cl_event[] event_wait_list=[]){
    return enqueueNDRangeKernel(queue, kernel, [global_ofs], [global_size], [local_size], event_wait_list);
  }

  void releaseKernel(ref cl_kernel k){ clChk(clReleaseKernel(k));  k = null; }

  auto createBuffer(const cl_context ctx, int flags, size_t size, void* host_ptr=null){
    int err;
    auto m = clCreateBuffer(ctx, flags, size, host_ptr, &err);
    clChk(err);
    return m;
  }

  void* enqueueMapBuffer(const cl_command_queue queue, const cl_mem buffer, cl_bool blocking_map, cl_map_flags map_flags, size_t offset, size_t cb,
                         const cl_event[] event_wait_list=[], cl_event* event=null){
    int err;
    auto res = clEnqueueMapBuffer(queue, buffer, blocking_map, map_flags, offset, cb, event_wait_list.length, event_wait_list.ptr, event, &err);
    clChk(err);
    return res;
  }

  void enqueueWriteBuffer(const cl_command_queue queue, const cl_mem buffer, cl_bool blocking_write, size_t offset, size_t cb, const void* ptr,
                          const cl_event[] event_wait_list=[], cl_event* event=null){
    clChk(clEnqueueWriteBuffer(queue, buffer, blocking_write, offset, cb, ptr, event_wait_list.length, event_wait_list.ptr, event));
  }

  void enqueueUnmapMemObject(const cl_command_queue queue, const cl_mem buffer, void* mapped_ptr,
                             const cl_event[] event_wait_list=null, cl_event* event=null){
    clChk(clEnqueueUnmapMemObject(queue, buffer, mapped_ptr, event_wait_list.length, event_wait_list.ptr, event));
  }


  void releaseMemObject(ref cl_mem m){ clChk(clReleaseMemObject(m));  m = null; }

  void finish(cl_command_queue que){ clChk(clFinish(que)); }
  void flush (cl_command_queue que){ clChk(clFlush (que)); }

  int getEventInfo_status(const cl_event event){
    int st;
    clChk(clGetEventInfo(event, CL_EVENT_COMMAND_EXECUTION_STATUS, st.sizeof, &st, null));
    return st;
  }

  void waitForEvents(const cl_event[] events){
    clChk(clWaitForEvents(events.length, events.ptr));
  }

  void releaseEvent(const cl_event event){ clChk(clReleaseEvent(event)); }

  // Test ///////////////////////////////////////////////

  static void _test(){
    "Testing OpenCL wrapper".writeln;
    writefln("Bitness: %s", (void*).sizeof*8);

    auto code = q{
      __kernel __attribute__((reqd_work_group_size(64,1,1)))
      void kernel1(__global int* a1, __constant int* cb){
        int g=get_global_id(0);
        a1[g] += cb[g];
      }
    };

    cl.devices.each!(d => d.info.writeln);
    auto dev      = cl.devices[0];
    auto kernel   = dev.newKernel(code);
    auto binary   = kernel.binary;   //FileName(`c:\dl\a.bin`).write(binary);
    auto kernel2  = dev.newKernel(binary);
    auto asm_     = kernel2.disasm;  //FileName(`c:\dl\a.asm`).write(asm_);
    auto kernel3  = dev.newKernel(asm_);

    const workCount = 1024;
    auto data1 = new int[workCount];  data1[] = 123;
    auto data2 = new int[workCount];  data2[] = 456;

    kernel3.disasm.writeln;
    auto buf1 = dev.newBuffer(workCount*4); buf1.ints[] = data1[];
    auto buf2 = dev.newBuffer(workCount*4); memcpy(buf2.map, data2.ptr, workCount*4);
    buf2.unmap;
    buf1.ints[0] = 1234;
    buf2.ints[] = buf1.ints;
    buf2.write(data2[0], 12);

    kernel3.arg(0, buf1);
    kernel3.arg(1, buf2);

    writeln(buf1.ints[0..10]);
    writeln(buf2.ints[0..10]);

    with(kernel3.run(0, workCount, buf1, buf2)){ waitFor; elapsed_sec.writeln; }

    writeln(buf1.ints[0..10]);
    cl.enforce(buf1.ints[0..10].equal([2468, 246, 246, 579, 246, 246, 246, 246, 246, 246]), "OpenCL test failed");

    "Test completed".writeln;
  }

}


class CLDeviceInfo{ // CLDeviceInfo /////////////////////////
  const{
    CLDevice device;

    string vendor, driverVer, deviceName;
    string[] extensions;
    uint idx, vendorID, computeUnits, coreMHz, cacheKB, memoryMB, maxMemAllocMB, streams;
    float TFlops;
  }

  this(CLDevice device){
    this.device = device;
    auto id()const { return cast(cl_device_id)device.id; }

    auto s(int n){ return cl.getDeviceInfo_str (id, n); }
    auto i(int n){ return cl.getDeviceInfo_int (id, n); }
    auto L(int n){ return cl.getDeviceInfo_long(id, n); }

    idx           = device.idx;
    vendor        = s(CL_DEVICE_VENDOR                  );
    driverVer     = s(CL_DRIVER_VERSION                 );
    deviceName    = s(CL_DEVICE_NAME                    );
    vendorID      = i(CL_DEVICE_VENDOR_ID               );
    computeUnits  = i(CL_DEVICE_MAX_COMPUTE_UNITS       );
    coreMHz       = i(CL_DEVICE_MAX_CLOCK_FREQUENCY     );
    cacheKB       = cast(int)(L(CL_DEVICE_GLOBAL_MEM_CACHE_SIZE)>>10);
    memoryMB      = cast(int)(L(CL_DEVICE_GLOBAL_MEM_SIZE      )>>20);
    maxMemAllocMB = cast(int)(L(CL_DEVICE_MAX_MEM_ALLOC_SIZE   )>>20);
    extensions    = s(CL_DEVICE_EXTENSIONS).split;

    streams       = computeUnits*64;
    TFlops        = coreMHz*streams*2e-6;
  }

  override string toString()const { return format("Idx:%d ID:%x Device: %s  %.2f TFlops  Core:%d MHz  Strm:%d  MEM:%d(%s) MB", idx, vendorID, deviceName, TFlops, coreMHz, streams, memoryMB, maxMemAllocMB); }
}


class CLDevice{ // CLDevice /////////////////////////////////
private:
  int fidx;
  cl_device_id fid;
  cl_context fcontext;
  cl_command_queue fqueue;
  CLDeviceInfo finfo;
public:

  this(int idx, cl_device_id id){
    fidx = idx;
    fid = id;
  }

  @property CLDeviceInfo info(){
    if(finfo is null) finfo = new CLDeviceInfo(this);
    return finfo;
  }

  @property auto id()      { return fid; }
  @property auto idx()     { return fidx; }
  @property auto context() { return fcontext; }
  @property auto queue()   { return fqueue; }

  @property bool active(){ return cast(void*)fcontext !is null; }
  @property active(bool a){
    if(active==a) return;
    if(a){
      fcontext = cl.createContext([id]);
      fqueue = cl.createCommandQueue(context, id, CL_QUEUE_OUT_OF_ORDER_EXEC_MODE_ENABLE);
    }else{
      finish;

      objects.dup.each!destroy;

      cl.releaseCommandQueue(fqueue);
      cl.releaseContext(fcontext);
    }
  }
  void activate() { active = true; }
  void deactivate() { active = false; }

  private CLObject[] objects;
  private void _removeObject(CLObject o){ objects = objects.remove(objects.countUntil(o)); }

  auto newKernel(string src, string kernelName="", string file=__FILE__, int line=__LINE__){
    return new CLKernel(this, src, kernelName, file, line);
  }
  auto newBuffer(size_t size, string flags="rw"){ return new CLBuffer(this, size, flags); }

  void finish(){ if(active) cl.finish(queue); }
  void flush (){ if(active) cl.flush (queue); }

  ~this(){
    active = false;
    cl.releaseDevice(fid);
  }
}

class CLObject{
  private CLDevice fdevice;
  @property auto device(){ return fdevice; }

  this(CLDevice device){
    device.objects ~= this;
    fdevice = device;
    device.activate;
  }

  ~this(){
    device._removeObject(this);
  }
} //base class for device linked objects

class CLBuffer:CLObject{ // CLBuffer /////////////////////////////////
  private{
    cl_mem      fmem;
    size_t      fsize;
    int         fflags, fmapFlags;
    void*       fmap;
    string      fflagsStr;
  }

  @property auto size () const { return fsize ; }
  @property auto flags() const { return fflags; }
  @property auto mem  () const { return fmem  ; }

  private void create(size_t size, string flags){
    fsize = size;
    fflagsStr = flags;
    fflags = strToCLMemFlags(flags);
    fmem = cl.createBuffer(device.context, fflags, fsize, null);
  }

  this(CLDevice device, size_t size, string flags){
    super(device);
    create(size, flags);
  }

  ~this(){
    unmap;
    cl.releaseMemObject(fmem); fmem = null;
  }

  void recreate(size_t newSize, string flags=""){
    if(fsize==newSize && flags==fflagsStr) return;
    unmap;
    cl.releaseMemObject(fmem); fmem = null;
    create(newSize, flags);
  }

  private static{
    int strToCLMemFlags(string s){
      int fl;
      s = s.strip.toLower;

      void f(string k, int val){
        if(s.countUntil(k)>=0){
          fl |= val;
          s = s.replace(k, "");
        }
      }
      //process flags
      f("rw",CL_MEM_READ_WRITE     );
      f("r" , CL_MEM_READ_ONLY     );
      f("w" , CL_MEM_WRITE_ONLY    );
      f("u" , CL_MEM_USE_HOST_PTR  );
      f("a" , CL_MEM_ALLOC_HOST_PTR);
      f("c" , CL_MEM_COPY_HOST_PTR );
      cl.enforce(s=="", `Invalid cl_mem flags "`~s~`". rw, r, w, u, a, c are valid. (use, alloc, copy hostptr)`);
      return fl;
    }

    int strToMemRW(string s){
      int fl;
      if(s.canFind('r')) fl |= CL_MAP_READ;
      if(s.canFind('w')) fl |= CL_MAP_WRITE;
      cl.enforce(fl!=0, `Invalid Read/Write specifier "`~s~`". (valids: rw, r, w)`);
      return fl;
    }
  }

  void* map(string rw="rw"){
    int fl = strToMemRW(rw);
    if(fmap &&((fl & fmapFlags)==fl)) return fmap; //got it already mapped for the same or more rw rights
    unmap;
    fmapFlags = fl;
    fmap = cl.enqueueMapBuffer(device.queue, fmem, CL_TRUE, fmapFlags, 0, fsize);
    return fmap;
  }

  void* mapPartial(string rw, size_t ofs, size_t size ){
    int fl = strToMemRW(rw);
    if(fmap &&((fl & fmapFlags)==fl)) return fmap; //got it already mapped for the same or more rw rights
    unmap;
    fmapFlags = fl;
    fmap = cl.enqueueMapBuffer(device.queue, fmem, CL_TRUE, fmapFlags, ofs, size);
    return fmap;
  }

  void unmap(){
    if(!fmap) return;
    cl.enqueueUnmapMemObject(device.queue, fmem, fmap);
    fmap = null;
  }

  T[] array(T)(){ return (cast(T*)map)[0..size/T.sizeof]; }
  auto chars  (){ return array!char  ; }
  auto bytes  (){ return array!byte  ; }
  auto ubytes (){ return array!ubyte ; }
  auto shorts (){ return array!short ; }
  auto ushorts(){ return array!ushort; }
  auto ints   (){ return array!int   ; }
  auto uints  (){ return array!uint  ; }
  auto longs  (){ return array!long  ; }
  auto ulongs (){ return array!ulong ; }
  auto floats (){ return array!float ; }
  auto doubles(){ return array!double; }

  private void enforceRange(size_t n){ cl.enforce(n<=size, "CLBuffer out of range"); }

  void read(T)(ref T res, size_t ofs=0){
    enforceRange(ofs+T.sizeof);
    res = *cast(T*)(map("r")+ofs);
  }
  void write(T)(ref T src, size_t ofs=0){
    enforceRange(ofs+T.sizeof);
    *cast(T*)(map("w")+ofs) = src;
  }

  void writeAsync(T)(ref T src, size_t ofs=0){
    enforceRange(ofs+T.sizeof);
    cl.enqueueWriteBuffer(device.queue, fmem, CL_FALSE, ofs, T.sizeof, cast(const void*)(&src));
  }

  void clear(){ bytes[] = 0; }
}


class CLKernel:CLObject{ // CLKernel /////////////////////////////////
  private{
    cl_program program;
    cl_kernel kernel;
    string fBinary, fDisasm;
    int fCodeSize = -1;
  }
  const{
    string name, src;
    size_t workGroupSize;
  }

  private this(CLDevice device, string src, string kernelName, string srcFile=__FILE__, int srcLine=__LINE__){
    super(device);                                           //srcLine, srcFile captires the file where the

    this.src = src;

    if(src.startsWith("\x7FELF")){ //ELF binary image
      program = cl.createProgramWithBinary(device.context, [device.id], src);
    }else if(src.indexOf(".amdcl2")>=0 || src.indexOf(".amdcl12")>=0 && src.indexOf(".kernel")>=0){ //GCN assembly
      try{
        fBinary = assemble(src);
      }catch(Exception e){ throwCompilationError(e, src, srcFile, srcLine); }
      program = cl.createProgramWithBinary(device.context, [device.id], fBinary);
    }else if(src.indexOf("__kernel")>=0){ //OpenCL source
      try{
        program = cl.createProgramWithSource(device.context, src);
      }catch(Exception e){ throwCompilationError(e, src, srcFile, srcLine); }
    }else cl.enforce(0, "CLKernel: Unknown kernel type");

    auto options = "";
    cl.buildProgram(program, [device.id], options);

    //choose a kernel from the program
    string[] names = cl.getProgramInfo_kernels(program);
    cl.enforce(!names.empty, "CLKernel: No kernels in program.");
    name = kernelName=="" ? names[0] : kernelName;
    cl.enforce(names.canFind(name), `CLKernel: kernel not found in program "`~kernelName~`". Available kernels: `~names.text);

    kernel = cl.createKernel(program, name);
    workGroupSize = cl.getPreferredWorkGroupSize(kernel, device.id);
  }

  string binary(){  //todo: ez egy cached value. Erre kene csinalni egy templatet.
    if(fBinary.empty) fBinary = cl.getProgramInfo_binary(program);
    return fBinary;
  }

  private static string callCLRX(string input, string cmdline, string operation){
    auto f0 = File(tempPath, "$clrxtmp.0");
    auto f1 = File(tempPath, "$clrxtmp.1");
    auto f2 = File(tempPath, "$clrxtmp.2");
    f0.remove;
    f1.remove;
    f2.remove;

    string res;

    try{
      f0.write(input);
      import std.process;
      string cmd = cmdline.replace("%0", `"`~f0.fullName~`"`).replace("%1", `"`~f1.fullName~`"`).replace("%2", `"`~f2.fullName~`"`);
      auto r = executeShell(cmd, null, Config.none, size_t.max, tempPath.fullPath);
      if(r.status!=0){
        string err = operation~" failed ("~r.status.to!string~")";
        res = f1.readStr(false) ~ f2.readStr(false);

        const maxErrorLength = 8192;
        if(res.length > maxErrorLength)
          res.length = maxErrorLength;

        if(!res.empty) err ~= "\r\n"~res;
        cl.enforce(0, err);
      }
      res = f1.readStr;
    }finally{
      f0.remove;
      f1.remove;
      f2.remove;
    }
    return res;
  }

  string disasm(){
    if(fDisasm.empty){
      auto s = callCLRX(binary, "clrxdisasm.exe -C %0 > %1", "CLRX Disasm");
      //remove header with unimportant temp filename
      if(s.startsWith("/* Disassembling ")){
        auto i = s.indexOf("\n");
        if(i>0) s = s[i+1..$];
      }
      fDisasm = s;
    }

    return fDisasm;
  }

  size_t codeSize(){
    immutable
      gcnBeginMarkerHex = "00FF06BF9E737D37", //todo: ennek hex stringnek kene lenni
      gcnEndMarkerHex   = "00FF06BF9F737D37";

    if(fCodeSize==-1){
      string b = binary;
      auto st = b.indexOf(cast(string)(gcnBeginMarkerHex.hexToBin));
      auto en = b.indexOf(cast(string)(gcnEndMarkerHex  .hexToBin));
      if(st>=0 && en>=0) fCodeSize = cast(int)(en-st);
                    else fCodeSize = cast(int)b.length-2472;
    }
    return fCodeSize;
  }

  private static string assemble(string src){
    return callCLRX(src, "clrxasm.exe %0 -o %1 >%2 2>&1", "CLRX Asm");
  }

  private void throwCompilationError(Exception e, string src, string srcFile, int srcLine){

    string[] src1, src2;
    void prepareSrc(string src1_, string src2_){
      import std.regex;
      static rx = regex(`\}\s*~.*~\s*q\{`, "gm");
      src1 = std.string.split(src1_.replaceAll(rx, "\x01"), '\n').map!strip.array;
      src2 = std.string.split(src2_                       , '\n').map!strip.array;
    }

    int findSourceLine(int idx2){
      auto chk(string s1, string s2){ return isWild!(false, '\x01', '\x02')(s1, s2); }
      int[] idx1List;
      foreach(i, s1; src1) if(chk(s1, src2[idx2])) idx1List ~= i.to!int;

      if(idx1List.empty) return -1;
      if(idx1List.length==1) return idx1List[0];

      //multiple chioices... find best
      int scoreOf(int idx1, int idx2){
        int res;
        bool doit(int i){
          if(idx2+i<0 || idx2+i>=src2.length) return false;
          if(idx1+i<0 || idx1+i>=src1.length) return false;
          if(!chk(src1[idx1+i], src2[idx2+i])) return false;
          res++;
          return true;
        }
        foreach(int i; 1..int.max) if(!doit(i)) break;
        for(int i=-1; i>int.min; i--) if(!doit(i)) break;
        return res;
      }

      auto scores = idx1List.map!(i => scoreOf(i, idx2)).array;
      return idx1List[scores.maxIndex];
    }

    const prefix = File(tempPath, "$clrxtmp.0").fullName~":";
    bool hasAsmError;

    string processErrorLine(string s){
      s = s.strip;
      string ret = s;

      if(s.startsWith(prefix)){
        s = s[prefix.length..$];

        int line, col; string err;
        try{
          s.formattedRead!"%d:%d: Error: %s"(line, col, err);
        }catch(Throwable){ return ret;}

        int lineIdx = findSourceLine(line); //todo: opt

        if(err!="" && lineIdx>=0){
          hasAsmError = true;
          ret = format("%s(%d,%d): Error: %s", srcFile, lineIdx, col, err);
        }
      }
      return ret;
    }

    prepareSrc(File(srcFile).readStr, src);
    e.msg = e.msg.splitter('\n').map!processErrorLine.filter!"!a.empty".join("\r\n");
    e.file = srcFile;
    e.line = srcLine;
    throw e;
  }

  void arg(uint idx, CLBuffer buf){
    buf.unmap;
    auto mem = buf.mem;
    cl.setKernelArg(kernel, idx, mem.sizeof, &mem);
  }

  void arg(T)(uint idx, T arg)if(isNumeric!T){
    cl.setKernelArg(kernel, idx, T.sizeof, &arg);
  }

  CLEvent run(T...)(size_t workOfs, size_t workSize, T args){
    foreach(i, a; args) arg(i, a);
    auto ev = cl.enqueueNDRangeKernel(device.queue, kernel, workOfs, workSize, workGroupSize);
    return CLEvent(ev, this);
  }

  ~this(){
    cl.releaseKernel(kernel);
    cl.releaseProgram(program);
  }
}

struct CLEvent{
  private{
    cl_event event;
    CLKernel kernel;
    bool frunning;
    double T0,T1;
  }

  this(cl_event event, CLKernel kernel){
    this.event = event;
    this.kernel = kernel;

    T0 = QPS; T1 = T0;
    frunning = true;
  }

  ~this(){
    cl.releaseEvent(event);
  }

  private void update(){
    if(!frunning) return;

    kernel.device.flush;
    int st = cl.getEventInfo_status(event);
    if(st==CL_COMPLETE){ //just finished
      frunning = false;
      T1 = QPS;
    }
  }

  bool running(){ update; return frunning; }
  bool finished(){ return !running; }
  float elapsed_sec(){ if(running) T1 = QPS; return T1-T0; }

  void waitFor(){
    while(running){}
    cl.waitForEvents([event]);
    update;//to get T1
  }
}

// GcnRegPool ///////////////////////////////////////////////////

class GcnRegPool{
private:
  struct Reg{
    char type;
    int idx;

    string allocatedName; //empty if free
    int allocatedIdx;
    bool isArray;

    auto toString ()const { return `%-4s:%s`.format(realName, aliasName); }

    auto realName ()const { return type~idx.text; }
    auto aliasName()const { return allocatedName~(isArray ? "["~allocatedIdx.text~"]" : ""); }

    bool allocated()const { return !allocatedName.empty; }

    void free(){
      allocatedName = "";
      allocatedIdx = 0;
      isArray = false;
    }
  }

  Reg[] regs;

  int findReg(char type, int idx){
    foreach(i, r; regs) if(r.type==type && r.idx==idx) return i.to!int;
    return -1;
  }

public:
  this(int SCnt, int VCnt){
    foreach(i; 0..SCnt) regs ~= Reg('s', i);
    foreach(i; 0..VCnt) regs ~= Reg('v', i);
  }

  bool tryAlloc(char type, int idx, string name, int count=1){
    if(regs.any!(r => r.allocatedName==name)) return false;

    int i = findReg(type, idx);
    if(i>=0 && regs[i..i+count].all!(r => r.type==type && r.allocatedName.empty)){
      foreach(j, ref s; regs[i..i+count]){
        s.allocatedName = name;
        s.allocatedIdx = j.to!int;
        s.isArray = count>1;
      }
      return true;
    }

    return false;
  }

  void alloc(char type, int idx, string name, int count=1){
    enforce(tryAlloc(type, idx, name, count), `RegPool Error: unable to alloc "%s"`.format(name));
  }

  void alloc(char type, string name, int count=1, int align_=1){
    name = name.replace(",", ";").replace("\n", ";"); //accept , and ; and NL for list separator
    if(name.canFind(";")||name.canFind("=")||name.canFind(" align ")||name.canFind("[")){
      allocMulti(type, name.split(";"));
      return;
    }

    if(name.empty) return;
    enforce(!regs.any!(r => r.allocatedName==name), `RegPool error: name "%s" already allocated.`.format(name));

    foreach(i, const r;regs[0..$+1-count]){
      if(r.idx != r.idx/align_*align_) continue;
      if(tryAlloc(type, r.idx, name, count)) return;
    }
    enforce(false, `RegPool error: unable to find space for "%s".`.format(name));
  }

  void allocMulti(char type, string[] parts){
    //todo: align without param -> get align_value from register size
    //todo: comments in reg alloc script
    //todo: alloc legyen a leheto leghatekonyabb! Azoknak a bolgoknak, amik nem lettem cimkent megadva, a vegen keressen helyet: nagyobb -> kisebb sorrendben!
    //todo: warning, ha a forrasban nincs megemlitve egy register (persze mi van, ha emlitve van, de csak commentben)

    foreach(s; parts){
      s = s.strip;
      if(s.empty) continue;

      int align_ = 1;
      string a, b;
      if(split2(s, " align ", a, b)){
        s = a;
        align_ = b.strip.to!int;
      }

      if(split2(s, "]align ", a, b)){ //lame :D
        s = a~"]";
        align_ = b.strip.to!int;
      }

      int dst = -1;
      if(split2(s, "=", a, b)){
        s = a;
        dst = b.strip.to!int;
      }

      int count = 1;
      if(s.isWild("?*[?*]")){
        s = wild[0].strip;
        count = wild[1].strip.to!int;
      }

      enforce(isIdentifier(s), `RegPool error: invalid identifier name "%s"`.format(s));

      if(dst>=0) alloc(type, dst, s, count);
            else alloc(type, s, count, align_);
    }
  }

  void allocS(int idx, string name, int count=1){ alloc('s', idx, name, count); }
  void allocV(int idx, string name, int count=1){ alloc('v', idx, name, count); }
  void allocS(string name, int count=1, int align_=1){ alloc('s', name, count, align_); }
  void allocV(string name, int count=1, int align_=1){ alloc('v', name, count, align_); }

  void free(string filter){
    foreach(ref r; regs) if(r.allocatedName.isWild(filter)) r.free;
  }

  void dump(){
    regs[0..$].each!writeln;
  }

  int getRegCnt(char type)const {
    int cnt = 0;
    foreach(const r; regs)if(r.allocated && r.type==type) cnt = r.idx+1;
    return cnt;
  }

  int getRegTotal(char type)const {
    int cnt = 0;
    foreach(const r; regs)if(r.type==type) cnt = r.idx+1;
    return cnt;
  }

  int sCnt()const { return getRegCnt('s'); }
  int vCnt()const { return getRegCnt('v'); }
  int sTotal()const { return getRegTotal('s'); }
  int vTotal()const { return getRegTotal('v'); }

  auto toClrxDeclarations(){
    auto toDecl(in Reg r, size_t cnt){
      return "%-16s = %%%s".format(r.allocatedName, r.type)~
             (cnt>1 ? "%-10s /* size: %3d */".format("[%d:%d]".format(r.idx, r.idx+cnt-1), cnt)
                    : "%d"     .format(r.idx));
    }

    auto s = regs.filter!"a.allocated"
                 .group!"a.allocatedName==b.allocatedName"
                 .map!(a => toDecl(a[]))
                 .join("\n");
    if(s.empty) return s;

    return "/* GcnRegPool declarations    sgprs:%d/%d  vgprs:%d/%d\n\n".format(sCnt, sTotal, vCnt, vTotal)~
           regMap~
           "\n*/\n%s\n".format(s);
  }

  string regMap(){

    string res;
    foreach(t; "sv"){
      foreach(idx, r; regs) if(r.type==t){
        if((r.idx&(r.type=='s' ? 7 : 3))==0) res ~= ' ';
        res ~= r.allocated ? (r.allocatedIdx ? r.type : r.type.toUpper) : '.';
        if((r.idx&63)==63) res ~= '\n';
      }
      if(!res.empty && res[$-1]!='\n') res ~= '\n';
    }
    return res;
  }

}

// gcn Basic Macros /////////////////////////

//todo: megcsinalni azt a helyzetet, hogy az irasnal/olvasasnal nem csak 1 lane van, hanem annyi, amennyi az EXEC-ben.
//todo: a postfixeket tisztazni: v_writeRegs helyett jobban illik a v_write_regs
//todo: a writeregs csakis buf-0-ra megy, fakk
//todo: az lds_writeRegs meg GID-re ir, nem LID-re, na ez egy nagy kavarodas, valamit csinalni kell vele

private string gcnMacroes(int[] buffers){
  auto s = q{
    /* Basic macroes */
    .macro s_loop idx, cnt, label
      s_addk_i32 idx, 1;
      s_cmp_ge_u32 idx, cnt;
      s_cbranch_scc0 label
    .endm

    .macro _addrCalc sBuf ofs /* calculates address bufN+ofs into vAddr */
      v_mov_b32   vAddr[0], ofs
      v_add_u32   vAddr[0], vcc, sBuf[0], vAddr[0]
      v_mov_b32   vAddr[1], sBuf[1]
      v_addc_u32  vAddr[1], vcc, 0, vAddr[1], vcc
    .endm

  }~ buffers.map!(i => ".macro v_seek%d ofs; _addrCalc sBuf%d, ofs; .endm;\n".format(i, i)).join~ q{

    .macro v_seek_rel n
      v_add_u32  vAddr[0], vcc, n, vAddr[0]
      v_addc_u32 vAddr[1], vcc, 0, vAddr[1], vcc
    .endm

    .macro v_write data
      v_mov_b32 vTmp0, data
      flat_store_dword vAddr, vTmp0 glc
      v_seek_rel 1*4
      s_waitcnt vmcnt(0)
    .endm

    .macro v_write2  data; flat_store_dwordx2 vAddr, data glc; v_seek_rel 2*4; s_waitcnt vmcnt(0); .endm
    .macro v_write4  data; flat_store_dwordx4 vAddr, data glc; v_seek_rel 4*4; s_waitcnt vmcnt(0); .endm
    .macro v_write8  data; .scope; d = %data; v_write4 d[0:3]; v_write4 d[4: 7]; .ends; .endm
    .macro v_write16 data; .scope; d = %data; v_write8 d[0:7]; v_write8 d[8:15]; .ends; .endm

    .macro v_read data
      flat_load_dword data, vAddr glc
      v_seek_rel 1*4
      s_waitcnt vmcnt(0);
    .endm

    .macro v_read2  data; flat_load_dwordx2 data, vAddr glc; v_seek_rel 2*4; s_waitcnt vmcnt(0); .endm
    .macro v_read4  data; flat_load_dwordx4 data, vAddr glc; v_seek_rel 4*4; s_waitcnt vmcnt(0); .endm
    .macro v_read8  data; .scope; d = %$data; v_read4 d[0:3]; v_read4 d[4: 7]; .ends; .endm
    .macro v_read16 data; .scope; d = %$data; v_read8 d[0:7]; v_read8 d[8:15]; .ends; .endm

    /* writing, reading whole regs */
    .macro v_ioRegs regs0, cnt, base, isWrite;  .scope;  regs = %regs0
      v_lshlrev_b32 vTmp0, 2, GID;  v_seek0 vTmp0;  v_seek_rel base
      .for i=0, i<cnt, i+1;
        .if(isWrite);  v_write regs[i];
               .else;  v_read  regs[i];  .endif
        v_seek_rel 256-4;
      .endr
    .ends;.endm

    .macro v_readRegs  regs0, cnt, base;  v_ioRegs regs0, cnt, base, 0;  .endm
    .macro v_writeRegs regs0, cnt, base;  v_ioRegs regs0, cnt, base, 1;  .endm

    .macro lds_ioRegs regs0, cnt, base, isWrite;  .scope;  regs = %regs0;
      v_lshlrev_b32 vTmp0, 2, GID
      .for i=0, i<cnt, i+1;
        .if(isWrite);  ds_write_b32 vTmp0, regs[i] offset:base+(i<<8);
               .else;  ds_read_b32  regs[i], vTmp0 offset:base+(i<<8);  .endif
      .endr
      s_waitcnt lgkmcnt(0)
    .endm

    .macro lds_readRegs  regs0, cnt, base;  lds_ioRegs regs0, cnt, base, 0;  .endm
    .macro lds_writeRegs regs0, cnt, base;  lds_ioRegs regs0, cnt, base, 1;  .endm



    .macro makeRSRC dst, base, stride
      s_mov_b64 dst[0:1], base               /* 48bit base */
      s_or_b32  dst[1], dst[1], (stride)<<16  /* stride*/
      s_mov_b32 dst[2], 0xFFFFffff            /* limit*/
      s_mov_b32 dst[3], 0x08027fac
    .endm

    .macro makeRSRC_TID dst, base, stride
      makeRSRC dst, base, stride
      s_or_b32    dst[3], dst[3], 1<<23       /*ADD_TID_EN*/
      s_andn2_b32 dst[3], dst[3], 0xf<<15     /* mask out stride bits 14:17 */
    .endm


    .macro byteSwap dst src  /*uses sTmp0*/
      s_mov_b32 sTmp0, 0x00010203
      v_perm_b32 dst, src, src, sTmp0
    .endm

    .macro v_fill_range dst, st, en, val:req; .scope
      dst2 = %dst
      .for i=(st), i<=(en), i+1; v_mov_b32 dst2[i], val; .endr
    .ends;.endm

    .macro v_clear_range dst, st, en:req; v_fill_range  dst, st, en, 0; .endm
    .macro v_fill_regs dst, cnt, val:req; v_fill_range  dst, 0, cnt-1, val; .endm
    .macro v_clear_regs dst, cnt:req;     v_clear_range dst, 0, cnt-1;   .endm

    .macro v_move_range dst, st, en, src, sst:req; .scope
      dst2 = %dst
      src2 = %src
      .for i=(st), i<=(en), i+1; v_mov_b32 dst2[i], src2[i+(sst)-(st)]; .endr
    .ends;.endm

    .macro v_move_regs dst, src, cnt:req; v_move_range dst, 0, cnt-1, src, 0; .endm


    .macro s_inc sReg, amount=1; s_add_u32 sReg, sReg, (amount); .endm
    .macro s_dec sReg, amount=1; s_inc sReg, -(amount); .endm

  };

  return s;
}
//todo: v_move_regs -> v_mov_regs


// gcnMake ///////////////////////////////////

alias GCNString = Typedef!(string, "", "GCNString");

GCNString gcnConcat(GCNString[] parts_...){
  auto parts = parts_.map!(p => cast(string)p).array;

  return cast(GCNString)(parts.join);
}

private{
  enum gcnTokenMarkerBegin = "<$<GCNToken>$>";
  enum gcnTokenMarkerEnd   = "</$</GCNToken>$>";
  GCNString gcnToken(string what, string payload){ return cast(GCNString)(gcnTokenMarkerBegin ~ what ~ gcnTokenMarkerEnd ~ payload); }
}

//todo: szamolt mezok a gcnOptions-ba, amit a kernelben fel lehet hasznalni
GCNString gcnOptions(T)(const T o)
if(isAggregateType!T)
{
  enum UPCASE = true;

  string[] parts;
  alias types = FieldTypeTuple!T;
  foreach(idx, name; FieldNameTuple!T){
    string value;
    mixin("value = o."~name~".text;");

    if(isSomeString!(types[idx])) value = `"`~value.replace(`"`, `\"`)~`"`;
    else if(types[idx].stringof=="bool") value = value=="true" ? "1" : "0";

    parts ~= "%s = %s;".format(UPCASE ? name.uc : name, value);
  }

  return gcnToken("Options", parts.join(" "));
}

GCNString gcnHeader(int waveSize, int sgprsNum, int vgprsNum, int localSize, int bufferCnt){

  enum kernelTemplate = q{/* auto generated header */
.amdcl2
.altmacro

.gpu Iceland
.64bit
.arch_minor 0
.arch_stepping 4
.driver_version 203603

.kernel kernel1
  .config
    .dims x
    .cws $waveSize$, 1, 1
    $sgprs$
    $vgprs$
    .localsize $localSize$
    .floatmode 0xc1 /* FloatMode 1 for x86 compatibility */
    .dx10clamp
    .ieeemode
    /* .priority 0 */
    .useargs
    .arg _.global_offset_0, "size_t", long
    .arg _.global_offset_1, "size_t", long
    .arg _.global_offset_2, "size_t", long
    .arg _.printf_buffer, "size_t", void*, global, , rdonly
    .arg _.vqueue_pointer, "size_t", long
    .arg _.aqlwrap_pointer, "size_t", long
    $buffers$
  .text
    groupSize = $waveSize$
    groupSh   = $waveSh$
};

  enforce([1,2,4,8,16,32,64,128,256].canFind(waveSize), "Invalid waveSize (%d)".format(waveSize));
  enforce(sgprsNum.inRange(0,  96), "Invalid sgprsNum (%d)".format(sgprsNum));
  enforce(vgprsNum.inRange(0, 256), "Invalid vgprsNum (%d)".format(vgprsNum));
  enforce(localSize.inRange(0, 32768), "Invalid localSize (%d)".format(localSize));
  enforce(bufferCnt.inRange(1, 4), "Invalid buffer count (%d)".format(bufferCnt));

  string buffers = iota(bufferCnt).map!(i => "%s.arg buf%d, \"int*\", int*, global,\n".format(indent(i ? 4: 0), i)).join;

  string s = kernelTemplate.replace("$waveSize$"    , waveSize.text)
                           .replace("$waveSh$"      , iRound(log2(waveSize)).text)
                           .replace("$sgprs$"       , sgprsNum ? ".sgprsnum "~sgprsNum.text : "") //default: auto
                           .replace("$vgprs$"       , vgprsNum ? ".vgprsnum "~vgprsNum.text : "") //default: auto
                           .replace("$localSize$"   , localSize.text)
                           .replace("$buffers$"     , buffers);
  return gcnToken("Header", s);
}

enum s_load = "s_load"; //UDA that tells the kernel to load fields into s_variables

GCNString gcnParams(T)(){
  auto si = getStructInfo!T;

  string[] sAlloc;
  string[] ofsDecls;
  string[] loadScript;

  void doSLoad(string name, string sName, size_t ofs, size_t size, bool doLoad){
    enforce((size&3)==0, `gcnParams error: fieldSize must be 4N "%s"`.format(name));

    auto ofsName = `ofs_%s`.format(name);
    ofsDecls ~= `%s = %d`.format(ofsName, ofs);

    if(!doLoad) return;

    if(size==4){ //no indexing
      sAlloc ~= sName;
      loadScript ~= "s_load_dword %s, sBuf0, %s".format(sName, ofsName);
      return;
    }

    int calcAlign(size_t s){ return 1<<(s.log2.iFloor); }

    sAlloc ~= `%s[%d] align %d`.format(sName, size/4, calcAlign(size/4));
    int dwIdx;
    while(size>0){
      foreach(dw; [16, 8, 4, 2, 1])if(size>=dw*4){
        loadScript ~= (dw==1) ? "s_load_dword %s[%d], sBuf0, %s+%d".format(sName, dwIdx, ofsName, dwIdx*4)
                              : "s_load_dwordx%d %s[%d:%d], sBuf0, %s+%d".format(dw, sName, dwIdx, dwIdx+dw-1, ofsName, dwIdx*4);
        dwIdx += dw;
        ofs   += dw*4;
        size  -= dw*4;
      }
    }
  }

  foreach(const fi; si.fields){
    auto sName = 's'~capitalizeFirstLetter(fi.name); //name tranformation
    doSLoad(fi.name, sName, fi.ofs, fi.size, fi.uda.canFind("s_load"));
  }

  return gcnConcat( gcnToken("AllocS", sAlloc.join(';'))                     ,
                    gcnToken("LoadParams", (ofsDecls~loadScript).join('\n')) );
}

GCNString gcnAllocS(string s){ return gcnToken("AllocS", s); }
GCNString gcnAllocV(string s){ return gcnToken("AllocV", s); }
GCNString gcnCode  (string s){ return gcnToken("Code"  , s); }

GCNString gcnRoutine(string name, string code, int level=1){
  enforce(name.isIdentifier, `gcnRoutine error: invalid identifier "%s"`.format(name));
  enforce(level.inRange(1, 4), `gcnRoutine error: level out of range`);

  auto header = q{
    /* routine: @ ************************************************************************/
    s_branch .lSkip_@
    .align 64
    .l@:
    .macro ret dummy; s_setpc_b64 sRetAddr#; .endm
  }, footer = q{
    ret
    .purgem ret
    .lSkip_@: /*--------------------------------------------------------------------------*/
  };

  string prep(string s) { return s.replace("#", level.text).replace("@", name).indent(0); }

  return gcnConcat( gcnToken("Routine", level.text ~ ";" ~ name) ,
                    gcnAllocS("s" ~ name ~ "[2] align 2")        ,
                    gcnCode(prep(header) ~ code ~ prep(footer))  );
}

GCNString gcnRoutine1(string name, string code) { return gcnRoutine(name, code, 1); }
GCNString gcnRoutine2(string name, string code) { return gcnRoutine(name, code, 2); }
GCNString gcnRoutine3(string name, string code) { return gcnRoutine(name, code, 3); }
GCNString gcnRoutine4(string name, string code) { return gcnRoutine(name, code, 4); }

string gcnMake(GCNString[] parts_...){
  void onlyOnce(string s, lazy string name){ enforce(s.empty, "gcnMake: "~name~" already defined."); }

  auto parts = parts_.map!(p => cast(string)p).array;
  enforce(parts.all!(p => p.isWild(gcnTokenMarkerBegin~"*"~gcnTokenMarkerEnd~"*")), "gcnMake: Invalid parameters. Every param must be 1 or more concatenated gcnTokens.");

  parts = parts.join.split(gcnTokenMarkerBegin);

  string header, loadParams;
  string[] options, main, allocS, allocV, routineDefs, startup;

  foreach(p; parts)if(!p.empty){ //first is always empty
    if(p.isWild("*"~gcnTokenMarkerEnd~"*")){
      switch(wild[0]){
        case "Options": options ~= wild[1]; break;
        case "Header": onlyOnce(header, "header");header = wild[1]; break;
        case "AllocS": allocS ~= wild[1]; break;
        case "AllocV": allocV ~= wild[1]; break;
        case "LoadParams": onlyOnce(loadParams, "params"); loadParams = wild[1]; break;
        case "Routine": routineDefs ~= wild[1]; break;
        case "Code": main ~= wild[1]; break;
        default: enforce(false, `gcnMake: invalid gcnToken:"%s"`.format(wild[0]));
      }
    }else{
      enforce(false, `gcnMake: unable to decode token: "%s"...`.format(p[0..min($, 50)]));
    }
  }

  enforce(!header.empty, "gcnMake: missing header");
  enforce(!main.empty, "gcnMake: missing main body");

  /////////////////////////////////////////////////////////////////////////
  //   Prepare the kernel stub

  // Create regpool
  int sCnt = 96, vCnt = 256; //default values are max
  if(header.isWild("*.sgprsnum *\r*")) sCnt = wild[1].to!int;
  if(header.isWild("*.vgprsnum *\r*")) vCnt = wild[1].to!int;

  auto pool = new GcnRegPool(sCnt, vCnt);

  // Allocate critical regs
  pool.allocS("sTmp0=0; sTmp1=1; sUserSGPR[2]=4; sGroupIdx=6");
  pool.allocV("GID=0; vTmp0=1; vAddr[2]=2");

  startup ~= "\n/* Initializing kernel */\n"~
    gcnBeginMarker~q{
    s_mov_b32       m0, 0xFFFFffff                /* LDS limit = max */
    s_lshl_b32      sTmp1, sGroupIdx, groupSh         /* calc GID */
    v_add_u32       GID, vcc, sTmp1, GID };

  // Prepare buffers
  int bufCnt = 0;
  int[] buffers;
  foreach(int i; 0..8)if(header.canFind(".arg buf"~i.text)){
    buffers ~= i;
    if(!bufCnt) startup ~= "\n/* Get buffers pointers */";
    auto sBuf = "sBuf"~i.text;
    pool.allocS(sBuf~"[2] align 2");
    startup ~= q{ s_load_dwordx2 %s, sUserSGPR, 0x30+%d*8}.format(sBuf, i);
    bufCnt++;
  }
  if(bufCnt) startup ~= q{ s_waitcnt lgkmcnt(0) };

  // Setup routines
  if(!routineDefs.empty){
    struct RD{ int level; string name; }
    auto rdList = routineDefs.map!(a=>a.split(';')).map!(a => RD(a[0].to!int, a[1])).array;

    pool.allocS("sCodeBase[2] align 2");
    startup ~= q{
      /* Setup routines */
      .macro setupRoutine sAddr, label
        s_add_u32  $sAddr[0], sCodeBase[0], $label - .lCodeBase
        s_addc_u32 $sAddr[1], sCodeBase[1], 0
      .endm
      .lCodeBase: s_getpc_b64 sCodeBase  /* determine code location for subroutines */
      s_sub_u32       sCodeBase[0], sCodeBase[0], 4
      s_subb_u32      sCodeBase[1], sCodeBase[1], 0
    };

    //make call macroes
    foreach(rd; rdList){
      pool.allocS("sAddr"~rd.name~"[2] align 2");
      startup ~= "setupRoutine sAddr%s, .l%s".format(rd.name, rd.name);
      startup ~= ".macro call_%s dummy; s_swappc_b64 sRetAddr%d, sAddr%s; .endm".format(rd.name, rd.level, rd.name);
    }

    //allocate return addresses, create return macroes
    foreach(level; rdList.map!"a.level".group.map!"a[0]"){
      pool.allocS("sRetAddr%d[2] align 2".format(level));
    }
  }

  //allocate user regs
  pool.allocS(allocS.join(';'));
  pool.allocV(allocV.join(';'));

  // Load params from sBuf0
  if(!loadParams.empty){
    enforce(bufCnt, "gcnMake error: LoadParams without any buffers.");
    startup ~= ["\n/* Load params */", loadParams, q{s_waitcnt lgkmcnt(0) }];
  }

  // initialize Routines
  //if(1) p.allocS("sCodeBase[2] align 2; ");

  string startupCode = (pool.toClrxDeclarations ~ startup.join('\n')).indent(2);
  string endCode = "\ns_endpgm\n"~gcnEndMarker~"\n/* End of main */\n";

  string source = [options, [header, startupCode, gcnMacroes(buffers)], main, [endCode]].join.join("\n");

  //use $ symbol instead of \ because my d parser don't like \
  source = source.replace("$", `\`);

//source.split('\n').enumerate.each!(a => "%4d|%s".writefln(a[0]+1, a[1]));

  return source;
}

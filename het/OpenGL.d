module het.opengl;

pragma(lib, "opengl32.lib");

__gshared{
  bool logVBO = 0;
}

enum UseOldTexImage2D = false; //otherwise use TexStorage2D instead!

/+glResManager plan:
Detailed list:
  Shader  : name, handleV, handleG, handleF, flags:VGF, size
  VBO     : name, handle, recordType, length, size
  GLTexture : name, handle, isCustom, type, width, height, mip, size

Summarized list: Shader: count/size,  VBO: count/size, GLTexture: count/size,  total:size
+/

//todo: Ha a glWindow.dr-t hasznalom, akkor a glDraw view es viewGui: tokmindegy a kirajzolasi sorrend, a view van mindig felul, pedig forditva kene.
//todo: nincs doUpdate formresize kozben

public import het.utils, het.win, het.geometry, het.view, het.bitmap, het.draw2d;
import core.runtime, core.sys.windows.windows, core.sys.windows.wingdi, std.traits;

//Turn on high performance GPUs on some laptops
export extern (Windows) int NvOptimusEnablement = 1;
export extern (Windows) int AmdPowerXpressRequestHighPerformance = 1;

alias gl = Singleton!GLFuncts;

//! GL enums///////////////////////////////////////////////////////////

enum{//ErrorCode////////////////////////
  GL_NO_ERROR                     = 0     ,
  GL_INVALID_ENUM                 = 0x0500,
  GL_INVALID_VALUE                = 0x0501,
  GL_INVALID_OPERATION            = 0x0502,
  GL_STACK_OVERFLOW               = 0x0503,
  GL_STACK_UNDERFLOW              = 0x0504,
  GL_OUT_OF_MEMORY                = 0x0505,
}

enum{//Primitives////////////////////////
  GL_POINTS                       =  0,
  GL_LINES                        =  1,
  GL_LINE_LOOP                    =  2,
  GL_LINE_STRIP                   =  3,
  GL_TRIANGLES                    =  4,
  GL_TRIANGLE_STRIP               =  5,
  GL_TRIANGLE_FAN                 =  6,
  GL_QUADS                        =  7,
  GL_QUAD_STRIP                   =  8,
  GL_POLYGON                      =  9,
  GL_LINES_ADJACENCY              = 10,
  GL_LINE_STRIP_ADJACENCY         = 11,
  GL_TRIANGLES_ADJACENCY          = 12,
  GL_TRIANGLE_STRIP_ADJACENCY     = 13,
}

enum{ //Booleans////////////////////////
  GL_FALSE                        = 0,
  GL_TRUE                         = 1,
}

enum{//AccumOp////////////////////////
  GL_ACCUM                        = 0x0100,
  GL_LOAD                         = 0x0101,
  GL_RETURN                       = 0x0102,
  GL_MULT                         = 0x0103,
  GL_ADD                          = 0x0104,
}

enum{//AlphaFunction////////////////////////
  GL_NEVER                        = 0x0200,
  GL_LESS                         = 0x0201,
  GL_EQUAL                        = 0x0202,
  GL_LEQUAL                       = 0x0203,
  GL_GREATER                      = 0x0204,
  GL_NOTEQUAL                     = 0x0205,
  GL_GEQUAL                       = 0x0206,
  GL_ALWAYS                       = 0x0207,
}

enum{//GetString////////////////////////
  GL_VENDOR                       = 0x1F00,
  GL_RENDERER                     = 0x1F01,
  GL_VERSION                      = 0x1F02,
  GL_EXTENSIONS                   = 0x1F03,
}

enum{// AttribMask////////////////////////
  GL_CURRENT_BIT                  = 0x00000001,
  GL_POINT_BIT                    = 0x00000002,
  GL_LINE_BIT                     = 0x00000004,
  GL_POLYGON_BIT                  = 0x00000008,
  GL_POLYGON_STIPPLE_BIT          = 0x00000010,
  GL_PIXEL_MODE_BIT               = 0x00000020,
  GL_LIGHTING_BIT                 = 0x00000040,
  GL_FOG_BIT                      = 0x00000080,
  GL_DEPTH_BUFFER_BIT             = 0x00000100,
  GL_ACCUM_BUFFER_BIT             = 0x00000200,
  GL_STENCIL_BUFFER_BIT           = 0x00000400,
  GL_VIEWPORT_BIT                 = 0x00000800,
  GL_TRANSFORM_BIT                = 0x00001000,
  GL_ENABLE_BIT                   = 0x00002000,
  GL_COLOR_BUFFER_BIT             = 0x00004000,
  GL_HINT_BIT                     = 0x00008000,
  GL_EVAL_BIT                     = 0x00010000,
  GL_LIST_BIT                     = 0x00020000,
  GL_TEXTURE_BIT                  = 0x00040000,
  GL_SCISSOR_BIT                  = 0x00080000,
  GL_ALL_ATTRIB_BITS              = 0x000fffff,
}

enum{//BlendingFactor////////////////////////
  GL_ZERO                         = 0     ,
  GL_ONE                          = 1     ,
  GL_SRC_COLOR                    = 0x0300,
  GL_ONE_MINUS_SRC_COLOR          = 0x0301,
  GL_SRC_ALPHA                    = 0x0302,
  GL_ONE_MINUS_SRC_ALPHA          = 0x0303,
  GL_DST_ALPHA                    = 0x0304,
  GL_ONE_MINUS_DST_ALPHA          = 0x0305,
  GL_DST_COLOR                    = 0x0306,
  GL_ONE_MINUS_DST_COLOR          = 0x0307,
  GL_SRC_ALPHA_SATURATE           = 0x0308,
  GL_CONSTANT_COLOR               = 0x8001,
  GL_ONE_MINUS_CONSTANT_COLOR     = 0x8002,
  GL_CONSTANT_ALPHA               = 0x8003,
  GL_ONE_MINUS_CONSTANT_ALPHA     = 0x8004,
}

enum{//DataType////////////////////////
  GL_BYTE                         = 0x1400,
  GL_UNSIGNED_BYTE                = 0x1401,
  GL_SHORT                        = 0x1402,
  GL_UNSIGNED_SHORT               = 0x1403,
  GL_INT                          = 0x1404,
  GL_UNSIGNED_INT                 = 0x1405,
  GL_FLOAT                        = 0x1406,
  GL_2_BYTES                      = 0x1407,
  GL_3_BYTES                      = 0x1408,
  GL_4_BYTES                      = 0x1409,
  GL_DOUBLE                       = 0x140A,
}

enum{//FrontFaceDirection////////////////////////
  GL_CW                           = 0x0900,
  GL_CCW                          = 0x0901,
}

enum{//Face sides////////////////////////
  GL_FRONT                        = 1028,
  GL_BACK                         = 1029,
  GL_FRONT_AND_BACK               = 1032,
}

enum{//PixelFormat////////////////////////
  GL_COLOR_INDEX                  = 0x1900,
  GL_STENCIL_INDEX                = 0x1901,
  GL_DEPTH_COMPONENT              = 0x1902,
  GL_RED                          = 0x1903,
  GL_GREEN                        = 0x1904,
  GL_BLUE                         = 0x1905,
  GL_ALPHA                        = 0x1906,
  GL_RGB                          = 0x1907,
  GL_RGBA                         = 0x1908,
  GL_LUMINANCE                    = 0x1909,
  GL_LUMINANCE_ALPHA              = 0x190A,
}

enum{//PolygonMode////////////////////////
  GL_POINT                        = 0x1B00,
  GL_LINE                         = 0x1B01,
  GL_FILL                         = 0x1B02,
}

enum{//GetTarget////////////////////////
  GL_CURRENT_COLOR                = 0x0B00,
  GL_CURRENT_INDEX                = 0x0B01,
  GL_CURRENT_NORMAL               = 0x0B02,
  GL_CURRENT_TEXTURE_COORDS       = 0x0B03,
  GL_CURRENT_RASTER_COLOR         = 0x0B04,
  GL_CURRENT_RASTER_INDEX         = 0x0B05,
  GL_CURRENT_RASTER_TEXTURE_COORDS= 0x0B06,
  GL_CURRENT_RASTER_POSITION      = 0x0B07,
  GL_CURRENT_RASTER_POSITION_VALID= 0x0B08,
  GL_CURRENT_RASTER_DISTANCE      = 0x0B09,
  GL_POINT_SMOOTH                 = 0x0B10,
  GL_POINT_SIZE                   = 0x0B11,
  GL_POINT_SIZE_RANGE             = 0x0B12,
  GL_POINT_SIZE_GRANULARITY       = 0x0B13,
  GL_LINE_SMOOTH                  = 0x0B20,
  GL_LINE_WIDTH                   = 0x0B21,
  GL_LINE_WIDTH_RANGE             = 0x0B22,
  GL_LINE_WIDTH_GRANULARITY       = 0x0B23,
  GL_LINE_STIPPLE                 = 0x0B24,
  GL_LINE_STIPPLE_PATTERN         = 0x0B25,
  GL_LINE_STIPPLE_REPEAT          = 0x0B26,
  GL_POLYGON_MODE                 = 0x0B40,
  GL_POLYGON_SMOOTH               = 0x0B41,
  GL_POLYGON_STIPPLE              = 0x0B42,
  GL_EDGE_FLAG                    = 0x0B43,
  GL_CULL_FACE                    = 0x0B44,
  GL_CULL_FACE_MODE               = 0x0B45,
  GL_FRONT_FACE                   = 0x0B46,
  GL_FOG                          = 0x0B60,
  GL_FOG_INDEX                    = 0x0B61,
  GL_FOG_DENSITY                  = 0x0B62,
  GL_FOG_START                    = 0x0B63,
  GL_FOG_END                      = 0x0B64,
  GL_FOG_MODE                     = 0x0B65,
  GL_FOG_COLOR                    = 0x0B66,
  GL_DEPTH_RANGE                  = 0x0B70,
  GL_DEPTH_TEST                   = 0x0B71,
  GL_DEPTH_WRITEMASK              = 0x0B72,
  GL_DEPTH_CLEAR_VALUE            = 0x0B73,
  GL_DEPTH_FUNC                   = 0x0B74,
  GL_ACCUM_CLEAR_VALUE            = 0x0B80,
  GL_STENCIL_TEST                 = 0x0B90,
  GL_STENCIL_CLEAR_VALUE          = 0x0B91,
  GL_STENCIL_FUNC                 = 0x0B92,
  GL_STENCIL_VALUE_MASK           = 0x0B93,
  GL_STENCIL_FAIL                 = 0x0B94,
  GL_STENCIL_PASS_DEPTH_FAIL      = 0x0B95,
  GL_STENCIL_PASS_DEPTH_PASS      = 0x0B96,
  GL_STENCIL_REF                  = 0x0B97,
  GL_STENCIL_WRITEMASK            = 0x0B98,
  GL_NORMALIZE                    = 0x0BA1,
  GL_VIEWPORT                     = 0x0BA2,
  GL_ATTRIB_STACK_DEPTH           = 0x0BB0,
  GL_CLIENT_ATTRIB_STACK_DEPTH    = 0x0BB1,
  GL_ALPHA_TEST                   = 0x0BC0,
  GL_ALPHA_TEST_FUNC              = 0x0BC1,
  GL_ALPHA_TEST_REF               = 0x0BC2,
  GL_BLEND_DST                    = 0x0BE0,
  GL_BLEND_SRC                    = 0x0BE1,
  GL_BLEND                        = 0x0BE2,
  GL_LOGIC_OP_MODE                = 0x0BF0,
  GL_INDEX_LOGIC_OP               = 0x0BF1,
  GL_COLOR_LOGIC_OP               = 0x0BF2,
  GL_AUX_BUFFERS                  = 0x0C00,
  GL_DRAW_BUFFER                  = 0x0C01,
  GL_READ_BUFFER                  = 0x0C02,
  GL_SCISSOR_BOX                  = 0x0C10,
  GL_SCISSOR_TEST                 = 0x0C11,
  GL_INDEX_CLEAR_VALUE            = 0x0C20,
  GL_INDEX_WRITEMASK              = 0x0C21,
  GL_COLOR_CLEAR_VALUE            = 0x0C22,
  GL_COLOR_WRITEMASK              = 0x0C23,
  GL_INDEX_MODE                   = 0x0C30,
  GL_RGBA_MODE                    = 0x0C31,
  GL_DOUBLEBUFFER                 = 0x0C32,
  GL_STEREO                       = 0x0C33,
  GL_RENDER_MODE                  = 0x0C40,
  GL_PERSPECTIVE_CORRECTION_HINT  = 0x0C50,
  GL_POINT_SMOOTH_HINT            = 0x0C51,
  GL_LINE_SMOOTH_HINT             = 0x0C52,
  GL_POLYGON_SMOOTH_HINT          = 0x0C53,
  GL_FOG_HINT                     = 0x0C54,
  GL_TEXTURE_GEN_S                = 0x0C60,
  GL_TEXTURE_GEN_T                = 0x0C61,
  GL_TEXTURE_GEN_R                = 0x0C62,
  GL_TEXTURE_GEN_Q                = 0x0C63,
  GL_PIXEL_MAP_I_TO_I             = 0x0C70,
  GL_PIXEL_MAP_S_TO_S             = 0x0C71,
  GL_PIXEL_MAP_I_TO_R             = 0x0C72,
  GL_PIXEL_MAP_I_TO_G             = 0x0C73,
  GL_PIXEL_MAP_I_TO_B             = 0x0C74,
  GL_PIXEL_MAP_I_TO_A             = 0x0C75,
  GL_PIXEL_MAP_R_TO_R             = 0x0C76,
  GL_PIXEL_MAP_G_TO_G             = 0x0C77,
  GL_PIXEL_MAP_B_TO_B             = 0x0C78,
  GL_PIXEL_MAP_A_TO_A             = 0x0C79,
  GL_PIXEL_MAP_I_TO_I_SIZE        = 0x0CB0,
  GL_PIXEL_MAP_S_TO_S_SIZE        = 0x0CB1,
  GL_PIXEL_MAP_I_TO_R_SIZE        = 0x0CB2,
  GL_PIXEL_MAP_I_TO_G_SIZE        = 0x0CB3,
  GL_PIXEL_MAP_I_TO_B_SIZE        = 0x0CB4,
  GL_PIXEL_MAP_I_TO_A_SIZE        = 0x0CB5,
  GL_PIXEL_MAP_R_TO_R_SIZE        = 0x0CB6,
  GL_PIXEL_MAP_G_TO_G_SIZE        = 0x0CB7,
  GL_PIXEL_MAP_B_TO_B_SIZE        = 0x0CB8,
  GL_PIXEL_MAP_A_TO_A_SIZE        = 0x0CB9,
  GL_UNPACK_SWAP_BYTES            = 0x0CF0,
  GL_UNPACK_LSB_FIRST             = 0x0CF1,
  GL_UNPACK_ROW_LENGTH            = 0x0CF2,
  GL_UNPACK_SKIP_ROWS             = 0x0CF3,
  GL_UNPACK_SKIP_PIXELS           = 0x0CF4,
  GL_UNPACK_ALIGNMENT             = 0x0CF5,
  GL_PACK_SWAP_BYTES              = 0x0D00,
  GL_PACK_LSB_FIRST               = 0x0D01,
  GL_PACK_ROW_LENGTH              = 0x0D02,
  GL_PACK_SKIP_ROWS               = 0x0D03,
  GL_PACK_SKIP_PIXELS             = 0x0D04,
  GL_PACK_ALIGNMENT               = 0x0D05,
  GL_MAP_COLOR                    = 0x0D10,
  GL_MAP_STENCIL                  = 0x0D11,
  GL_INDEX_SHIFT                  = 0x0D12,
  GL_INDEX_OFFSET                 = 0x0D13,
  GL_RED_SCALE                    = 0x0D14,
  GL_RED_BIAS                     = 0x0D15,
  GL_ZOOM_X                       = 0x0D16,
  GL_ZOOM_Y                       = 0x0D17,
  GL_GREEN_SCALE                  = 0x0D18,
  GL_GREEN_BIAS                   = 0x0D19,
  GL_BLUE_SCALE                   = 0x0D1A,
  GL_BLUE_BIAS                    = 0x0D1B,
  GL_ALPHA_SCALE                  = 0x0D1C,
  GL_ALPHA_BIAS                   = 0x0D1D,
  GL_DEPTH_SCALE                  = 0x0D1E,
  GL_DEPTH_BIAS                   = 0x0D1F,
  GL_MAX_CLIP_PLANES              = 0x0D32,
  GL_MAX_TEXTURE_SIZE             = 0x0D33,
  GL_MAX_PIXEL_MAP_TABLE          = 0x0D34,
  GL_MAX_ATTRIB_STACK_DEPTH       = 0x0D35,
  GL_MAX_NAME_STACK_DEPTH         = 0x0D37,
  GL_MAX_VIEWPORT_DIMS            = 0x0D3A,
  GL_MAX_CLIENT_ATTRIB_STACK_DEPTH= 0x0D3B,
  GL_SUBPIXEL_BITS                = 0x0D50,
  GL_INDEX_BITS                   = 0x0D51,
  GL_RED_BITS                     = 0x0D52,
  GL_GREEN_BITS                   = 0x0D53,
  GL_BLUE_BITS                    = 0x0D54,
  GL_ALPHA_BITS                   = 0x0D55,
  GL_DEPTH_BITS                   = 0x0D56,
  GL_STENCIL_BITS                 = 0x0D57,
  GL_ACCUM_RED_BITS               = 0x0D58,
  GL_ACCUM_GREEN_BITS             = 0x0D59,
  GL_ACCUM_BLUE_BITS              = 0x0D5A,
  GL_ACCUM_ALPHA_BITS             = 0x0D5B,
  GL_NAME_STACK_DEPTH             = 0x0D70,
  GL_AUTO_NORMAL                  = 0x0D80,
  GL_TEXTURE_1D                   = 0x0DE0,
  GL_TEXTURE_2D                   = 0x0DE1,
  GL_FEEDBACK_BUFFER_POINTER      = 0x0DF0,
  GL_FEEDBACK_BUFFER_SIZE         = 0x0DF1,
  GL_FEEDBACK_BUFFER_TYPE         = 0x0DF2,
  GL_SELECTION_BUFFER_POINTER     = 0x0DF3,
  GL_SELECTION_BUFFER_SIZE        = 0x0DF4,
  GL_TEXTURE_WIDTH                = 0x1000,
  GL_TEXTURE_HEIGHT               = 0x1001,
  GL_TEXTURE_INTERNAL_FORMAT      = 0x1003,
  GL_TEXTURE_BORDER_COLOR         = 0x1004,
  GL_TEXTURE_BORDER               = 0x1005,
}

enum{//getShaderiv////////////////////////
  GL_SHADER_TYPE                  = 35663,
  GL_DELETE_STATUS                = 35712,
  GL_COMPILE_STATUS               = 35713,
  GL_INFO_LOG_LENGTH              = 35716,
  GL_SHADER_SOURCE_LENGTH         = 35720,
}

enum{//getProgramiv////////////////////////
  GL_LINK_STATUS                  = 35714,
}

enum{//ARB_vertex_buffer_object////////////////////////
  GL_ARRAY_BUFFER                               = 0x8892,
  GL_ELEMENT_ARRAY_BUFFER                       = 0x8893,
  GL_ARRAY_BUFFER_BINDING                       = 0x8894,
  GL_ELEMENT_ARRAY_BUFFER_BINDING               = 0x8895,
  GL_VERTEX_ARRAY_BUFFER_BINDING                = 0x8896,
  GL_NORMAL_ARRAY_BUFFER_BINDING                = 0x8897,
  GL_COLOR_ARRAY_BUFFER_BINDING                 = 0x8898,
  GL_INDEX_ARRAY_BUFFER_BINDING                 = 0x8899,
  GL_TEXTURE_COORD_ARRAY_BUFFER_BINDING         = 0x889A,
  GL_EDGE_FLAG_ARRAY_BUFFER_BINDING             = 0x889B,
  GL_SECONDARY_COLOR_ARRAY_BUFFER_BINDING       = 0x889C,
  GL_FOG_COORDINATE_ARRAY_BUFFER_BINDING        = 0x889D,
  GL_WEIGHT_ARRAY_BUFFER_BINDING                = 0x889E,
  GL_VERTEX_ATTRIB_ARRAY_BUFFER_BINDING         = 0x889F,
  GL_STREAM_DRAW                                = 0x88E0,
  GL_STREAM_READ                                = 0x88E1,
  GL_STREAM_COPY                                = 0x88E2,
  GL_STATIC_DRAW                                = 0x88E4,
  GL_STATIC_READ                                = 0x88E5,
  GL_STATIC_COPY                                = 0x88E6,
  GL_DYNAMIC_DRAW                               = 0x88E8,
  GL_DYNAMIC_READ                               = 0x88E9,
  GL_DYNAMIC_COPY                               = 0x88EA,
  GL_READ_ONLY                                  = 0x88B8,
  GL_WRITE_ONLY                                 = 0x88B9,
  GL_READ_WRITE                                 = 0x88BA,
  GL_BUFFER_SIZE                                = 0x8764,
  GL_BUFFER_USAGE                               = 0x8765,
  GL_BUFFER_ACCESS                              = 0x88BB,
  GL_BUFFER_MAPPED                              = 0x88BC,
  GL_BUFFER_MAP_POINTER                         = 0x88BD,
}

enum{//ARB_shader_objects////////////////////////
  GL_PROGRAM_OBJECT                             = 0x8B40,
  GL_OBJECT_TYPE                                = 0x8B4E,
  GL_OBJECT_SUBTYPE                             = 0x8B4F,
  GL_OBJECT_DELETE_STATUS                       = 0x8B80,
  GL_OBJECT_COMPILE_STATUS                      = 0x8B81,
  GL_OBJECT_LINK_STATUS                         = 0x8B82,
  GL_OBJECT_VALIDATE_STATUS                     = 0x8B83,
  GL_OBJECT_INFO_LOG_LENGTH                     = 0x8B84,
  GL_OBJECT_ATTACHED_OBJECTS                    = 0x8B85,
  GL_OBJECT_ACTIVE_UNIFORMS                     = 0x8B86,
  GL_OBJECT_ACTIVE_UNIFORM_MAX_LENGTH           = 0x8B87,
  GL_OBJECT_SHADER_SOURCE_LENGTH                = 0x8B88,
  GL_SHADER_OBJECT                              = 0x8B48,
  GL_FLOAT_VEC2                                 = 0x8B50,
  GL_FLOAT_VEC3                                 = 0x8B51,
  GL_FLOAT_VEC4                                 = 0x8B52,
  GL_INT_VEC2                                   = 0x8B53,
  GL_INT_VEC3                                   = 0x8B54,
  GL_INT_VEC4                                   = 0x8B55,
  GL_BOOL                                       = 0x8B56,
  GL_BOOL_VEC2                                  = 0x8B57,
  GL_BOOL_VEC3                                  = 0x8B58,
  GL_BOOL_VEC4                                  = 0x8B59,
  GL_FLOAT_MAT2                                 = 0x8B5A,
  GL_FLOAT_MAT3                                 = 0x8B5B,
  GL_FLOAT_MAT4                                 = 0x8B5C,
  GL_ACTIVE_ATTRIBUTES                          = 35721,
}

enum{//ARB_vertex_shader////////////////////////
  GL_VERTEX_SHADER                              = 0x8B31,
  GL_MAX_VERTEX_UNIFORM_COMPONENTS              = 0x8B4A,
  GL_MAX_VARYING_FLOATS                         = 0x8B4B,
  GL_MAX_VERTEX_TEXTURE_IMAGE_UNITS             = 0x8B4C,
  GL_MAX_COMBINED_TEXTURE_IMAGE_UNITS           = 0x8B4D,
  GL_OBJECT_ACTIVE_ATTRIBUTES                   = 0x8B89,
  GL_OBJECT_ACTIVE_ATTRIBUTE_MAX_LENGTH         = 0x8B8A,
  GL_MAX_VERTEX_OUTPUT_COMPONENTS               = 0x9122,
}

enum{//ARB_fragment_shader////////////////////////
  GL_FRAGMENT_SHADER                            = 0x8B30,
  GL_MAX_FRAGMENT_UNIFORM_COMPONENTS            = 0x8B49,
  GL_MAX_FRAGMENT_INPUT_COMPONENTS              = 0x9125,
}

enum{//ARB_geometry_shader////////////////////////
  GL_GEOMETRY_SHADER                            = 36313,
  GL_MAX_GEOMETRY_TEXTURE_IMAGE_UNITS           = 0x8C29,
  GL_GEOMETRY_VERTICES_OUT                      = 0x8916,
  GL_GEOMETRY_INPUT_TYPE                        = 0x8917,
  GL_GEOMETRY_OUTPUT_TYPE                       = 0x8918,
  GL_MAX_GEOMETRY_UNIFORM_COMPONENTS            = 0x8DDF,
  GL_MAX_GEOMETRY_OUTPUT_VERTICES               = 0x8DE0,
  GL_MAX_GEOMETRY_TOTAL_OUTPUT_COMPONENTS       = 0x8DE1,
  GL_MAX_GEOMETRY_INPUT_COMPONENTS              = 0x9123,
  GL_MAX_GEOMETRY_OUTPUT_COMPONENTS             = 0x9124,
}

enum{//other////////////////////////
  GL_MULTISAMPLE                                = 0x809D,

  WGL_NUMBER_PIXEL_FORMATS_ARB                  = 0x2000,
  WGL_DRAW_TO_WINDOW_ARB                        = 0x2001,
  WGL_DRAW_TO_BITMAP_ARB                        = 0x2002,
  WGL_ACCELERATION_ARB                          = 0x2003,
  WGL_NEED_PALETTE_ARB                          = 0x2004,
  WGL_NEED_SYSTEM_PALETTE_ARB                   = 0x2005,
  WGL_SWAP_LAYER_BUFFERS_ARB                    = 0x2006,
  WGL_SWAP_METHOD_ARB                           = 0x2007,
  WGL_NUMBER_OVERLAYS_ARB                       = 0x2008,
  WGL_NUMBER_UNDERLAYS_ARB                      = 0x2009,
  WGL_TRANSPARENT_ARB                           = 0x200A,
  WGL_TRANSPARENT_RED_VALUE_ARB                 = 0x2037,
  WGL_TRANSPARENT_GREEN_VALUE_ARB               = 0x2038,
  WGL_TRANSPARENT_BLUE_VALUE_ARB                = 0x2039,
  WGL_TRANSPARENT_ALPHA_VALUE_ARB               = 0x203A,
  WGL_TRANSPARENT_INDEX_VALUE_ARB               = 0x203B,
  WGL_SHARE_DEPTH_ARB                           = 0x200C,
  WGL_SHARE_STENCIL_ARB                         = 0x200D,
  WGL_SHARE_ACCUM_ARB                           = 0x200E,
  WGL_SUPPORT_GDI_ARB                           = 0x200F,
  WGL_SUPPORT_OPENGL_ARB                        = 0x2010,
  WGL_DOUBLE_BUFFER_ARB                         = 0x2011,
  WGL_STEREO_ARB                                = 0x2012,
  WGL_PIXEL_TYPE_ARB                            = 0x2013,
  WGL_COLOR_BITS_ARB                            = 0x2014,
  WGL_RED_BITS_ARB                              = 0x2015,
  WGL_RED_SHIFT_ARB                             = 0x2016,
  WGL_GREEN_BITS_ARB                            = 0x2017,
  WGL_GREEN_SHIFT_ARB                           = 0x2018,
  WGL_BLUE_BITS_ARB                             = 0x2019,
  WGL_BLUE_SHIFT_ARB                            = 0x201A,
  WGL_ALPHA_BITS_ARB                            = 0x201B,
  WGL_ALPHA_SHIFT_ARB                           = 0x201C,
  WGL_ACCUM_BITS_ARB                            = 0x201D,
  WGL_ACCUM_RED_BITS_ARB                        = 0x201E,
  WGL_ACCUM_GREEN_BITS_ARB                      = 0x201F,
  WGL_ACCUM_BLUE_BITS_ARB                       = 0x2020,
  WGL_ACCUM_ALPHA_BITS_ARB                      = 0x2021,
  WGL_DEPTH_BITS_ARB                            = 0x2022,
  WGL_STENCIL_BITS_ARB                          = 0x2023,
  WGL_AUX_BUFFERS_ARB                           = 0x2024,

  WGL_NO_ACCELERATION_ARB                       = 0x2025,
  WGL_GENERIC_ACCELERATION_ARB                  = 0x2026,
  WGL_FULL_ACCELERATION_ARB                     = 0x2027,

  WGL_SWAP_EXCHANGE_ARB                         = 0x2028,
  WGL_SWAP_COPY_ARB                             = 0x2029,
  WGL_SWAP_UNDEFINED_ARB                        = 0x202A,

  WGL_TYPE_RGBA_ARB                             = 0x202B,
  WGL_TYPE_COLORINDEX_ARB                       = 0x202C,

  WGL_SAMPLE_BUFFERS_ARB                        = 0x2041,
  WGL_SAMPLES_ARB                               = 0x2042,
}

// TEXTURING

enum{//texture_object////////////////////////
  GL_TEXTURE_PRIORITY                           = 0x8066,
  GL_TEXTURE_RESIDENT                           = 0x8067,
  GL_TEXTURE_BINDING_1D                         = 0x8068,
  GL_TEXTURE_BINDING_2D                         = 0x8069,

  GL_CLAMP_TO_EDGE                              = 0x812F,

  GL_MAX_TEXTURE_IMAGE_UNITS                    = 0x8872,
}

enum{// texture format////////////////////////
  GL_ALPHA4                                     = 0x803B,
  GL_ALPHA8                                     = 0x803C,
  GL_ALPHA12                                    = 0x803D,
  GL_ALPHA16                                    = 0x803E,
  GL_LUMINANCE4                                 = 0x803F,
  GL_LUMINANCE8                                 = 0x8040,
  GL_LUMINANCE12                                = 0x8041,
  GL_LUMINANCE16                                = 0x8042,
  GL_LUMINANCE4_ALPHA4                          = 0x8043,
  GL_LUMINANCE6_ALPHA2                          = 0x8044,
  GL_LUMINANCE8_ALPHA8                          = 0x8045,
  GL_LUMINANCE12_ALPHA4                         = 0x8046,
  GL_LUMINANCE12_ALPHA12                        = 0x8047,
  GL_LUMINANCE16_ALPHA16                        = 0x8048,
  GL_INTENSITY                                  = 0x8049,
  GL_INTENSITY4                                 = 0x804A,
  GL_INTENSITY8                                 = 0x804B,
  GL_INTENSITY12                                = 0x804C,
  GL_INTENSITY16                                = 0x804D,
  GL_R3_G3_B2                                   = 0x2A10,
  GL_RGB4                                       = 0x804F,
  GL_RGB5                                       = 0x8050,
  GL_RGB8                                       = 0x8051,
  GL_RGB10                                      = 0x8052,
  GL_RGB12                                      = 0x8053,
  GL_RGB16                                      = 0x8054,
  GL_RGBA2                                      = 0x8055,
  GL_RGBA4                                      = 0x8056,
  GL_RGB5_A1                                    = 0x8057,
  GL_RGBA8                                      = 0x8058,
  GL_RGB10_A2                                   = 0x8059,
  GL_RGBA12                                     = 0x805A,
  GL_RGBA16                                     = 0x805B,
  GL_TEXTURE_RED_SIZE                           = 0x805C,
  GL_TEXTURE_GREEN_SIZE                         = 0x805D,
  GL_TEXTURE_BLUE_SIZE                          = 0x805E,
  GL_TEXTURE_ALPHA_SIZE                         = 0x805F,
  GL_TEXTURE_LUMINANCE_SIZE                     = 0x8060,
  GL_TEXTURE_INTENSITY_SIZE                     = 0x8061,
  GL_PROXY_TEXTURE_1D                           = 0x8063,
  GL_PROXY_TEXTURE_2D                           = 0x8064,
}

enum{
  GL_TEXTURE0                                   = 0x84C0,
}
auto GL_TEXTURE(const int n){ return GL_TEXTURE0+n; }

enum{
  GL_NEAREST                       = 0x2600,
  GL_LINEAR                        = 0x2601,
  GL_NEAREST_MIPMAP_NEAREST        = 0x2700,
  GL_LINEAR_MIPMAP_NEAREST         = 0x2701,
  GL_NEAREST_MIPMAP_LINEAR         = 0x2702,
  GL_LINEAR_MIPMAP_LINEAR          = 0x2703,
  GL_TEXTURE_MAG_FILTER            = 0x2800,
  GL_TEXTURE_MIN_FILTER            = 0x2801,
  GL_TEXTURE_WRAP_S                = 0x2802,
  GL_TEXTURE_WRAP_T                = 0x2803,
  GL_CLAMP                         = 0x2900,
  GL_REPEAT                        = 0x2901,
}

enum{
  GL_TEXTURE_MAX_ANISOTROPY_EXT     = 0x84FE,
  GL_MAX_TEXTURE_MAX_ANISOTROPY_EXT = 0x84FF,
}

//! GLU enums /////////////////////////////////////

enum{// TessCallback ////////////////////////
  GLU_TESS_BEGIN                    = 100100,
  GLU_BEGIN                         = 100100,
  GLU_TESS_VERTEX                   = 100101,
  GLU_VERTEX                        = 100101,
  GLU_TESS_END                      = 100102,
  GLU_END                           = 100102,
  GLU_TESS_ERROR                    = 100103,
  GLU_TESS_EDGE_FLAG                = 100104,
  GLU_EDGE_FLAG                     = 100104,
  GLU_TESS_COMBINE                  = 100105,
  GLU_TESS_BEGIN_DATA               = 100106,
  GLU_TESS_VERTEX_DATA              = 100107,
  GLU_TESS_END_DATA                 = 100108,
  GLU_TESS_ERROR_DATA               = 100109,
  GLU_TESS_EDGE_FLAG_DATA           = 100110,
  GLU_TESS_COMBINE_DATA             = 100111,
}

enum TessContour:int {// TessContour////////////////////////
  GLU_CW                            = 100120,
  GLU_CCW                           = 100121,
  GLU_INTERIOR                      = 100122,
  GLU_EXTERIOR                      = 100123,
  GLU_UNKNOWN                       = 100124,
}

enum{// TessProperty////////////////////////
  GLU_TESS_WINDING_RULE             = 100140,
  GLU_TESS_BOUNDARY_ONLY            = 100141,
  GLU_TESS_TOLERANCE                = 100142,
}

enum{// TessError ////////////////////////
  GLU_TESS_MISSING_BEGIN_POLYGON    = 100151,
  GLU_TESS_MISSING_BEGIN_CONTOUR    = 100152,
  GLU_TESS_MISSING_END_POLYGON      = 100153,
  GLU_TESS_MISSING_END_CONTOUR      = 100154,
  GLU_TESS_COORD_TOO_LARGE          = 100155,
  GLU_TESS_NEED_COMBINE_CALLBACK    = 100156,
  GLU_TESS_ERROR7                   = 100157,
  GLU_TESS_ERROR8                   = 100158,
}

enum TessWinding:int {// TessWinding ////////////////////////
  odd              = 100130,
  nonZero          = 100131,
  positive         = 100132,
  negative         = 100133,
  abs_geq_two      = 100134,
}

///! GLFuncts class //////////////////////////////////////////////////////////////////////////

private class GLFuncts{ //todo: roviditve a GLXxxxx elotag legyen GlXxxxx
private: //original opengl api calls, private helpers
  extern(Windows){
    int function()                                                        glGetError;

    void function()                                                       glFlush, glFinish;

    void function(int val)                                                wglSwapIntervalEXT;

    char* function(int name)                                              glGetString;
    void function(int name, int* v)                                       glGetIntegerv;
    void function(int pname, float *value)                                glGetFloatv;

    void function(int what)                                               glEnable, glDisable;
    bool function(int what)                                               glIsEnabled;

    void function(float r, float g, float b, float a)                     glClearColor;
    void function(float d)                                                glClearDepth;
    void function(int mask)                                               glClear;

    void function(int x, int y, int w, int h, int format, int type, int len, void* data) glReadnPixels;

    void function(int what)                                               glFrontFace;
    void function(int what)                                               glCullFace;
    void function(int face, int what)                                     glPolygonMode;
    void function(float width)                                            glLineWidth;
    void function(int what)                                               glDepthFunc;

    void function(bool)                                                   glDepthMask;
    void function(bool, bool, bool, bool)                                 glColorMask;
    void function(int sfactor, int dfactor)                               glBlendFunc;
    void function(float r, float g, float b, float a)                     glBlendColor;
    void function(int func, float reference)                              glAlphaFunc;

    void function(int x, int y, int width, int height)                    glViewport;

    int function(int type)                                                glCreateShader;
    void function(int shader, int count, const(char)** source, int* length) glShaderSource;
    int function(int shader)                                              glCompileShader;
    void function(int shader)                                             glDeleteShader;
    void function(int shader, int pname, int* res)                        glGetShaderiv;
    void function(int shader, int maxLength, int* length, char* infoLog)  glGetShaderInfoLog;
    int function()                                                        glCreateProgram;
    void function(int prg, int shader)                                    glAttachShader, glDetachShader;
    int function(int prg, const(char)* name)                              glGetAttribLocation;
    void function(int prg, int index, const(char)* name)                  glBindAttribLocation;
    void function(int prg)                                                glLinkProgram, glUseProgram, glDeleteProgram;
    void function(int prg, int pname, int* res)                           glGetProgramiv;
    void function(int prg, int maxLength, int* length, char* infoLog)     glGetProgramInfoLog;
    void function(int prg, int idx, int bufSize, int* length, int* size, int *type, char* name) glGetActiveAttrib;

    void function(int index, int size, int type, bool normalized, int stride, void* ptr) glVertexAttribPointer;
    void function(int index, int size, int type,                  int stride, void* ptr) glVertexAttribIPointer;
    void function(int index)                                              glEnableVertexAttribArray, glDisableVertexAttribArray;
    void function(int mode, int first, int count)                         glDrawArrays;

    void function(int n, int* ids)                                        glGenBuffers, glDeleteBuffers;
    void function(int target, int id)                                     glBindBuffer;
    void function(int target, int size, const(void)* data, int usage)     glBufferData;
    void function(int target, int offset, int size, const(void)* data)    glBufferSubData;

    int function(int prg, const(char)* name)                              glGetUniformLocation;
    void function(int loc, int cnt, const(float)* val)                    glUniform1fv , glUniform2fv , glUniform3fv , glUniform4fv ;
    void function(int loc, int cnt, const(int  )* val)                    glUniform1iv , glUniform2iv , glUniform3iv , glUniform4iv ;
    void function(int loc, int cnt, bool transpose, const(float)* val)    glUniformMatrix4fv, glUniformMatrix3fv;

//not supported on dell    void function(int loc, int cnt, const(uint )* val)                    glUniform1uiv, glUniform2uiv, glUniform3uiv, glUniform4uiv;

    void function(int slot)                                               glActiveTexture;
    void function(int cnt, const(int) *texId)                             glDeleteTextures;

    void function(int slot, int* handle)                                  glGenTextures;
    void function(int slot, int texture)                                  glBindTexture;
    void function(int what, int value)                                    glPixelStorei;
    void function(int target, int level, int format, int type, void* pixels)                                                           glGetTexImage;
    void function(int target, int level, int internalFmt, int width, int height, int border, int format, int type, const(void)* data)  glTexImage2D;
    void function(int target, int levels, int internalFmt, int width, int height)                                                      glTexStorage2D;
    void function(int target, int level, int xOffs, int yOffs, int width, int height, int format, int type, const(void)* data)         glTexSubImage2D;
//    void function(int target, int level, int xOffs, int yOffs, int zOffs, int width, int height, int depth, int bufSize, void* data)   glGetCompressedTextureSubImage_optional; //ver: 4.5

    void function(int target)                                             glGenerateMipmap;
    void function(int target, int pname, float pvalue)                    glTexParameterf;

  // GLU functs /////////////////////////////

    void* function()                                            gluNewTess;
    void function(void* tess)                                   gluDeleteTess, gluTessBeginContour, gluTessEndContour, gluTessEndPolygon;
    void function(void* tess, int what, void* fn)               gluTessCallback;
    void function(void* tess, double x, double y, double z)     gluTessNormal;
    void function(void* tess, int prop, double value)           gluTessProperty;
    void function(void* tess, void* data)                       gluTessBeginPolygon;
    void function(void* tess, TessContour)                      gluNextContour;
    void function(void* tess, double* location, void* data)     gluTessVertex;
  }

  // function wrappers ////////////////////////////////////

  private void loadFuncts() //must be called right after it got an active opengl contect
  {
    if(!&glGetError) return; //only if needed

    auto hGL = loadLibrary("OpenGL32.dll"),
         hGLU = loadLibrary("glu32.dll");

    //getProcAddress: works with opengl32.dll exports and also with wgl extensions
    void GPA(T)(ref T func, string name) {
      if(!name.startsWith("gl") && !name.startsWith("wgl")) return;
      alias t = typeof(func);

      //check if the function is optional
      const optPostfix = "_optional";
      const isOptional = name.endsWith(optPostfix);
      if(isOptional) name = name[0..$-optPostfix.length];

      //1. try from wgl
      func = cast(t)wglGetProcAddress(toStringz(name));
      //2. try from opengl32
      if(!func) func = cast(t)GetProcAddress(hGL, toStringz(name));
      //3. try from glu32
      if(!func) func = cast(t)GetProcAddress(hGLU, toStringz(name));

      //otherwise error
      if(!func && !isOptional)
        throw new Exception("gl.getProcAddress fail: "~name);
    }

    //load all the function pointers in this class
    mixin([FieldNameTuple!GLFuncts].map!(x => `GPA(`~x~`,"`~x~`");` ).join);
  }

  static string glErrorStr(int err)
  {
    if(err==GL_NO_ERROR) return "";

    switch(err){
      case GL_INVALID_ENUM      : return "INVALID_ENUM";
      case GL_INVALID_VALUE     : return "INVALID_VALUE";
      case GL_INVALID_OPERATION : return "INVALID_OPERATION";
      case GL_STACK_OVERFLOW    : return "STACK_OVERFLOW";
      case GL_STACK_UNDERFLOW   : return "STACK_UNDERFLOW";
      case GL_OUT_OF_MEMORY     : return "OUT_OF_MEMORY";

      case GLU_TESS_MISSING_BEGIN_POLYGON   : return "TESS_MISSING_BEGIN_POLYGON";
      case GLU_TESS_MISSING_BEGIN_CONTOUR   : return "TESS_MISSING_BEGIN_CONTOUR";
      case GLU_TESS_MISSING_END_POLYGON     : return "TESS_MISSING_END_POLYGON";
      case GLU_TESS_MISSING_END_CONTOUR     : return "TESS_MISSING_END_CONTOUR";
      case GLU_TESS_COORD_TOO_LARGE         : return "TESS_COORD_TOO_LARGE";
      case GLU_TESS_NEED_COMBINE_CALLBACK   : return "TESS_NEED_COMBINE_CALLBACK";
      case GLU_TESS_ERROR7                  : return "TESS_ERROR7";
      case GLU_TESS_ERROR8                  : return "TESS_ERROR8";

      default: return "UNKNOWN("~text(err)~")";
    }
  }

  void glChk(string file = __FILE__, int line = __LINE__){  //todo: utils. customEnforce() template
    int err = glGetError();
    if(err) throw new Exception("GLError: "~glErrorStr(err), file, line);
  }

public://///////////////////////////////////////////////////////

  private bool active_;
  @property bool active()const { return active_; };
  @property private void active(bool v) { active_ = v; }

  void swapInterval(int intrvl) { wglSwapIntervalEXT(intrvl); }

  string getString(int name) { string res = text(glGetString(name)); glChk("getString"); return res; }
  string getVendor      () { return getString(GL_VENDOR    ); }
  string getRenderer    () { return getString(GL_RENDERER  ); }
  string getVersion     () { return getString(GL_VERSION   ); }
  string getExtensions  () { return getString(GL_EXTENSIONS); }

  private static string getArrayv(string name, string T){
    return format(q{
      auto get%1$sv(int name, int len){
        %2$s[] res;
        res.length = len;
        glGet%1$sv(name, res.ptr);
        glChk;
        return res;
      }
      auto get%1$s(int name){ return get%1$sv(name, 1)[0]; }
    }, name, T);
  }
  mixin(getArrayv("Integer", "int"  ));
  mixin(getArrayv("Float"  , "float"));

  auto getViewport() {
    auto vp = getIntegerv(GL_VIEWPORT, 4);
    return ibounds2(vp[0], vp[1], vp[0]+vp[2], vp[1]+vp[3]);
  }

  auto maxTextureSize() {
    static int v;
    if(!v) v = getInteger(GL_MAX_TEXTURE_SIZE);
    return v;
  }

  auto maxTextureImageUnits() { return getInteger(GL_MAX_TEXTURE_IMAGE_UNITS); }

  void flush () { glFlush (); glChk; }
  void finish() { glFinish(); glChk; }

  void enable(int what, bool state = true){
    if(state){
      glEnable(what);
      glChk;
    }else{
      disable(what);
    }
  }
  void disable(int what){
    glDisable(what);
    glChk;
  }
  bool isEnabled(int what){
    bool res = glIsEnabled(what);
    glChk;
    return res;
  }

  void clearColor(float r, float g, float b, float a)   { glClearColor(r, g, b, a); }
  void clearColor(T)(in T color)                        { with(color.convertPixel!vec4) clearColor(r, g, b, a); }
  void clearDepth(float depth)                          { glClearDepth(depth); }
  void clear(int mask)                                  { glClear(mask); glChk; }

  void readPixels(int x, int y, int w, int h, int format, int type, void[] data) { glReadnPixels(x, y, w, h, format, type, data.length.to!int, data.ptr); glChk; }

  void frontFace(int what) { glFrontFace(what); glChk; }
  void cullFace (int what) { glCullFace (what); glChk; }
  void polygonMode(int face, int what) { glPolygonMode(face, what); glChk; }
  void lineWidth(float width) { glLineWidth(width); glChk; }
  void depthFunc(int what) { glDepthFunc(what); glChk; }

  void depthMask(bool d) { glDepthMask(d); }
  void colorMask(bool r, bool g, bool b, bool a) { glColorMask(r, g, b, a); }
  void blendFunc(int sfactor, int dfactor) { glBlendFunc(sfactor, dfactor); glChk; }
  void blendColor(float r, float g, float b, float a)   { glBlendColor(r, g, b, a); }
  void blendColor(T)(in T color)                        { with(color.convertPixel!vec4) blendColor(r, g, b, a); }
  void alphaFunc(int func, float reference) { glAlphaFunc(func, reference); glChk; }

  void viewport(int x, int y, int width, int height)    { glViewport(x, y, width, height); glChk; }

  void shaderSource(int shader, string source){
    auto s = source.toPChar;
    glShaderSource(shader, 1, &s, null);
    glChk;
  }
  void compileShader(int shader){
    glCompileShader(shader);
    glChk;
  }
  void getShaderiv(int shader, int pname, int* res){
    glGetShaderiv(shader, pname, res);
    glChk;
  }
  bool getShaderCompiled(int shader){
    int compiled;
    getShaderiv(shader, GL_COMPILE_STATUS, &compiled);
    return compiled!=0;
  }
  int getShaderInfoLen(int shader){
    int infoLen;
    glGetShaderiv(shader, GL_INFO_LOG_LENGTH, &infoLen);
    return infoLen;
  }
  void getShaderInfoLog(int shader, int maxLength, int* length, char* infoLog){
    glGetShaderInfoLog(shader, maxLength, length, infoLog);
    glChk;
  }
  string getShaderInfoLog(int shader){
    char[] infoLog;
    infoLog.length = getShaderInfoLen(shader);
    getShaderInfoLog(shader, cast(int)infoLog.length, null, infoLog.ptr);
    return to!(string)(infoLog);
  }
  void attachShader(int prg, int shader){
    glAttachShader(prg, shader);
    glChk;
  }
  void detachShader(int prg, int shader){
    glDetachShader(prg, shader);
    glChk;
  }
  void bindAttribLocation(int prg, int index, string name){
    glBindAttribLocation(prg, index, name.toPChar);
    glChk;
  }
  int getAttribLocation(int prg, string name){
    int res = glGetAttribLocation(prg, name.toPChar);
    glChk;
    return res;
  }
  void linkProgram(int prg){
    glLinkProgram(prg);
    glChk;
  }
  void getProgramiv(int prg, int pname, int* res){
    glGetProgramiv(prg, pname, res);
    glChk;
  }
  bool getProgramLinked(int prg){
    int linked;
    gl.getProgramiv(prg, GL_LINK_STATUS, &linked);
    return linked!=0;
  }
  int getProgramInfoLen(int prg){
    int infoLen;
    glGetProgramiv(prg, GL_INFO_LOG_LENGTH, &infoLen);
    return infoLen;
  }
  void getProgramInfoLog(int prg, int maxLength, int* length, char* infoLog){
    glGetProgramInfoLog(prg, maxLength, length, infoLog);
    glChk;
  }
  string getProgramInfoLog(int prg){
    char[] infoLog;
    infoLog.length = getProgramInfoLen(prg);
    getProgramInfoLog(prg, cast(int)infoLog.length, null, infoLog.ptr);
    return to!(string)(infoLog);
  }
  void getActiveAttrib(int prg, int idx, ref int size, ref int type, ref string name){
    char[128] buf = void;
    int len;
    glGetActiveAttrib(prg, idx, buf.sizeof, &len, &size, &type, buf.ptr);
    glChk;
    name = to!string(buf[0..len]);
  }

  void useProgram(int prg){
    glUseProgram(prg);
    glChk;
  }
  void vertexAttribPointer(int index, int size, int type, bool normalized, int stride, void* ptr){
    glVertexAttribPointer(index, size, type, normalized, stride, ptr);
    glChk;
  }
  void vertexAttribIPointer(int index, int size, int type, int stride, void* ptr){
    glVertexAttribIPointer(index, size, type, stride, ptr);
    glChk;
  }
  void enableVertexAttribArray(int index, bool state=true){
    if(state){
      glEnableVertexAttribArray(index);
      glChk;
    }else{
      disableVertexAttribArray(index);
    }
  }
  void disableVertexAttribArray(int index){
    glDisableVertexAttribArray(index);
    glChk;
  }
  void drawArrays(int mode, int first, int count){
    glDrawArrays(mode, first, count);
    glChk;
  }

  void bindBuffer(int target, int id){
    glBindBuffer(target, id);
    glChk;
  }
  void bufferData(int target, int size, const(void)* data, int usage){
    glBufferData(target, size, data, usage);
    glChk;
  }
  void bufferData(int target, const(float)[] data, int usage){ bufferData(target, cast(int)data.length*4, data.ptr, usage); }
  void bufferSubData(int target, int offset, int size, const(void)* data){
    glBufferSubData(target, offset, size, data);
    glChk;
  }
  void bufferSubData(int target, int offset, const(float)[] data){ bufferSubData(target, offset, cast(int)data.length*4, data.ptr); }

  int getUniformLocation(int prg, string name){
    int res = glGetUniformLocation(prg, name.toPChar);
    glChk;
    return res;
  }

  void uniform(int loc, float v ){ glUniform1fv(loc, 1, &v  ); glChk; }
  void uniform(int loc, in vec2 v){ glUniform2fv(loc, 1, v.array.ptr); glChk; }
  void uniform(int loc, in vec3 v){ glUniform3fv(loc, 1, v.array.ptr); glChk; }

  void uniform(int loc, int v      ){ glUniform1iv(loc, 1, &v  ); glChk; }
  void uniform(int loc, in ivec2 v, string file=__FILE__, int line=__LINE__){ glUniform2iv(loc, 1, v.array.ptr); glChk(file, line); }

  void uniform(int loc, in float[4][4] v){ glUniformMatrix4fv(loc, 1, true/*transposed by default*/, &v[0][0]); glChk; }
  void uniform(int loc, in float[3][3] v){ glUniformMatrix3fv(loc, 1, true/*transposed by default*/, &v[0][0]); glChk; }

  void uniform(int loc, in float[4] v){ glUniform4fv(loc, 1, &v[0]); glChk; }
  void uniform(int loc, in float[3] v){ glUniform3fv(loc, 1, &v[0]); glChk; }

  void activeTexture(int slot) { glActiveTexture(slot); glChk; }
  void bindTexture(int slot, int texture) { glBindTexture(slot, texture); glChk; }

  void pixelStore(int what, int value){ glPixelStorei(what, value); glChk; }

  void texImage2D(int target, int level, int internalFrmt, int width, int height, int border, int format, int type, const(void)[] data) {
    glTexImage2D(target, level, internalFrmt, width, height, border, format, type, data.ptr);
    glChk;
  }

  void texStorage2D(int target, int levels, int internalFmt, int width, int height) {
    glTexStorage2D(target, levels, internalFmt, width, height);
    glChk;
  }

  void texSubImage2D(int target, int level, int xOffs, int yOffs, int width, int height, int format, int type, const(void)[] data) {
    glTexSubImage2D(target, level, xOffs, yOffs, width, height, format, type, data.ptr);
    glChk;
  }

  void getTexImage(int target, int level, int format, int type, void[] data){
    glGetTexImage(target, level, format, type, data.ptr);
    glChk;
  }

  void generateMipmap(int target) { glGenerateMipmap(target); glChk; }
  void texParameterf(int target, int pname, float pvalue) { glTexParameterf(target, pname, pvalue); glChk; }

  //resource managed things

  int genTexture()                     { int res; glGenTextures(1, &res); glChk; return res; }
  int genBuffer()                      { int res; glGenBuffers (1, &res); glChk; return res; }
  int createShader(int type)           { auto res = glCreateShader(type); glChk; return res; }
  int createProgram()                  { auto res = glCreateProgram();    glChk; return res; }

  void deleteTexture(int handle)       { if(!handle) return; glDeleteTextures(1, &handle); glChk; }
  void deleteBuffer (int handle)       { if(!handle) return; glDeleteBuffers (1, &handle); glChk; }
  void deleteShader (int shader)       { if(!shader) return; glDeleteShader  (shader    ); glChk; }
  void deleteProgram(int prg   )       { if(!prg   ) return; glDeleteProgram (prg       ); glChk; }
}

//GLHandle, GlResource ////////////////////////////////////////

class GLHandle(string resName, string gen, string del){
  const{
    string name;
    size_t size;
    int handle;
  }

  override string toString() const{ return format!"%d \"%s\" %d"(handle, name, size); }

  this(string name, size_t size, int param=0){
    this.name = name.empty ? "<noname>" : name;
    this.size = size;
    mixin("handle = "~gen~";");
    handles[handle] = this;
  }

  private bool mustDelete;
  void release(){ mustDelete = true; }

  ~this(){ //must NOT be called from GC
    mixin(del~"(handle);");
    handles.remove(handle);
  }

  __gshared static{
    typeof(this)[int] handles;
    auto sizeBytes(){ return handles.values.map!"a.size".sum; };
    auto stats(){ return format!"%ss:(%s, %sKB)"(resName, handles.values.count, sizeBytes>>10); }
    void update(){
      foreach(h; handles.values.filter!(a => a.mustDelete).array){
        handles.remove(h.handle);
        h.destroy;
      }
    }
  }
}

alias GLBufferHandle  = GLHandle!("Buffer" , "gl.genBuffer"          , "gl.deleteBuffer" );
alias GLTextureHandle = GLHandle!("Texture", "gl.genTexture"         , "gl.deleteTexture");
alias GLProgramHandle = GLHandle!("Program", "gl.createProgram"      , "gl.deleteProgram");
alias GLShaderHandle  = GLHandle!("Shader" , "gl.createShader(param)", "gl.deleteShader" );

alias GLAllHandles = AliasSeq!(GLBufferHandle, GLTextureHandle, GLProgramHandle, GLShaderHandle);

private void updateGLHandles(){
  foreach(T; GLAllHandles) T.update;
}

auto glHandleStats(string separ=" "){
  string[] res;
  foreach(T; GLAllHandles) res ~= T.stats;
  return res.join(separ);
}

auto glHandleStats2(){
  string[] res;
  foreach(T; GLAllHandles){
    res ~= T.stats;
    res ~= T.handles.values.sort!((a,b)=>a.handle<b.handle).map!(a=>"  "~a.text).array;
  }
  return res;
}


abstract class GlResource{
  string resName() const;
  size_t resSize() const;
  string resInfo() const; //resource specific stuff
}

/// Shader class //////////////////////////////////////////////////////////////////////////

class Shader:GlResource {
public:
  string shaderTypes() const{
    string res;
    if(vertexShader  ) res ~= "V";
    if(geometryShader) res ~= "G";
    if(fragmentShader) res ~= "F";
    return res;
  }

  override string resName() const    { return name; }
  override size_t resSize() const    { return [vertexShaderSrc, geometryShaderSrc, fragmentShaderSrc].map!(x=>x.length).sum; }
  override string resInfo() const    { return "["~shaderTypes~"] "~attribs.keys.to!string; }
private:
  mixin CustomEnforce!"GLShader error"; //todo: customEnforce

  void error(string s){ throw new Exception(`Shader("`~name~`"): `~s); } //todo: ennek fatal errornak kene lenni, kiveve ha egy shadertoyszeruseget csinalok...

  GLShaderHandle vertexShader, geometryShader, fragmentShader;
  GLProgramHandle programObject;

  struct AttribRec{ string name; int loc; int type; int count; }
  AttribRec[string] attribs;

  void splitUnifiedShader(string ush, out string vsh, out string gsh, out string fsh){
    //markers
    const mv = "@vertex:";
    const mg = "@geometry:";
    const mf = "@fragment:";

    auto pv = indexOfWord(ush, mv, 0          );  if(pv<0) error(`Can't split unified shader: "`~mv~`" marker not found.`);
    auto pg = indexOfWord(ush, mg, pv         );  //can be empty
    auto pf = indexOfWord(ush, mf, max(pv, pg));  if(pf<0) error(`Can't split unified shader: "`~mf~`" marker not found.`);

    if(pv>pf) error(`Vertex shader must be the first.`);
    if(pg>=0 && !(pv<pg && pg<pf)) error(`Geometry shader must be in the middle.`);

    string common = ush[0..pv];
    if(pg>=0){
      vsh = common~ush[pv+mv.length..pg];
      gsh = common~ush[pg+mg.length..pf];
      fsh = common~ush[pf+mf.length..$];
    }else{
      vsh = common~ush[pv+mv.length..pf];
      fsh = common~ush[pf+mf.length..$];
    }

    //TODO: a szetvalasztast ugy csinalja, hogy a sorok erintetlenek maradjanak es akkor a hibat ki tudja jelezni az IDE
  }

  string precompile(string src, string[] options){
    return src;
  }

  auto loadShader(char typeChr, int type, string source)
  {
    auto shader = new GLShaderHandle(resName~"."~typeChr, source.length, type);
    try{
      gl.shaderSource(shader.handle, source);
      gl.compileShader(shader.handle);
      if(!gl.getShaderCompiled(shader.handle)){
        auto err = gl.getShaderInfoLog(shader.handle);
        File(appPath, "shader.error").writeStr(source~"\n=============================================\n"~err);
        error("Compile error:\n"~err);
      }
      return shader;
    }catch(Throwable o){
      shader.release;
      shader = null;
      error(o.toString);
    }
    return null;
  }

  void compile(){
                              vertexShader   = loadShader('v', GL_VERTEX_SHADER  , vertexShaderSrc  );
    if(geometryShaderSrc!="") geometryShader = loadShader('g', GL_GEOMETRY_SHADER, geometryShaderSrc);
                              fragmentShader = loadShader('f', GL_FRAGMENT_SHADER, fragmentShaderSrc);

    programObject = new GLProgramHandle(resName, resSize);

                       gl.attachShader(programObject.handle, vertexShader  .handle);
    if(geometryShader) gl.attachShader(programObject.handle, geometryShader.handle);
                       gl.attachShader(programObject.handle, fragmentShader.handle);

    gl.linkProgram(programObject.handle);

    if(!gl.getProgramLinked(programObject.handle))
      error("Link error\r\n"~gl.getProgramInfoLog(programObject.handle));
  }

  void collectAttribs(){
    int n; gl.getProgramiv(programObject.handle, GL_ACTIVE_ATTRIBUTES, &n);

    foreach(i; 0..n){
      AttribRec r;
      gl.getActiveAttrib(programObject.handle, i, r.count, r.type, r.name);
      r.loc = gl.getAttribLocation(programObject.handle, r.name);
      attribs[r.name] = r;
    }
    attribs.rehash;
  }
public:
  const string name, vertexShaderSrc, geometryShaderSrc, fragmentShaderSrc;

  this(string name, string unifiedSrc){
    this.name = name;

    string vs, gs, fs;
    splitUnifiedShader(unifiedSrc, vs, gs, fs);
    vertexShaderSrc   = vs;
    geometryShaderSrc = gs;
    fragmentShaderSrc = fs;

    compile;
    collectAttribs;
  }

  void use() { gl.useProgram(programObject.handle); }

  //TODO: az use-ket csak akkor hivni, ha kell
  //TODO: a getUniformLocation-bol kompilalas kozben listat felepiteni!
  void uniform(T)(string name, T val, bool mustSucceed=true, string file=__FILE__, int line=__LINE__){
    use;
    int loc = gl.getUniformLocation(programObject.handle, name);

    if(loc<0){ //what if not found:
      if(mustSucceed) error(`Uniform not found: "`~name~`"`);
                 else return; //just hide the error
    }

    try{
      gl.uniform(loc, val);
    }catch(Throwable t){
      throw new Exception("Error setting uniform: %s.%s = %s %s raised %s".format(this.name, name, T.stringof, val, t.msg), file, line);
    }
  }

  //TODO: a getUniformLocation-bol kompilalas kozben listat felepiteni!
  void uniform(T)(in T val, bool mustSucceed=true){
    foreach(name; FieldNamesWithUDA!(T, UNIFORM, true)){
      auto u = getUDA!(mixin("T.", name), UNIFORM);
      if(u.name == "") u.name = name;
      uniform(u.name, __traits(getMember, val, name), mustSucceed);
    }
  }

  int getAttribLocation(string name){
    int loc = gl.getAttribLocation(programObject.handle, name);
    if(loc<0) error(`Attrib not found: "`~name~`"`);
    return loc;
  }

  void attrib(VBO vbo, int loc, int type, int size, bool normalize = false, int offset = 0){
    use; vbo.bind;
    gl.vertexAttribPointer(loc, size, type, normalize, vbo.stride, cast(void*)offset);
    gl.enableVertexAttribArray(loc); //TODO: disable it afterwards
  }

  void attrib(VBO vbo, string name, int type, int size, bool normalize = false, int offset = 0){
    attrib(vbo, getAttribLocation(name), type, size, normalize, offset);
  }

  void attribI(VBO vbo, int loc, int type, int size, int offset = 0){
    use; vbo.bind;
    gl.vertexAttribIPointer(loc, size, type, vbo.stride, cast(void*)offset);
    gl.enableVertexAttribArray(loc); //TODO: disable it afterwards
  }

  void attribI(VBO vbo, string name, int type, int size, int offset = 0){
    attribI(vbo, getAttribLocation(name), type, size, offset);
  }

  private bool attrib(VBO vbo, string name, string srcType, int offset, bool mustExists = false){
    if(name=="") return false;
    auto dst = name in attribs;
    if(!dst){
      return false; //field not found in shader. Ignore this error.
    }

    if(dst.count!=1) error("attrib("~name~") array attribs not supported yet.");

    //todo: working with typenames is compiler-implementation dependent.
         if(srcType.among("Vector!(float, 2)", "float[2]"   ) && (dst.type==GL_FLOAT_VEC2  )) attrib (vbo, dst.loc, GL_FLOAT        , 2, false, offset);
    else if(srcType.among("Vector!(float, 3)", "float[3]"   ) && (dst.type==GL_FLOAT_VEC3  )) attrib (vbo, dst.loc, GL_FLOAT        , 3, false, offset);
    else if(srcType.among("Vector!(float, 4)", "float[4]"   ) && (dst.type==GL_FLOAT_VEC4  )) attrib (vbo, dst.loc, GL_FLOAT        , 4, false, offset);
    else if(srcType.among("int", "uint", "Vector!(ubyte, 3)") && (dst.type==GL_FLOAT_VEC3  )) attrib (vbo, dst.loc, GL_UNSIGNED_BYTE, 3, true , offset);
    else if(srcType.among("int", "uint", "Vector!(ubyte, 4)") && (dst.type==GL_FLOAT_VEC4  )) attrib (vbo, dst.loc, GL_UNSIGNED_BYTE, 4, true , offset);
    else if(srcType.among("float"                           ) && (dst.type==GL_FLOAT       )) attrib (vbo, dst.loc, GL_FLOAT        , 1, false, offset);
    else if(srcType.among("int"                             ) && (dst.type==GL_INT         )) attribI(vbo, dst.loc, GL_INT          , 1,        offset);
    else if(srcType.among("uint"                            ) && (dst.type==GL_UNSIGNED_INT)) attribI(vbo, dst.loc, GL_UNSIGNED_INT , 1,        offset);
    else error("attrib("~name~") unable to convert "~srcType~"->"~text(dst.type));

    return true;
  }

  void attrib(VBO vbo){
    bool any;
    if(!vbo.attrName.empty){
      any |= attrib(vbo, vbo.attrName, vbo.elementType, 0);
    }else{
      foreach(const ref f; vbo.elementFields){
        any |= attrib(vbo, f.name, f.type, f.offset);
      }
    }
    if(!any) error("attrib(VBO) failed to connect any attributes. "~vbo.attrName);
  }

  ~this(){
    if(vertexShader  ) vertexShader  .release;
    if(geometryShader) geometryShader.release;
    if(fragmentShader) fragmentShader.release;
    if(programObject ) programObject .release;
  }
}


/// load a shader and cache it for frequent access.
auto loadShader(File file){

  static Shader shaderFromText(string text){
    text = text.strip.strip2("q{", "}"); //put in a q{} string for the syntaxt highlighter. Quite lame... Ide should know how to deal with .glsl file.
    return new Shader("unnamed/cached", text);
  }

  return loadCachedFile!shaderFromText(file);
}


/// VBO class ///////////////////////////////////////////////////////////////////////////////

class VBO:GlResource {
public:
  override string resName() const    { return elementFields.map!(a=>a.name).array.text; }
  override size_t resSize() const    { return count*stride; }
  override string resInfo() const    { return format("count:%s stride:%s elements:%s", count, stride, elementFields.map!(a=>a.name).array); }
private:
  alias Handle = GLBufferHandle;

  Handle buffer; //TODO: readonly property
  int stride, count;

  struct Field { string name, type; int offset; }
  Field[] elementFields;
  string elementType;

public:
  @property auto handle() const { return buffer.handle; }
  @property auto shortName() const { return format!"VBO(%d)"(handle); }
  @property auto logName() const { return "\33\13"~shortName~"\33\7"; }

  const string attrName; //only if VBO is not a struct

  int getCount() const { return count; }

  this(const(void*) data, int count, int recordSize, string attrName="", int accessType = GL_STATIC_DRAW){
    this.stride = recordSize;
    this.count = count;
    this.attrName = attrName;
    buffer = new Handle(resName, resSize);
    if(logVBO) LOG(logName, "created", "resSize:", resSize);

    bind;

    //if(logVBO) LOG("bufferData", "count:", count, "stride:", stride, "fields:", "["~elementFields.map!"a.name".join(", ")~"]");
    gl.bufferData(GL_ARRAY_BUFFER, count*stride, data, accessType);
  }

  this(T)(const(T)[] data, string attrName="", int accessType = GL_STATIC_DRAW){
    elementType = T.stringof;
    static if(!isVector!T && !isMatrix!T){
      //search struct fields
      foreach(i, n; FieldNameTuple!T){
        static if(!n.empty) elementFields ~= Field(n, FieldTypeTuple!T[i].stringof, __traits(getMember, T, n).offsetof);
      }
    }

    this(data.ptr, cast(int)data.length, cast(int)data[0].sizeof, attrName, accessType);
  }

  void bind(){
    //if(logVBO) LOG("bind");
    gl.bindBuffer(GL_ARRAY_BUFFER, handle); //TODO: csak akkor bind, ha kell. Ehhez mindig resetelni kell a currentet a rajzolas kezdetekor
  }

  void draw(int primitive, int start = 0, int end = int.max){
    if(start>=count) return;
    if(start<0) start = 0;
    if(end>count) end = count;
    if(end<=start) return;

    bind;

    //if(logVBO) LOG("drawArrays", primitive.to!string(16), "[%d..%d]".format(start, end), "cnt:", end-start);
    gl.drawArrays(primitive, start, end-start);
  }

  ~this(){
    //if(logVBO) LOG("release (destroy)");
    buffer.release; //elvileg nem volna szabad hivatkozni erre a member classra
  }

}


/// GLTexture class ////////////////////////////////////////////////////////////////////////////

enum GLTextureFilter { Nearest, Linear, Mipmapped }

// todo: this shit must be rethinked
enum GLTextureType   { Unknown, RGBA8, RGBA16, L8}

int GL_FORMAT(GLTextureType type){ with(GLTextureType)final switch(type){
    case RGBA8  : return GL_RGBA  ;
    case RGBA16 : return GL_RGBA16;
    case L8     : return GL_LUMINANCE;
case Unknown: return 0;}}

int GL_FORMAT2(GLTextureType type){ with(GLTextureType)final switch(type){ //for texStorage
    case RGBA8  : return GL_RGBA8 ;
    case RGBA16 : return GL_RGBA16;
    case L8     : return -1;//GL_R8;
case Unknown: return 0;}}

int GL_DATATYPE(GLTextureType type){ with(GLTextureType )final switch(type){
    case RGBA8  :
    case L8     : return GL_UNSIGNED_BYTE ;
    case RGBA16 : return GL_UNSIGNED_SHORT;
case Unknown: return 0; }}

int GL_COMPONENTSIZE(GLTextureType type){ with(GLTextureType )final switch(type){
    case RGBA8  :
    case L8     : return 1;
    case RGBA16 : return 2;
case Unknown: return 0; }}

int GL_COMPONENTCOUNT(GLTextureType type){ with(GLTextureType )final switch(type){
    case L8     : return 1;
    case RGBA8  : return 4;
    case RGBA16 : return 4;
case Unknown: return 0; }}

int GL_TEXELSIZE(GLTextureType type){ return GL_COMPONENTSIZE(type)*GL_COMPONENTCOUNT(type); }

class GLTexture:GlResource {
public:
  override string resName() const    { return name; }
  override size_t resSize() const    { return width*height*GL_TEXELSIZE(type); }
  override string resInfo() const    { return format("size:%sx%s format:%s isCustom:%s mipEnabled:%s mipBuilt:%s", width, height, type, isCustom, mipmapEnabled, mipmapBuilt); }
private:
  GLTextureHandle handle;
  bool mipmapBuilt, mipmapEnabled;
  bool isCustom;

  GLTextureType type_;
  int width_, height_;

  //data for rebind
  int lastSlot;
  GLTextureFilter lastFilter;
  bool lastClamped=true;

  public uint changedCnt; //for synching with players

  void setup(bool isC, GLTextureType t, int w, int h, bool me){
    isCustom = isC;  //todo: every gltexture is custom because megaTexturing
    type_ = t; width_ = w; height_ = h;
    mipmapEnabled = me;
  }

  void enforce(bool c, lazy string msg, string file=__FILE__, int line=__LINE__, string fv = __FUNCTION__){ //todo: enforce with template params
    .enforce(c, "GLTexture["~name~"] "~msg, file, line, fv);
  }

public:
  immutable string name;
  @property width ()const { return width_ ; }
  @property height()const { return height_; }
  @property size  ()const { return ivec2(width, height); }
  @property type  ()const { return type_  ; }

  override string toString()const{ return `Texture("%s", %s, %s, mipmap(en=%s, built=%s), handle=%X)`.format(name, size, type, mipmapEnabled.to!int, mipmapBuilt.to!int, handle ? handle.handle : 0); }

/*  //load from a file        since megaTexturing is implemented, this is obsolete.
  this(string fileName, bool mipmapEnabled_ = true){ //todo: FileName type
    glResources.register(this);
    name = fileName; //will load on first bind
    setup(false, GLTextureType.RGBA8, 0, 0, mipmapEnabled_);
  }*/

  //create a custom texture
  this(string name_, int width_, int height_, GLTextureType type_, bool mipmapEnabled_ = false){
    name = name_;
    setup(true, type_, width_, height_, mipmapEnabled_);
  }

  private void checkBinding(string file = __FILE__, int line = __LINE__, string fn = __FUNCTION__){
    enforce(handle.handle!=0, "GLTexture not exists.", file, line, fn);
    enforce(gl.getInteger(GL_TEXTURE_BINDING_2D)==handle.handle, "GLTexture not bound.", file, line, fn);
  }

  int texelSize()const{ return GL_TEXELSIZE(type); }

  private bool prepareInputRect(int x, int y, ref int sx, ref int sy){
    //set default size to texture.size
    if(sx==int.min) sx = width -x;
    if(sy==int.min) sy = height-y;

    enforce(x>=0 && x+sx<=width , "Out of range X");
    enforce(y>=0 && y+sy<=height, "Out of range Y");

    return sx>0 && sy>0;
  }

  bool isCompatibleWith(in Bitmap bmp)const {
    assert(0, "notimpl");
    return bmp.channels==4 && type==GLTextureType.RGBA8
        || bmp.channels==1 && type==GLTextureType.L8;
  }

  bool isCompatibleType(T)(){ //todo: more texture type support
         static if(is(T==ubyte)) return type==GLTextureType.L8;
    else static if(is(T==RGBA )) return type==GLTextureType.RGBA8;
    else static assert(0, "unhandled textureType");
  }

  void enforceType(T)(){
    enforce(isCompatibleType!T, "incompatible texture type "~T.stringof~" and "~type.text);
  }

  //todo: ha nincs binding, akkor az access violation megsemmisul, a program meg crashol.

  void upload(const(void)[] data, int x=0, int y=0, int xs=int.min, int ys=int.min, int stride=0){ //todo: must bind first! Ez maceras igy, kell valami automatizalas erre.
    if(!prepareInputRect(x, y, xs, ys)) return;

    //check required buffer size
    int bytes = (stride ? stride : xs)*ys*texelSize;
    enforce(data.length>=bytes, "Insufficient input data x=%s, y=%s, sx=%s, sy=%s, stride=%s, reqBytes=%s data.length=%s".format(x, y, xs, ys, stride, bytes, data.length));

    //do the actual upload
    checkBinding;
    gl.pixelStore(GL_UNPACK_ROW_LENGTH, stride);
    gl.texSubImage2D(GL_TEXTURE_2D, 0, x, y, xs, ys, GL_FORMAT(type), GL_DATATYPE(type), data);

    mipmapBuilt = false; //todo: rebuild mipmap
  }

  void fill(T)(const T data, int x=0, int y=0, int xs=int.min, int ys=int.min, int stride=0){ //todo: must bind first! Ez maceras igy, kell valami automatizalas erre.
    enforceType!T;
    if(!prepareInputRect(x, y, xs, ys)) return;
    int bytes = (stride ? stride : xs)*ys*texelSize;

    auto dataArr = [data];
    auto byteArr = cast(ubyte[])dataArr;
    auto tmp = byteArr.replicate(bytes/byteArr.length.to!int).array;
    upload(tmp, x, y, xs, ys, stride);
  }

  //upload a subrect from an image2D
  void upload(T)(Image!(T, 2) img, int x=0, int y=0, int sx=int.min, int sy=int.min){ //todo: must bind first! Ez maceras igy, kell valami automatizalas erre.
    if(!isCompatibleType!T){ // incompatible format?
      upload(new Bitmap(img), x, y, sx, sy); // Bitmap will automatically convert
    }else{ // compatible
      //adjust size to image dimensions also, not just to the texture
      if(sx==int.min) sx = min(width -x, img.width );
      if(sy==int.min) sy = min(height-y, img.height);

      upload(img.impl, x, y, sx, sy, img.stride);
    }
  }

  void upload(Bitmap bmp, int x=0, int y=0, int sx=int.min, int sy=int.min){
    switch(type){
      case GLTextureType.L8   : upload(bmp.get!ubyte, x, y, sx,sy); break;
      case GLTextureType.RGBA8: upload(bmp.get!RGBA , x, y, sx,sy); break;
      default: raise("unhandled texture type: "~type.text);
    }
  }

  // specual uploads for textures holding sequential data. Consider using 1D textures in the future?
  void uploadRows(const(void)[] data, int startRow, int numRows){ //todo: must bind first! Ez maceras igy, kell valami automatizalas erre.
    upload(data, 0, startRow, width, numRows);
  }

  void uploadSeq(const(void)[] data, int byteOfs=0){ //seq is a byte array stored continuously in the texture
    if(data.length==0) return;
    int ts = texelSize;
    int bytes = width*height*ts;
    enforce(byteOfs>=0 && byteOfs+data.length<=bytes, "Insufficient data");
    enforce(data.length%ts==0, "Align error: data.length");
    enforce(byteOfs%ts==0, "Align error: byteOfs");

    byteOfs/=ts;

    int y = byteOfs/width;
    int f = byteOfs%width;
    if(f!=0){ //first row
      int xs = min(width-byteOfs, cast(int)(data.length/ts));
      upload(data, byteOfs, y, xs, 1);
      data = data[xs*ts..$];
      y++;
    }

    if(data.length==0) return;

    int ys = cast(int)data.length/(width*ts);
    if(ys>0){ //whole rows
      upload(data, 0, y, width, ys);
      data = data[width*ys*ts..$];
      y += ys;
    }

    if(data.length==0) return;

    upload(data, 0, y, cast(int)data.length/ts, 1); //last row
  }


  // download a subrect from the texture. It's unsafe with the format!
  auto downloadImage(T)(int x=0, int y=0, int xs=int.min, int ys=int.min){
    enforceType!T;

    if(!prepareInputRect(x, y, xs, ys))
      return image2D(0, 0, T.init); //nothing to copy

    auto img = image2D(size, T(0)); //!!! only for 8 bit
    checkBinding;
    gl.pixelStore(GL_UNPACK_ROW_LENGTH, 0);
    gl.getTexImage(GL_TEXTURE_2D, 0, GL_FORMAT(type), GL_DATATYPE(type), img.asArray);

    // note: there is no such thing as glGetTexSubimage2D(), sigh...
    if(ivec2(xs, ys) != size)
      img = img[x..x+xs, y..y+ys]; // subrect emulation. Fucking ineffective, had to load the whole tedture....

    return img;
  }

  Bitmap downloadBitmap(int x=0, int y=0, int xs=int.min, int ys=int.min){
    auto doit(T)(){ return new Bitmap(downloadImage!T(x, y, xs, ys)); }
    switch(type){
      case GLTextureType.L8     : return doit!ubyte;
      case GLTextureType.RGBA8  : return doit!RGBA;
      default: raise("unsupported TextureType: "~type.text); assert(0);
    }
  }

  int mipmapLevels() const{ return mipmapEnabled ? 1 : 1; } //todo: mipmaps

  void resize(int xs, int ys, bool preserve=true){
    if(xs==width && ys==height) return;

    const maxs = gl.maxTextureSize;
    enforce(xs.inRange(1, maxs) && ys.inRange(1, maxs), "Out of range");

    Bitmap bmp;
    if(preserve) bmp = downloadBitmap(0, 0, min(xs, width ), min(ys, height));

    checkBinding;
    width_ = xs; height_ = ys; mipmapBuilt = false;

    static if(UseOldTexImage2D){
      gl.texImage2D(GL_TEXTURE_2D, 0, GL_FORMAT(type), width, height, 0, GL_FORMAT(type), GL_DATATYPE(type), null);
    }else{
      //recreate the texture
      if(handle) handle.release;
      handle = new GLTextureHandle(resName, resSize);
      gl.bindTexture(GL_TEXTURE_2D, handle.handle);

      gl.texStorage2D(GL_TEXTURE_2D, mipmapLevels, GL_FORMAT2(type), width, height);
    }

    if(preserve) upload(bmp);

    bind(lastSlot, lastFilter, lastClamped); //rebind it for mipmap
  }

  void fastBind(){
    gl.activeTexture(GL_TEXTURE(0));
    gl.bindTexture(GL_TEXTURE_2D, handle.handle);
  }

  void bind(int slot = 0, GLTextureFilter filter=GLTextureFilter.Mipmapped, bool clamped=true){
    enforce(inRange(slot, 0, 7), "Slot out of range");

    lastSlot = slot; lastFilter = filter; lastClamped = clamped;

    gl.activeTexture(GL_TEXTURE(slot));

    if(!handle){
      handle = new GLTextureHandle(resName, resSize);
      gl.bindTexture(GL_TEXTURE_2D, handle.handle);

      void[] dataToUpload;

/*      if(!isCustom){ //because of megaTexturing this is deprecated
        auto bmp = newBitmap(name);
        bmp.channels = 4; //todo: not just rgba8
        setup(isCustom, GLTextureType.RGBA8, bmp.width, bmp.height, mipmapEnabled);
        dataToUpload = bmp.data;
      }*/

      static if(UseOldTexImage2D){
        gl.texImage2D(GL_TEXTURE_2D, 0, GL_FORMAT(type), width, height, 0, GL_FORMAT(type), GL_DATATYPE(type), dataToUpload);
      }else{
        gl.texStorage2D(GL_TEXTURE_2D, mipmapLevels, GL_FORMAT2(type), width, height);
      }
    }

    if(!handle) return;

    gl.bindTexture(GL_TEXTURE_2D, handle.handle);

    //mipmap
    if(filter==GLTextureFilter.Mipmapped && !mipmapEnabled) filter = GLTextureFilter.Linear;

    if(filter==GLTextureFilter.Mipmapped && !mipmapBuilt) {
      gl.generateMipmap(GL_TEXTURE_2D);
      mipmapBuilt = true;
    }

    //min/mag filter
    int minFilt, magFilt;
    with(GLTextureFilter) final switch(filter){
      case Nearest   : minFilt = magFilt = GL_NEAREST; break;
      case Linear    : minFilt = magFilt = GL_LINEAR ; break;
      case Mipmapped : minFilt = GL_LINEAR_MIPMAP_LINEAR; magFilt = GL_LINEAR ; break;
    }

    gl.texParameterf(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, minFilt);
    gl.texParameterf(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, magFilt);

    if(filter==GLTextureFilter.Mipmapped){
      auto maxAniso = gl.getFloat(GL_MAX_TEXTURE_MAX_ANISOTROPY_EXT);
      gl.texParameterf(GL_TEXTURE_2D, GL_TEXTURE_MAX_ANISOTROPY_EXT, maxAniso);
    }

    //clamping
    gl.texParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S    , clamped ? GL_CLAMP_TO_EDGE : GL_REPEAT);
    gl.texParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T    , clamped ? GL_CLAMP_TO_EDGE : GL_REPEAT);

    gl.enable(GL_TEXTURE_2D);
  }

  void unBind(int slot=0)
  {
    gl.activeTexture(GL_TEXTURE(slot));
    gl.bindTexture(GL_TEXTURE_2D, 0);
  }

  ~this(){
    if(handle) handle.release;
  }
}

/// GLTesselator //////////////////////////////////////////////////////////////////////////////

private{

  struct TessVertex{
    int idx;
    vec2 v;
  }

  TessVertex*[] tessVertices;

  auto addVertex(in vec2 v){
    auto r = new TessVertex(cast(int)tessVertices.length, v);
    tessVertices ~= r;
    return r;
  }

  auto findAddVertex(in vec2 v){
    foreach(i; tessBaseVertexCount..tessVertices.length)
      if(tessVertices[i].v==v)
        return tessVertices[i];

    return addVertex(v);
  }

  public struct TessResult{
    vec2[] vertices;
    int[3][] triangles;
    int[2][] lines;
    string error;
  }

  TessResult tessResult;

  bool tessBoundaryPass;
  size_t tessBaseVertexCount;
  int tessActPrimitive;
  int tessIdx;
  int tessLast0;
  int tessLast1;

  extern(Windows){
    void cbBegin(int type){
      //GLU_TRIANGLE_FAN, GLU_TRIANGLE_STRIP, or GLU_TRIANGLES
      //if(GLU_TESS_BOUNDARY_ONLY == 1) -> GLU_LINE_LOOP
      //"glBegin(%d)".writefln(type);

      tessActPrimitive = type; tessIdx = 0;
    }
    //------------------------------------------------------------------------------

    void cbEnd(){
      //"glEnd".writeln;

      if(tessActPrimitive==GL_LINE_LOOP && tessIdx>0){
        tessResult.lines ~= [tessLast1, tessLast0]; //last looped segment
      }
      tessActPrimitive = 0; tessIdx = 0;
    }

    void cbVertex(in TessVertex v){
      //"glVertex %d %s".writefln(v.idx, v.v);

      switch(tessActPrimitive){  //todo: egybeagyazott switch()-ek. Ezeket lehetne grafikusan optolni...
        case GL_TRIANGLE_FAN:{
          switch(tessIdx){
            case 0: tessLast0 = v.idx; break;//todo: case 0, case 1 mindegyiknel kozos, ha mar tesztelve van, akkor ki kell pakolni.
            case 1: tessLast1 = v.idx; break;
            default:{
              tessResult. triangles ~= [tessLast0, tessLast1, v.idx];
              tessLast1 = v.idx;
            }
          }
        break;}
        case GL_TRIANGLE_STRIP:{
          switch(tessIdx){
            case 0: tessLast0 = v.idx; break;
            case 1: tessLast1 = v.idx; break;
            default:{
              tessResult.triangles ~= tessIdx&1 ? [tessLast1, tessLast0, v.idx]
                                                : [tessLast0, tessLast1, v.idx];
              tessLast0 = tessLast1;
              tessLast1 = v.idx;
            }
          }
        break;}
        case GL_TRIANGLES:{
          switch(tessIdx%3){
            case 0: tessLast0 = v.idx; break;
            case 1: tessLast1 = v.idx; break;
            default: tessResult.triangles ~= [tessLast0, tessLast1, v.idx];
          }
        break;}
        case GL_LINE_LOOP:{
          switch(tessIdx){
            case 0: tessLast0 = v.idx; break;
            case 1: tessLast1 = v.idx; tessResult.lines ~= [tessLast0, tessLast1]; break;
            default: tessResult.lines ~= [tessLast1, v.idx]; tessLast1 = v.idx;
          }
        break;}
        default: enforce(0, "tess: invalid primitive %s".format(tessActPrimitive));
      }

      tessIdx++;
    }

    void cbCombine(double* coords, double* orig, float* weight, out TessVertex* dataOut){
      auto v = vec2(coords[0], coords[1]);
      if(tessBoundaryPass) dataOut = findAddVertex(v);
                      else dataOut = addVertex    (v);

      //"combine %d %s".writefln(dataOut.idx, dataOut.v);
    }

    void cbError(int err){
      tessResult.error = GLFuncts.glErrorStr(err);
      //throw new Exception("GLTesselator.Error: "~GLFuncts.glErrorStr(err));
    }

  }

  void* tess;
  int tessError;

  void tessInit(){
    tessResult = TessResult.init;
    tessVertices = [];

    if(tess) return;
    with(gl){
      tess = gluNewTess();
      gluTessCallback(tess, GLU_TESS_BEGIN  , cast(void*)&cbBegin  );
      gluTessCallback(tess, GLU_TESS_VERTEX , cast(void*)&cbVertex );
      gluTessCallback(tess, GLU_TESS_END    , cast(void*)&cbEnd    );
      gluTessCallback(tess, GLU_TESS_COMBINE, cast(void*)&cbCombine);
      gluTessCallback(tess, GLU_TESS_ERROR  , cast(void*)&cbError  );
      gluTessNormal(tess, 0, 0, 1);
    }
    //"tess created".writeln;
  }
}

TessResult tesselate(in vec2[][] contours, TessWinding winding = TessWinding.nonZero, bool boundary = true){ with(gl){
  tessInit;
  double[3] dv = [0, 0, 0];

  gluTessProperty(tess, GLU_TESS_WINDING_RULE, winding);

  //surface pass
  tessBoundaryPass = false;
  gluTessProperty(tess, GLU_TESS_BOUNDARY_ONLY, tessBoundaryPass);
  gluTessBeginPolygon(tess, null);
  foreach(const contour; contours){
    gluTessBeginContour(tess); //note: gluTessNextContour is for more control
    foreach(const vIn; contour){
      dv[0] = vIn.x; dv[1] = vIn.y;
      gluTessVertex(tess, dv.ptr, cast(void*)addVertex(vIn));
    }
    gluTessEndContour(tess);
  }
  tessBaseVertexCount = tessVertices.length; //save the base size here, the base vertices will be the same
  gluTessEndPolygon(tess);

  //boundary pass
  if(boundary){
    tessBoundaryPass = true;
    gluTessProperty(tess, GLU_TESS_BOUNDARY_ONLY, tessBoundaryPass);
    gluTessBeginPolygon(tess, null);
    int n = 0;
    foreach(const contour; contours){
      gluTessBeginContour(tess); //note: gluTessNextContour is for more control
      foreach(const vIn; contour){
        dv[0] = vIn.x; dv[1] = vIn.y;
        gluTessVertex(tess, dv.ptr, cast(void*)(tessVertices[n++]));
      }
      gluTessEndContour(tess);
    }
    gluTessEndPolygon(tess);
  }

  //enforce(dv[2]==0, "tess fatal error: dv[2]!=0");

  //transfer the vertices
  tessResult.vertices = tessVertices.map!"a.v".array;
  tessVertices = [];

  return tessResult;
}}

TessResult tesselate(in vec2[] contour, TessWinding winding = TessWinding.nonZero, bool boundary = true){ return tesselate([contour], winding, boundary); }


/// GLWindow class //////////////////////////////////////////////////////////////////////////

class GLWindow: Window{
public:

  //Drawing dr, drGUI;
  View2D view;
  MouseState mouse;
  private View2D viewGUI_;

  auto viewGUI() {
    viewGUI_.scale = 1;
    viewGUI_.origin = clientSizeHalf;
    viewGUI_.skipAnimation;
    return viewGUI_;
  }

private:
  HGLRC frc;

  void oldSetPixelFormat(HDC dc)
  {
    PIXELFORMATDESCRIPTOR pfd;
    with(pfd){
      nSize = pfd.sizeof;
      nVersion = 1;
      dwFlags = PFD_SUPPORT_OPENGL | PFD_SWAP_EXCHANGE | PFD_DRAW_TO_WINDOW | PFD_DOUBLEBUFFER;
      iPixelType = PFD_TYPE_RGBA;
      cColorBits = 32;
      cAccumBits = 0;
      cDepthBits = 24;
      cStencilBits = 8;
      iLayerType = PFD_MAIN_PLANE;
    }
    enforce(SetPixelFormat(dc, ChoosePixelFormat(dc, &pfd), &pfd), "SetPixelFormat fail");
  }

  void newSetPixelFormat(HDC dc, int samples){
    retry:

    if(samples<=1 || wglChoosePixelFormatARB is null){
      oldSetPixelFormat(dc);
      return;
    }

    const float[] attribFList = [ 0, 0, ];
    const int[] attribIList = [
        WGL_DRAW_TO_WINDOW_ARB, GL_TRUE,
        WGL_SUPPORT_OPENGL_ARB, GL_TRUE,
        WGL_DOUBLE_BUFFER_ARB, GL_TRUE,
        WGL_PIXEL_TYPE_ARB, WGL_TYPE_RGBA_ARB,
        WGL_COLOR_BITS_ARB, 32,
        WGL_DEPTH_BITS_ARB, 24,
        WGL_STENCIL_BITS_ARB, 8,
        WGL_SAMPLE_BUFFERS_ARB, GL_TRUE,
        WGL_SAMPLES_ARB, samples,
        0, 0, //End
    ];

    int pixelFormat, numFormats;
    bool ok = wglChoosePixelFormatARB(dc, attribIList.ptr, attribFList.ptr, 1, &pixelFormat, &numFormats);

    if(!ok || numFormats<1){  //try again with smalle multisampling, or with the old shit
      samples /= 2;  goto retry;
    }

    PIXELFORMATDESCRIPTOR pfd;
    enforce(SetPixelFormat(dc, pixelFormat, &pfd), "wglSetPixelFormat fail");
  }

  void createRenderingContext()
  {
    if(frc) return;

    const multiSample = 6;
    newSetPixelFormat(hdc, multiSample);

    frc = wglCreateContext(hdc);  if(!frc) error("GLVindow.CreateRenderingContext failed");

    wglMakeCurrent;
    gl.loadFuncts;

    if(multiSample>1) gl.enable(GL_MULTISAMPLE);
  }

  void wglMakeCurrent(){
    enforce(hdc, "hdc in null");
    enforce(rc , "rc  is null");
    enforce(.wglMakeCurrent(hdc, rc));
  }

protected:
  override void onInitializeGLWindow(){
    createRenderingContext;

    //init drawing, view, mouse
    /*dr    = new Drawing;*/  view     = new View2D;  view    .owner = this;  view.centerCorrection = true;
    /*drGUI = new Drawing;*/  viewGUI_ = new View2D;  viewGUI_.owner = this;

    mouse = new MouseState;
  }

  override void onWglMakeCurrent(bool state){
    if(state) wglMakeCurrent;
         else .wglMakeCurrent(null, null);
    gl.active = state;
  }

  override void onFinalizeGLWindow(){
    if(!rc) return;
    enforce(wglDeleteContext(rc));
    frc = null;
  }

  override void onInitialZoomAll(){
    //called right after onCreate
    //todo: tryInitialZoom should work with the registry also
    if(!view.workArea.empty){ //workarea already set
      view.zoomAll_immediate;
      return;
    }

/*    if(view.workArea.empty && !dr.getBounds.empty){ //get the workarea from the drawing
      view.workArea = dr.getBounds;
      view.zoomAll_immediate;
    }*/
  }

  override void onMouseUpdate(){
    bool k(const string n) { return inputs[n].value!=0; }

    MouseState.MSAbsolute a;
    with(a){
      LMB    = k("LMB"  );
      RMB    = k("RMB"  );
      MMB    = k("MMB"  );
      shift  = k("Shift");
      alt    = k("Alt"  );
      ctrl   = k("Ctrl" );
      screen = screenToClient(inputs.mouseAct).iround;
      world  = view.invTrans(vec2(screen));
      wheel  = inputs["MW"].delta.iround;
    }
    mouse._updateInternal(a);

    mouse.screenRect = clientBounds;
    mouse.worldRect = bounds2(view.invTrans(vec2(mouse.screenRect.topLeft)), view.invTrans(vec2(mouse.screenRect.bottomRight)));
  }

  void updateViewClipBoundsAndMousePos(){
    // set extra info about mouse and bounds for view and viewGUI
    vec2 mp = mouse.act.screen;
    bounds2 bnd = clientBounds;

    with(view   ){ mousePos = invTrans(mp); clipBounds = invTrans(bnd); }
    with(viewGUI){ mousePos = invTrans(mp); clipBounds = invTrans(bnd); }
  }

  override void onUpdateViewAnimation(){
    view.updateAnimation(deltaTime, true/*invalidate*/);
    updateViewClipBoundsAndMousePos;
  }

  override void onUpdateUIBeginFrame(){
    import het.ui:im;
    im._beginFrame([im.TargetSurface(view), im.TargetSurface(viewGUI)]);
  }

  override void onUpdateUIEndFrame(){
    import het.ui:im;
    im._endFrame; //(bounds2(clientBounds))
  }

public:
  HGLRC rc() { return frc; }

  int VSynch = 1; //0:off, 1:on, -1:On when at max FrameRate(bogus)

  override void onBeginPaint()
  {
    super.onBeginPaint;
    onWglMakeCurrent(true);

    //dr.drawCnt = drGUI.drawCnt = 0; //if the user draws it, then GlWindow will not.

    with(clientRect) gl.viewport(left, top, right-left, bottom-top);
    gl.disable(GL_DEPTH_TEST); //no zbuffering by default

    textures.update; //upload pending textures.

    {//todo: this is a fix: if the clientSize changes between update() and draw() this will update it. Must rethink the update() draw() thing completely.
      updateViewClipBoundsAndMousePos;
      import het.ui:im;
      im.setTargetSurfaceViews(view, viewGUI);
    }
 }

  override void onPaint()
  {
    //descendants must not call super!
    gl.clearColor(clFuchsia);
    gl.clear(GL_COLOR_BUFFER_BIT);
  }

  private bool firstPaint;

  override void onEndPaint(){
    if(chkClear(view._mustZoomAll)) view.zoomAll;

    /*if(!dr.drawCnt){
      if(!firstPaint) onInitialZoomAll; //if dr has a painting
      dr.glDraw(view   );
    }
    if(!drGUI.drawCnt) drGUI.glDraw(viewGUI);

    lastFrameStats ~= "dr: %s * %d; ".format(dr.drawCnt, dr.totalDrawObj);
    lastFrameStats ~= "drGUI: %s * %d; ".format(drGUI.drawCnt, drGUI.totalDrawObj);*/

    firstPaint = true;
  }

  override void onSwapBuffers(){
    //must not call super!
    gl.swapInterval(VSynch);
    SwapBuffers(hdc);

    updateGLHandles;

    onWglMakeCurrent(false);
    super.onEndPaint;
  }

  void drawFPS(Drawing dr){
    with(dr){
      //FPS graph
      translate(vec2(0, 64+4));

      fontHeight = 7;

      lineWidth = 1;
      lineStyle = LineStyle.normal;
      auto groups = timeLine.getGroups;
      foreach(int idx; 1..groups.length.to!int){
        auto group = groups[idx], prevGroup = groups[idx-1];
        const scale = vec2(5000.0f, 4);
        const origin = vec2(clientWidth-2, 2);

        auto rect(double t0, double t1){
          bounds2 b;
          float base = prevGroup[$-1].t1;
          float len = group[$-1].t1 - base;
          b.low.x  = origin.x + (t0-base-len)*scale.x;
          b.high.x = origin.x + (t1-base-len)*scale.x;
          b.low.y  = origin.y + scale.y*(idx-1);
          b.high.y = b.low.y + scale.y*.9;
          return b;
        }

        auto rAll = rect(prevGroup[$-1].t1, group[$-1].t1);
        color = clBlack;
        fillRect(rAll);

        foreach(pass; 0..2) foreach(g; group){
          color = g.color;
          auto r = rect(g.t0, g.t1);
          if(pass==0){
            fillRect(r);
          }else{
            color = mix(color, clWhite, 0.5f);
            line(r.topLeft, r.bottomLeft);
          }
        }

        void mark(float f){
          auto r = rect(group[$-1].t1-(1/f), group[$-1].t1);
          color = clWhite;
          line(r.topLeft, r.bottomLeft);
        }

        mark(60); mark(30);
      }

      pop;

    }
  }

}
module turbojpeg.turbojpeg;

//Source:        https://github.com/rtbo/turbojpeg-d/blob/master/source/turbojpeg/turbojpeg.d
//Documentation: https://github.com/D-Programming-Deimos/jpeg-turbo/blob/master/source/libjpeg/turbojpeg.d


/+MIT License

Copyright (c) 2018 Remi Thebault

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.+/

// extra stuff for the integration with hetlib ////////////////////////////////////

pragma(lib, "turbojpeg-static.lib");

void tjChk(tjhandle h, int res, string what){
  if(res==0) return;
  import std.format;
  throw new Exception(format!"TurboJpeg Error: %s %s"(what, tjGetErrorStr2(h)));
}

//Auto-create a separate instance for each thread
import std.exception : enforce;
auto tjDecoder(){ static tjhandle h; if(!h){ h = tjInitDecompress; enforce(h, "tjInitDecompress() fail."); } return h; }
auto tjEncoder(){ static tjhandle h; if(!h){ h = tjInitCompress  ; enforce(h, "tjInitCompress() fail."  ); } return h; }

// original stuff //////////////////////////////////////////////////////////////////

import core.stdc.config : c_ulong;

extern (C) nothrow @nogc:

enum TJ_NUMSAMP = 6;

enum TJSAMP
{
    TJSAMP_444 = 0,
    TJSAMP_422,
    TJSAMP_420,
    TJSAMP_GRAY,
    TJSAMP_440,
    TJSAMP_411
}

alias TJSAMP_444 = TJSAMP.TJSAMP_444;
alias TJSAMP_422 = TJSAMP.TJSAMP_422;
alias TJSAMP_420 = TJSAMP.TJSAMP_420;
alias TJSAMP_GRAY = TJSAMP.TJSAMP_GRAY;
alias TJSAMP_440 = TJSAMP.TJSAMP_440;
alias TJSAMP_411 = TJSAMP.TJSAMP_411;

immutable int[TJ_NUMSAMP] tjMCUWidth = [8, 16, 16, 8, 8, 32];
immutable int[TJ_NUMSAMP] tjMCUHeight = [8, 8, 16, 8, 16, 8];

enum TJ_NUMPF = 12;

enum TJPF
{
    TJPF_RGB = 0,
    TJPF_BGR,
    TJPF_RGBX,
    TJPF_BGRX,
    TJPF_XBGR,
    TJPF_XRGB,
    TJPF_GRAY,
    TJPF_RGBA,
    TJPF_BGRA,
    TJPF_ABGR,
    TJPF_ARGB,
    TJPF_CMYK,
    TJPF_UNKNOWN = -1
}

alias TJPF_RGB = TJPF.TJPF_RGB;
alias TJPF_BGR = TJPF.TJPF_BGR;
alias TJPF_RGBX = TJPF.TJPF_RGBX;
alias TJPF_BGRX = TJPF.TJPF_BGRX;
alias TJPF_XBGR = TJPF.TJPF_XBGR;
alias TJPF_XRGB = TJPF.TJPF_XRGB;
alias TJPF_GRAY = TJPF.TJPF_GRAY;
alias TJPF_RGBA = TJPF.TJPF_RGBA;
alias TJPF_BGRA = TJPF.TJPF_BGRA;
alias TJPF_ABGR = TJPF.TJPF_ABGR;
alias TJPF_ARGB = TJPF.TJPF_ARGB;
alias TJPF_CMYK = TJPF.TJPF_CMYK;
alias TJPF_UNKNOWN = TJPF.TJPF_UNKNOWN;

immutable int[TJ_NUMPF] tjRedOffset = [0, 2, 0, 2, 3, 1, -1, 0, 2, 3, 1, -1];
immutable int[TJ_NUMPF] tjGreenOffset = [1, 1, 1, 1, 2, 2, -1, 1, 1, 2, 2, -1];
immutable int[TJ_NUMPF] tjBlueOffset = [2, 0, 2, 0, 1, 3, -1, 2, 0, 1, 3, -1];
immutable int[TJ_NUMPF] tjAlphaOffset = [-1, -1, -1, -1, -1, -1, -1, 3, 3, 0, 0, -1];
immutable int[TJ_NUMPF] tjPixelSize = [3, 3, 4, 4, 4, 4, 1, 4, 4, 4, 4, 4];

enum TJ_NUMCS = 5;

enum TJCS
{
    TJCS_RGB = 0,
    TJCS_YCbCr,
    TJCS_GRAY,
    TJCS_CMYK,
    TJCS_YCCK
}

alias TJCS_RGB = TJCS.TJCS_RGB;
alias TJCS_YCbCr = TJCS.TJCS_YCbCr;
alias TJCS_GRAY = TJCS.TJCS_GRAY;
alias TJCS_CMYK = TJCS.TJCS_CMYK;
alias TJCS_YCCK = TJCS.TJCS_YCCK;

enum TJFLAG_BOTTOMUP = 2;
enum TJFLAG_FASTUPSAMPLE = 256;
enum TJFLAG_NOREALLOC = 1024;
enum TJFLAG_FASTDCT = 2048;
enum TJFLAG_ACCURATEDCT = 4096;
enum TJFLAG_STOPONWARNING = 8192;
enum TJFLAG_PROGRESSIVE = 16384;

enum TJ_NUMERR = 2;

enum TJERR
{
    TJERR_WARNING = 0,
    TJERR_FATAL
}

alias TJERR_WARNING = TJERR.TJERR_WARNING;
alias TJERR_FATAL = TJERR.TJERR_FATAL;

enum TJ_NUMXOP = 8;

enum TJXOP
{
    TJXOP_NONE = 0,
    TJXOP_HFLIP,
    TJXOP_VFLIP,
    TJXOP_TRANSPOSE,
    TJXOP_TRANSVERSE,
    TJXOP_ROT90,
    TJXOP_ROT180,
    TJXOP_ROT270
}

alias TJXOP_NONE = TJXOP.TJXOP_NONE;
alias TJXOP_HFLIP = TJXOP.TJXOP_HFLIP;
alias TJXOP_VFLIP = TJXOP.TJXOP_VFLIP;
alias TJXOP_TRANSPOSE = TJXOP.TJXOP_TRANSPOSE;
alias TJXOP_TRANSVERSE = TJXOP.TJXOP_TRANSVERSE;
alias TJXOP_ROT90 = TJXOP.TJXOP_ROT90;
alias TJXOP_ROT180 = TJXOP.TJXOP_ROT180;
alias TJXOP_ROT270 = TJXOP.TJXOP_ROT270;

enum TJXOPT_PERFECT = 1;
enum TJXOPT_TRIM = 2;
enum TJXOPT_CROP = 4;
enum TJXOPT_GRAY = 8;
enum TJXOPT_NOOUTPUT = 16;
enum TJXOPT_PROGRESSIVE = 32;
enum TJXOPT_COPYNONE = 64;

struct tjscalingfactor
{
    int num;
    int denom;
}

struct tjregion
{
    int x;
    int y;
    int w;
    int h;
}

struct tjtransform
{
    tjregion r;
    int op;
    int options;
    void* data;
    int function(short* coeffs, tjregion arrayRegion, tjregion planeRegion,
            int componentIndex, int transformIndex, tjtransform* transform) customFilter;
}

alias tjhandle = void*;

extern (D) auto TJPAD(W)(in W width)
{
    return (width + 3) & (~3);
}

extern (D) auto TJSCALED(D)(in D dimension, in tjscalingfactor scalingFactor)
{
    return (dimension * scalingFactor.num + scalingFactor.denom - 1) / scalingFactor.denom;
}

tjhandle tjInitCompress();

int tjCompress2(tjhandle handle, const(ubyte)* srcBuf, int width, int pitch,
        int height, int pixelFormat, ubyte** jpegBuf, c_ulong* jpegSize,
        int jpegSubsamp, int jpegQual, int flags);

int tjCompressFromYUV(tjhandle handle, const(ubyte)* srcBuf, int width, int pad,
        int height, int subsamp, ubyte** jpegBuf, c_ulong* jpegSize, int jpegQual, int flags);

int tjCompressFromYUVPlanes(tjhandle handle, const(ubyte)** srcPlanes,
        int width, const(int)* strides, int height, int subsamp, ubyte** jpegBuf,
        c_ulong* jpegSize, int jpegQual, int flags);

c_ulong tjBufSize(int width, int height, int jpegSubsamp);

c_ulong tjBufSizeYUV2(int width, int pad, int height, int subsamp);

c_ulong tjPlaneSizeYUV(int componentID, int width, int stride, int height, int subsamp);

int tjPlaneWidth(int componentID, int width, int subsamp);

int tjPlaneHeight(int componentID, int height, int subsamp);

int tjEncodeYUV3(tjhandle handle, const(ubyte)* srcBuf, int width, int pitch,
        int height, int pixelFormat, ubyte* dstBuf, int pad, int subsamp, int flags);

int tjEncodeYUVPlanes(tjhandle handle, const(ubyte)* srcBuf, int width, int pitch,
        int height, int pixelFormat, ubyte** dstPlanes, int* strides, int subsamp, int flags);

tjhandle tjInitDecompress();

int tjDecompressHeader3(tjhandle handle, const(ubyte)* jpegBuf, c_ulong jpegSize,
        int* width, int* height, int* jpegSubsamp, int* jpegColorspace);

tjscalingfactor* tjGetScalingFactors(int* numscalingfactors);

int tjDecompress2(tjhandle handle, const(ubyte)* jpegBuf, c_ulong jpegSize,
        ubyte* dstBuf, int width, int pitch, int height, int pixelFormat, int flags);

int tjDecompressToYUV2(tjhandle handle, const(ubyte)* jpegBuf, c_ulong jpegSize,
        ubyte* dstBuf, int width, int pad, int height, int flags);

int tjDecompressToYUVPlanes(tjhandle handle, const(ubyte)* jpegBuf,
        c_ulong jpegSize, ubyte** dstPlanes, int width, int* strides, int height, int flags);

int tjDecodeYUV(tjhandle handle, const(ubyte)* srcBuf, int pad, int subsamp,
        ubyte* dstBuf, int width, int pitch, int height, int pixelFormat, int flags);

int tjDecodeYUVPlanes(tjhandle handle, const(ubyte)** srcPlanes,
        const int* strides, int subsamp, ubyte* dstBuf, int width, int pitch,
        int height, int pixelFormat, int flags);

tjhandle tjInitTransform();

int tjTransform(tjhandle handle, const(ubyte)* jpegBuf, c_ulong jpegSize, int n,
        ubyte** dstBufs, c_ulong* dstSizes, tjtransform* transforms, int flags);

int tjDestroy(tjhandle handle);

ubyte* tjAlloc(int bytes);

ubyte* tjLoadImage(const(char)* filename, int* width, int alignment,
        int* height, int* pixelFormat, int flags);

int tjSaveImage(const(char)* filename, ubyte* buffer, int width, int pitch,
        int height, int pixelFormat, int flags);

void tjFree(ubyte* buffer);

char* tjGetErrorStr2(tjhandle handle);

int tjGetErrorCode(tjhandle handle);


deprecated:

c_ulong TJBUFSIZE(int width, int height);

c_ulong TJBUFSIZEYUV(int width, int height, int jpegSubsamp);

c_ulong tjBufSizeYUV(int width, int height, int subsamp);

int tjCompress(tjhandle handle, ubyte *srcBuf, int width,
                         int pitch, int height, int pixelSize,
                         ubyte *dstBuf, c_ulong *compressedSize,
                         int jpegSubsamp, int jpegQual, int flags);

int tjEncodeYUV(tjhandle handle, ubyte *srcBuf, int width,
                          int pitch, int height, int pixelSize,
                          ubyte *dstBuf, int subsamp, int flags);

int tjEncodeYUV2(tjhandle handle, ubyte *srcBuf, int width,
                           int pitch, int height, int pixelFormat,
                           ubyte *dstBuf, int subsamp, int flags);

int tjDecompressHeader(tjhandle handle, ubyte *jpegBuf,
                                 c_ulong jpegSize, int *width,
                                 int *height);

int tjDecompressHeader2(tjhandle handle, ubyte *jpegBuf,
                                  c_ulong jpegSize, int *width,
                                  int *height, int *jpegSubsamp);

int tjDecompress(tjhandle handle, ubyte *jpegBuf,
                           c_ulong jpegSize, ubyte *dstBuf,
                           int width, int pitch, int height, int pixelSize,
                           int flags);

int tjDecompressToYUV(tjhandle handle, ubyte *jpegBuf,
                                c_ulong jpegSize, ubyte *dstBuf,
                                int flags);

char *tjGetErrorStr();

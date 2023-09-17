module het.imageformats; 
/+
	This module combines the following 3rd party modules/packages:
	- imageformats package: BMP, TGA, PNG (without JPEG)
	- turboJPEG package
	- libWebp package
	It's combined to achieve less incremental build times and less complexity in the system.
	The het.bitmap module always compiles all of these.
+/
//Todo: It should be configured with with version conditions.

public
{
	version(/+$DIDE_REGION Imageformats+/all)
	{
		//Copyright (c) 2014-2018 Tero Hänninen
		
		//Boost Software License - Version 1.0 - August 17th, 2003
		//module imageformats; 
		
		import std.stdio	: StdIOFile=File, SEEK_SET, SEEK_CUR, SEEK_END; 
		import std.string	: toLower, lastIndexOf; 
		import std.typecons : scoped; 
		//public import imageformats.png; 
		//public import imageformats.tga; 
		//public import imageformats.bmp; 
		
		//public import imageformats.jpeg; 
		//230916 realhet : JPEG support disabled in here. I prefer turboJpeg.
		
		/// Image with 8-bit channels.
		struct IFImage
		{
			/// width
			int         w; 
			/// height
			int         h; 
			/// channels
			ColFmt      c; 
			/// buffer
			ubyte[]     pixels; 
		} 
		
		/// Image with 16-bit channels.
		struct IFImage16
		{
			/// width
			int         w; 
			/// height
			int         h; 
			/// channels
			ColFmt      c; 
			/// buffer
			ushort[]    pixels; 
		} 
		
		/// Color format which you can pass to the read and write functions.
		enum ColFmt
		{
			Y = 1,	  /// Gray
			YA = 2,	  /// Gray + Alpha
			RGB = 3,	  /// Truecolor
			RGBA = 4,	  /// Truecolor + Alpha
		} 
		
		/// Reads an image from file. req_chans defines the format of returned image
		/// (you can use ColFmt here).
		IFImage read_image(in char[] file, long req_chans = 0)
		{
			auto reader = scoped!FileReader(file); 
			return read_image_from_reader(reader, req_chans); 
		} 
		
		/// Reads an image from a buffer. req_chans defines the format of returned
		/// image (you can use ColFmt here).
		IFImage read_image_from_mem(in ubyte[] source, long req_chans = 0)
		{
			auto reader = scoped!MemReader(source); 
			return read_image_from_reader(reader, req_chans); 
		} 
		
		/// Writes an image to file. req_chans defines the format the image is saved in
		/// (you can use ColFmt here).
		void write_image(in char[] file, long w, long h, in ubyte[] data, long req_chans = 0)
		{
			const char[] ext = extract_extension_lowercase(file); 
			
			void function(Writer, long, long, in ubyte[], long) write_image; 
			switch(ext)
			{
				case "png": write_image = &write_png; break; 
				case "tga": write_image = &write_tga; break; 
				case "bmp": write_image = &write_bmp; break; 
				default: throw new ImageIOException("unknown image extension/type"); 
			}
			auto writer = scoped!FileWriter(file); 
			write_image(writer, w, h, data, req_chans); 
		} 
		
		/// Returns width, height and color format information via w, h and chans.
		/// If number of channels is unknown chans is set to zero, otherwise chans
		/// values map to those of ColFmt.
		void read_image_info(in char[] file, out int w, out int h, out int chans)
		{
			auto reader = scoped!FileReader(file); 
			try
			{ return read_png_info(reader, w, h, chans); }catch(Throwable)
			{ reader.seek(0, SEEK_SET); }
			/+
				try
					{ return read_jpeg_info(reader, w, h, chans); }catch(Throwable)
					{ reader.seek(0, SEEK_SET); }
			+/
			try
			{ return read_bmp_info(reader, w, h, chans); }catch(Throwable)
			{ reader.seek(0, SEEK_SET); }
			try
			{ return read_tga_info(reader, w, h, chans); }catch(Throwable)
			{ reader.seek(0, SEEK_SET); }
			throw new ImageIOException("unknown image type"); 
		} 
		
		//Added by realhet
		
		void read_image_info_from_mem(in ubyte[] source, out int w, out int h, out int chans)
		{
			auto reader = scoped!MemReader(source); 
			try
			{ return read_png_info(reader, w, h, chans); }catch(Throwable)
			{ reader.seek(0, SEEK_SET); }
			/+
				try
					{ return read_jpeg_info(reader, w, h, chans); }catch(Throwable)
					{ reader.seek(0, SEEK_SET); }
			+/
			try
			{ return read_bmp_info(reader, w, h, chans); }catch(Throwable)
			{ reader.seek(0, SEEK_SET); }
			try
			{ return read_tga_info(reader, w, h, chans); }catch(Throwable)
			{ reader.seek(0, SEEK_SET); }
			throw new ImageIOException("unknown image type"); 
		} 
		
		/// Thrown from all the functions...
		class ImageIOException : Exception
		{
			@safe pure const
				 this(string msg, string file = __FILE__, size_t line = __LINE__)
			{   super(msg, file, line); } 
		} 
		
		private: 
		
		IFImage read_image_from_reader(Reader reader, long req_chans)
		{
			if(detect_png(reader))
			return read_png(reader, req_chans); 
			/+
				if(detect_jpeg(reader))
					return read_jpeg(reader, req_chans); 
			+/
			if(detect_bmp(reader))
			return read_bmp(reader, req_chans); 
			if(detect_tga(reader))
			return read_tga(reader, req_chans); 
			throw new ImageIOException("unknown image type"); 
		} 
		
		//--------------------------------------------------------------------------------
		//Conversions
		
		package enum _ColFmt : int
		{
			Unknown = 0,
			Y = 1,
			YA,
			RGB,
			RGBA,
			BGR,
			BGRA,
		} 
		
		package alias LineConv(T) = void function(in T[] src, T[] tgt); 
		
		package LineConv!T get_converter(T)(long src_chans, long tgt_chans) pure
		{
			long combo(long a, long b) pure nothrow
			{ return a*16 + b; } 
			
			if(src_chans == tgt_chans)
			return &copy_line!T; 
			
			switch(combo(src_chans, tgt_chans))
			with(_ColFmt)
			{
				case combo(Y, YA): return &Y_to_YA!T; 
				case combo(Y, RGB): return &Y_to_RGB!T; 
				case combo(Y, RGBA): return &Y_to_RGBA!T; 
				case combo(Y, BGR): return &Y_to_BGR!T; 
				case combo(Y, BGRA)	: 	return &Y_to_BGRA!T; 
				case combo(YA, Y)	: 	return &YA_to_Y!T; 
				case combo(YA, RGB)	: 	return &YA_to_RGB!T; 
				case combo(YA, RGBA): return &YA_to_RGBA!T; 
				case combo(YA, BGR): return &YA_to_BGR!T; 
				case combo(YA, BGRA): 	return &YA_to_BGRA!T; 
				case combo(RGB, Y)	: return &RGB_to_Y!T; 
				case combo(RGB, YA)	: return &RGB_to_YA!T; 
				case combo(RGB, RGBA): 	return &RGB_to_RGBA!T; 
				case combo(RGB, BGR): return &RGB_to_BGR!T; 
				case combo(RGB, BGRA): 	return &RGB_to_BGRA!T; 
				case combo(RGBA, Y)	: return &RGBA_to_Y!T; 
				case combo(RGBA, YA): return &RGBA_to_YA!T; 
				case combo(RGBA, RGB)	: return &RGBA_to_RGB!T; 
				case combo(RGBA, BGR)	: return &RGBA_to_BGR!T; 
				case combo(RGBA, BGRA): 	return &RGBA_to_BGRA!T; 
				case combo(BGR, Y)	: return &BGR_to_Y!T; 
				case combo(BGR, YA): return &BGR_to_YA!T; 
				case combo(BGR, RGB): return &BGR_to_RGB!T; 
				case combo(BGR, RGBA): 	return &BGR_to_RGBA!T; 
				case combo(BGRA, Y)	: return &BGRA_to_Y!T; 
				case combo(BGRA, YA): return	&BGRA_to_YA!T; 
				case combo(BGRA, RGB): return	&BGRA_to_RGB!T; 
				case combo(BGRA, RGBA): return	&BGRA_to_RGBA!T; 
				default	: throw new ImageIOException("internal error"); 
			}
			
		} 
		
		void copy_line(T)(in T[] src, T[] tgt) pure nothrow
		{ tgt[0..$] = src[0..$]; } 
		
		T luminance(T)(T r, T g, T b) pure nothrow
		{
			return cast(T) (0.21*r + 0.64*g + 0.15*b); //somewhat arbitrary weights
		} 
		
		void Y_to_YA(T)(in T[] src, T[] tgt) pure nothrow
		{
			for(size_t k, t;   k < src.length;   k+=1, t+=2)
			{
				tgt[t] = src[k]; 
				tgt[t+1] = T.max; 
			}
		} 
		
		alias Y_to_BGR = Y_to_RGB; 
		void Y_to_RGB(T)(in T[] src, T[] tgt) pure nothrow
		{
			for(size_t k, t;   k < src.length;   k+=1, t+=3)
			tgt[t .. t+3] = src[k]; 
		} 
		
		alias Y_to_BGRA = Y_to_RGBA; 
		void Y_to_RGBA(T)(in T[] src, T[] tgt) pure nothrow
		{
			for(size_t k, t;   k < src.length;   k+=1, t+=4)
			{
				tgt[t .. t+3] = src[k]; 
				tgt[t+3] = T.max; 
			}
		} 
		
		void YA_to_Y(T)(in T[] src, T[] tgt) pure nothrow
		{
			for(size_t k, t;   k < src.length;   k+=2, t+=1)
			tgt[t] = src[k]; 
		} 
		
		alias YA_to_BGR = YA_to_RGB; 
		void YA_to_RGB(T)(in T[] src, T[] tgt) pure nothrow
		{
			for(size_t k, t;   k < src.length;   k+=2, t+=3)
			tgt[t .. t+3] = src[k]; 
		} 
		
		alias YA_to_BGRA = YA_to_RGBA; 
		void YA_to_RGBA(T)(in T[] src, T[] tgt) pure nothrow
		{
			for(size_t k, t;   k < src.length;   k+=2, t+=4)
			{
				tgt[t .. t+3] = src[k]; 
				tgt[t+3] = src[k+1]; 
			}
		} 
		
		void RGB_to_Y(T)(in T[] src, T[] tgt) pure nothrow
		{
			for(size_t k, t;   k < src.length;   k+=3, t+=1)
			tgt[t] = luminance(src[k], src[k+1], src[k+2]); 
		} 
		
		void RGB_to_YA(T)(in T[] src, T[] tgt) pure nothrow
		{
			for(size_t k, t;   k < src.length;   k+=3, t+=2)
			{
				tgt[t] = luminance(src[k], src[k+1], src[k+2]); 
				tgt[t+1] = T.max; 
			}
		} 
		
		void RGB_to_RGBA(T)(in T[] src, T[] tgt) pure nothrow
		{
			for(size_t k, t;   k < src.length;   k+=3, t+=4)
			{
				tgt[t .. t+3] = src[k .. k+3]; 
				tgt[t+3] = T.max; 
			}
		} 
		
		void RGBA_to_Y(T)(in T[] src, T[] tgt) pure nothrow
		{
			for(size_t k, t;   k < src.length;   k+=4, t+=1)
			tgt[t] = luminance(src[k], src[k+1], src[k+2]); 
		} 
		
		void RGBA_to_YA(T)(in T[] src, T[] tgt) pure nothrow
		{
			for(size_t k, t;   k < src.length;   k+=4, t+=2)
			{
				tgt[t] = luminance(src[k], src[k+1], src[k+2]); 
				tgt[t+1] = src[k+3]; 
			}
		} 
		
		void RGBA_to_RGB(T)(in T[] src, T[] tgt) pure nothrow
		{
			for(size_t k, t;   k < src.length;   k+=4, t+=3)
			tgt[t .. t+3] = src[k .. k+3]; 
		} 
		
		void BGR_to_Y(T)(in T[] src, T[] tgt) pure nothrow
		{
			for(size_t k, t;   k < src.length;   k+=3, t+=1)
			tgt[t] = luminance(src[k+2], src[k+1], src[k+1]); 
		} 
		
		void BGR_to_YA(T)(in T[] src, T[] tgt) pure nothrow
		{
			for(size_t k, t;   k < src.length;   k+=3, t+=2)
			{
				tgt[t] = luminance(src[k+2], src[k+1], src[k+1]); 
				tgt[t+1] = T.max; 
			}
		} 
		
		alias RGB_to_BGR = BGR_to_RGB; 
		void BGR_to_RGB(T)(in T[] src, T[] tgt) pure nothrow
		{
			for(size_t k;   k < src.length;   k+=3)
			{
				tgt[k  ] = src[k+2]; 
				tgt[k+1] = src[k+1]; 
				tgt[k+2] = src[k  ]; 
			}
		} 
		
		alias RGB_to_BGRA = BGR_to_RGBA; 
		void BGR_to_RGBA(T)(in T[] src, T[] tgt) pure nothrow
		{
			for(size_t k, t;   k < src.length;   k+=3, t+=4)
			{
				tgt[t  ] = src[k+2]; 
				tgt[t+1] = src[k+1]; 
				tgt[t+2] = src[k  ]; 
				tgt[t+3] = T.max; 
			}
		} 
		
		void BGRA_to_Y(T)(in T[] src, T[] tgt) pure nothrow
		{
			for(size_t k, t;   k < src.length;   k+=4, t+=1)
			tgt[t] = luminance(src[k+2], src[k+1], src[k]); 
		} 
		
		void BGRA_to_YA(T)(in T[] src, T[] tgt) pure nothrow
		{
			for(size_t k, t;   k < src.length;   k+=4, t+=2)
			{
				tgt[t] = luminance(src[k+2], src[k+1], src[k]); 
				tgt[t+1] = T.max; 
			}
		} 
		
		alias RGBA_to_BGR = BGRA_to_RGB; 
		void BGRA_to_RGB(T)(in T[] src, T[] tgt) pure nothrow
		{
			for(size_t k, t;   k < src.length;   k+=4, t+=3)
			{
				tgt[t  ] = src[k+2]; 
				tgt[t+1] = src[k+1]; 
				tgt[t+2] = src[k  ]; 
			}
		} 
		
		alias RGBA_to_BGRA = BGRA_to_RGBA; 
		void BGRA_to_RGBA(T)(in T[] src, T[] tgt) pure nothrow
		{
			for(size_t k, t;   k < src.length;   k+=4, t+=4)
			{
				tgt[t  ] = src[k+2]; 
				tgt[t+1] = src[k+1]; 
				tgt[t+2] = src[k  ]; 
				tgt[t+3] = src[k+3]; 
			}
		} 
		
		//--------------------------------------------------------------------------------
		
		package interface Reader
		{
			void readExact(ubyte[], size_t); 
			void seek(ptrdiff_t, int); 
		} 
		
		package interface Writer
		{
			void rawWrite(in ubyte[]); 
			void flush(); 
		} 
		
		package class FileReader : Reader
		{
			this(in char[] filename)
			{ this(StdIOFile(filename.idup, "rb")); } 
			
			this(StdIOFile f)
			{
				if(!f.isOpen)
				throw new ImageIOException("File not open"); 
				this.f = f; 
			} 
			
			void readExact(ubyte[] buffer, size_t bytes)
			{
				auto slice = this.f.rawRead(buffer[0..bytes]); 
				if(slice.length != bytes)
				throw new Exception("not enough data"); 
			} 
			
			void seek(ptrdiff_t offset, int origin)
			{ this.f.seek(offset, origin); } 
			
			private StdIOFile f; 
		} 
		
		package class MemReader : Reader
		{
			this(in ubyte[] source)
			{ this.source = source; } 
			
			void readExact(ubyte[] buffer, size_t bytes)
			{
				if(source.length - cursor < bytes)
				throw new Exception("not enough data"); 
				buffer[0..bytes] = source[cursor .. cursor+bytes]; 
				cursor += bytes; 
			} 
			
			void seek(ptrdiff_t offset, int origin)
			{
				switch(origin)
				{
					case SEEK_SET: 
						if(offset < 0 || source.length <= offset)
					throw new Exception("seek error"); 
						cursor = offset; 
						break; 
					case SEEK_CUR: 
						ptrdiff_t dst = cursor + offset; 
						if(dst < 0 || source.length <= dst)
					throw new Exception("seek error"); 
						cursor = dst; 
						break; 
					case SEEK_END: 
						if(0 <= offset || source.length < -offset)
					throw new Exception("seek error"); 
						cursor = cast(ptrdiff_t) source.length + offset; 
						break; 
					default: assert(0); 
				}
			} 
			
			private const ubyte[] source; 
			private ptrdiff_t cursor; 
		} 
		
		package class FileWriter : Writer
		{
			this(in char[] filename)
			{ this(StdIOFile(filename.idup, "wb")); } 
			
			this(StdIOFile f)
			{
				if(!f.isOpen)
				throw new ImageIOException("File not open"); 
				this.f = f; 
			} 
			
			void rawWrite(in ubyte[] block)
			{ this.f.rawWrite(block); } 
			void flush()
			{ this.f.flush(); } 
			
			private StdIOFile f; 
		} 
		
		package class MemWriter : Writer
		{
			this()
			{} 
			
			ubyte[] result()
			{ return buffer; } 
			
			void rawWrite(in ubyte[] block)
			{ this.buffer ~= block; } 
			void flush()
			{} 
			
			private ubyte[] buffer; 
		} 
		
		const(char)[] extract_extension_lowercase(in char[] filename)
		{
			ptrdiff_t di = filename.lastIndexOf('.'); 
			return (0 < di && di+1 < filename.length) ? filename[di+1..$].toLower() : ""; 
		} 
		
		unittest
		{
			//The TGA and BMP files are not as varied in format as the PNG files, so
			//not as well tested.
			string png_path = "tests/pngsuite/"; 
			string tga_path = "tests/pngsuite-tga/"; 
			string bmp_path = "tests/pngsuite-bmp/"; 
			
			auto files = [
				"basi0g08",			 //PNG image data, 32 x 32, 8-bit grayscale, interlaced
				"basi2c08",			 //PNG image data, 32 x 32, 8-bit/color RGB, interlaced
				"basi3p08",			 //PNG image data, 32 x 32, 8-bit colormap, interlaced
				"basi4a08",			 //PNG image data, 32 x 32, 8-bit gray+alpha, interlaced
				"basi6a08",			 //PNG image data, 32 x 32, 8-bit/color RGBA, interlaced
				"basn0g08",			 //PNG image data, 32 x 32, 8-bit grayscale, non-interlaced
				"basn2c08",			 //PNG image data, 32 x 32, 8-bit/color RGB, non-interlaced
				"basn3p08",			 //PNG image data, 32 x 32, 8-bit colormap, non-interlaced
				"basn4a08",			 //PNG image data, 32 x 32, 8-bit gray+alpha, non-interlaced
				"basn6a08",			 //PNG image data, 32 x 32, 8-bit/color RGBA, non-interlaced
			]; 
			
			foreach(file; files)
			{
				//writefln("%s", file);
				auto a = read_image(png_path ~ file ~ ".png", ColFmt.RGBA); 
				auto b = read_image(tga_path ~ file ~ ".tga", ColFmt.RGBA); 
				auto c = read_image(bmp_path ~ file ~ ".bmp", ColFmt.RGBA); 
				assert(a.w == b.w && a.w == c.w); 
				assert(a.h == b.h && a.h == c.h); 
				assert(a.pixels.length == b.pixels.length && a.pixels.length == c.pixels.length); 
				foreach(i; 0 .. a.pixels.length)
				{
					assert(a.pixels[i] == b.pixels[i], "png/tga"); 
					assert(a.pixels[i] == c.pixels[i], "png/bmp"); 
				}
			}
		} 
	}version(/+$DIDE_REGION BMP+/all)
	{
		//module imageformats.bmp; 
		
		import std.bitmanip	: littleEndianToNative, nativeToLittleEndian; 
		import std.math	: abs; 
		import std.typecons	: scoped; 
		//import imageformats; 
		
		private: 
		
		immutable bmp_header = ['B', 'M']; 
		
		/// Reads a BMP image. req_chans defines the format of returned image
		/// (you can use ColFmt here).
		public IFImage read_bmp(in char[] filename, long req_chans = 0)
		{
			auto reader = scoped!FileReader(filename); 
			return read_bmp(reader, req_chans); 
		} 
		
		/// Reads an image from a buffer containing a BMP image. req_chans defines the
		/// format of returned image (you can use ColFmt here).
		public IFImage read_bmp_from_mem(in ubyte[] source, long req_chans = 0)
		{
			auto reader = scoped!MemReader(source); 
			return read_bmp(reader, req_chans); 
		} 
		
		/// Returns the header of a BMP file.
		public BMP_Header read_bmp_header(in char[] filename)
		{
			auto reader = scoped!FileReader(filename); 
			return read_bmp_header(reader); 
		} 
		
		/// Reads the image header from a buffer containing a BMP image.
		public BMP_Header read_bmp_header_from_mem(in ubyte[] source)
		{
			auto reader = scoped!MemReader(source); 
			return read_bmp_header(reader); 
		} 
		
		/// Header of a BMP file.
		public struct BMP_Header
		{
			uint file_size; 
			uint pixel_data_offset; 
			
			uint dib_size; 
			int width; 
			int height; 
			ushort planes; 
			int bits_pp; 
			uint dib_version; 
			DibV1 dib_v1; 
			DibV2 dib_v2; 
			uint dib_v3_alpha_mask; 
			DibV4 dib_v4; 
			DibV5 dib_v5; 
		} 
		
		/// Part of BMP header, not always present.
		public struct DibV1
		{
			uint compression; 
			uint idat_size; 
			uint pixels_per_meter_x; 
			uint pixels_per_meter_y; 
			uint palette_length; 
			uint important_color_count; 
		} 
		
		/// Part of BMP header, not always present.
		public struct DibV2
		{
			uint red_mask; 
			uint green_mask; 
			uint blue_mask; 
		} 
		
		/// Part of BMP header, not always present.
		public struct DibV4
		{
			uint color_space_type; 
			ubyte[36] color_space_endpoints; 
			uint gamma_red; 
			uint gamma_green; 
			uint gamma_blue; 
		} 
		
		/// Part of BMP header, not always present.
		public struct DibV5
		{
			uint icc_profile_data; 
			uint icc_profile_size; 
		} 
		
		/// Returns width, height and color format information via w, h and chans.
		public void read_bmp_info(in char[] filename, out int w, out int h, out int chans)
		{
			auto reader = scoped!FileReader(filename); 
			return read_bmp_info(reader, w, h, chans); 
		} 
		
		/// Returns width, height and color format information via w, h and chans.
		public void read_bmp_info_from_mem(in ubyte[] source, out int w, out int h, out int chans)
		{
			auto reader = scoped!MemReader(source); 
			return read_bmp_info(reader, w, h, chans); 
		} 
		
		/// Writes a BMP image into a file.
		public void write_bmp(in char[] file, long w, long h, in ubyte[] data, long tgt_chans = 0)
		{
			auto writer = scoped!FileWriter(file); 
			write_bmp(writer, w, h, data, tgt_chans); 
		} 
		
		/// Writes a BMP image into a buffer.
		public ubyte[] write_bmp_to_mem(long w, long h, in ubyte[] data, long tgt_chans = 0)
		{
			auto writer = scoped!MemWriter(); 
			write_bmp(writer, w, h, data, tgt_chans); 
			return writer.result; 
		} 
		
		//Detects whether a BMP image is readable from stream.
		package bool detect_bmp(Reader stream)
		{
			try
			{
				ubyte[18] tmp = void;  //bmp header + size of dib header
				stream.readExact(tmp, tmp.length); 
				size_t ds = littleEndianToNative!uint(tmp[14..18]); 
				return (
					tmp[0..2] == bmp_header
								&& (ds == 12 || ds == 40 || ds == 52 || ds == 56 || ds == 108 || ds == 124)
				); 
			}catch(Throwable)
			{ return false; }finally
			{ stream.seek(0, SEEK_SET); }
		} 
		
		BMP_Header read_bmp_header(Reader stream)
		{
			ubyte[18] tmp = void;  //bmp header + size of dib header
			stream.readExact(tmp[], tmp.length); 
			
			if(tmp[0..2] != bmp_header)
			throw new ImageIOException("corrupt header"); 
			
			uint dib_size = littleEndianToNative!uint(tmp[14..18]); 
			uint dib_version; 
			switch(dib_size)
			{
				case 12: dib_version = 0; break; 
				case 40: dib_version = 1; break; 
				case 52: dib_version = 2; break; 
				case 56: dib_version = 3; break; 
				case 108: dib_version = 4; break; 
				case 124: dib_version = 5; break; 
				default: throw new ImageIOException("unsupported dib version"); 
			}
			auto dib_header = new ubyte[dib_size-4]; 
			stream.readExact(dib_header[], dib_header.length); 
			
			DibV1 dib_v1; 
			DibV2 dib_v2; 
			uint dib_v3_alpha_mask; 
			DibV4 dib_v4; 
			DibV5 dib_v5; 
			
			if(1 <= dib_version)
			{
				DibV1 v1 = {
					compression	: littleEndianToNative!uint(dib_header[12..16]),
					idat_size	: littleEndianToNative!uint(dib_header[16..20]),
					pixels_per_meter_x	: littleEndianToNative!uint(dib_header[20..24]),
					pixels_per_meter_y	: littleEndianToNative!uint(dib_header[24..28]),
					palette_length	: littleEndianToNative!uint(dib_header[28..32]),
					important_color_count	: littleEndianToNative!uint(dib_header[32..36]),
				}; 
				dib_v1 = v1; 
			}
			
			if(2 <= dib_version)
			{
				DibV2 v2 = {
					red_mask	           :	littleEndianToNative!uint(dib_header[36..40]),
					green_mask		: littleEndianToNative!uint(dib_header[40..44]),
					blue_mask	           : littleEndianToNative!uint(dib_header[44..48]),
				}; 
				dib_v2 = v2; 
			}
			
			if(3 <= dib_version)
			{ dib_v3_alpha_mask = littleEndianToNative!uint(dib_header[48..52]); }
			
			if(4 <= dib_version)
			{
				DibV4 v4 = {
					color_space_type	: littleEndianToNative!uint(dib_header[52..56]),
					color_space_endpoints	: dib_header[56..92],
					gamma_red	: littleEndianToNative!uint(dib_header[92..96]),
					gamma_green	: littleEndianToNative!uint(dib_header[96..100]),
					gamma_blue	: littleEndianToNative!uint(dib_header[100..104]),
				}; 
				dib_v4 = v4; 
			}
			
			if(5 <= dib_version)
			{
				DibV5 v5 = {
					icc_profile_data					 : littleEndianToNative!uint(dib_header[108..112]),
					icc_profile_size					 : littleEndianToNative!uint(dib_header[112..116]),
				}; 
				dib_v5 = v5; 
			}
			
			int width, height; ushort planes; int bits_pp; 
			if(0 == dib_version)
			{
				width = littleEndianToNative!ushort(dib_header[0..2]); 
				height = littleEndianToNative!ushort(dib_header[2..4]); 
				planes = littleEndianToNative!ushort(dib_header[4..6]); 
				bits_pp = littleEndianToNative!ushort(dib_header[6..8]); 
			}else
			{
				width = littleEndianToNative!int(dib_header[0..4]); 
				height = littleEndianToNative!int(dib_header[4..8]); 
				planes = littleEndianToNative!ushort(dib_header[8..10]); 
				bits_pp = littleEndianToNative!ushort(dib_header[10..12]); 
			}
			
			BMP_Header header = {
				file_size	    : littleEndianToNative!uint(tmp[2..6]),
				pixel_data_offset	    : littleEndianToNative!uint(tmp[10..14]),
				width	    : width,
				height				 : height,
				planes				 : planes,
				bits_pp	    : bits_pp,
				dib_version	    : dib_version,
				dib_v1				 : dib_v1,
				dib_v2				 : dib_v2,
				dib_v3_alpha_mask	    : dib_v3_alpha_mask,
				dib_v4				 : dib_v4,
				dib_v5				 : dib_v5,
			}; 
			return header; 
		} 
		
		enum CMP_RGB	= 0; 
		enum CMP_BITS	= 3; 
		
		package IFImage read_bmp(Reader stream, long req_chans = 0)
		{
			if(req_chans < 0 || 4 < req_chans)
			throw new ImageIOException("unknown color format"); 
			
			BMP_Header hdr = read_bmp_header(stream); 
			
			if(hdr.width < 1 || hdr.height == 0)
			{ throw new ImageIOException("invalid dimensions"); }
			if(
				hdr.pixel_data_offset < (14 + hdr.dib_size)
					|| hdr.pixel_data_offset > 0xffffff /*arbitrary*/
			)
			{ throw new ImageIOException("invalid pixel data offset"); }
			if(hdr.planes != 1)
			{ throw new ImageIOException("not supported"); }
			
			auto bytes_pp						 = 1; 
			bool paletted						 = true; 
			size_t palette_length = 256; 
			bool rgb_masked	   = false; 
			auto pe_bytes_pp	   = 3; 
			
			if(1 <= hdr.dib_version)
			{
				if(256 < hdr.dib_v1.palette_length)
				throw new ImageIOException("ivnalid palette length"); 
				if(
					hdr.bits_pp <= 8 &&
							   (hdr.dib_v1.palette_length == 0 || hdr.dib_v1.compression != CMP_RGB)
				)
				throw new ImageIOException("unsupported format"); 
				if(hdr.dib_v1.compression != CMP_RGB && hdr.dib_v1.compression != CMP_BITS)
				throw new ImageIOException("unsupported compression"); 
				
				switch(hdr.bits_pp)
				{
					case 8	: bytes_pp = 1; paletted = true; break; 
					case 24	: bytes_pp = 3; paletted = false; break; 
					case 32	: bytes_pp = 4; paletted = false; break; 
					default: throw new ImageIOException("not supported"); 
				}
				
				palette_length = hdr.dib_v1.palette_length; 
				rgb_masked = hdr.dib_v1.compression == CMP_BITS; 
				pe_bytes_pp = 4; 
			}
			
			size_t mask_to_idx(uint mask)
			{
				switch(mask)
				{
					case 0xff00_0000: return 3; 
					case 0x00ff_0000: return 2; 
					case 0x0000_ff00: return 1; 
					case 0x0000_00ff: return 0; 
					default: throw new ImageIOException("unsupported mask"); 
				}
			} 
			
			size_t redi = 2; 
			size_t greeni = 1; 
			size_t bluei = 0; 
			if(rgb_masked && hdr.dib_version>1)
			{
				 //het: version 1 has no specific masks
				if(hdr.dib_version < 2)
				throw new ImageIOException("invalid format"); 
				redi = mask_to_idx(hdr.dib_v2.red_mask); 
				greeni = mask_to_idx(hdr.dib_v2.green_mask); 
				bluei = mask_to_idx(hdr.dib_v2.blue_mask); 
			}
			
			bool alpha_masked = false; 
			size_t alphai = 0; 
			if(bytes_pp == 4 && 3 <= hdr.dib_version && hdr.dib_v3_alpha_mask != 0)
			{
				alpha_masked = true; 
				alphai = mask_to_idx(hdr.dib_v3_alpha_mask); 
			}
			
			ubyte[] depaletted_line = null; 
			ubyte[] palette = null; 
			if(paletted)
			{
				depaletted_line = new ubyte[hdr.width * pe_bytes_pp]; 
				palette = new ubyte[palette_length * pe_bytes_pp]; 
				stream.readExact(palette[], palette.length); 
			}
			
			stream.seek(hdr.pixel_data_offset, SEEK_SET); 
			
			immutable tgt_chans = (0 < req_chans) ? req_chans
												  : (alpha_masked) ? _ColFmt.RGBA
																   : _ColFmt.RGB; 
			
			const src_fmt = (!paletted || pe_bytes_pp == 4) ? _ColFmt.BGRA : _ColFmt.BGR; 
			const LineConv!ubyte convert = get_converter!ubyte(src_fmt, tgt_chans); 
			
			immutable size_t src_linesize = hdr.width * bytes_pp;  //without padding
			immutable size_t src_pad = 3 - ((src_linesize-1) % 4); 
			immutable ptrdiff_t tgt_linesize = (hdr.width * cast(int) tgt_chans); 
			
			immutable ptrdiff_t tgt_stride	= (hdr.height < 0) ? tgt_linesize : -tgt_linesize; 
			ptrdiff_t ti	= (hdr.height < 0) ? 0 : (hdr.height-1) * tgt_linesize; 
			
			auto src_line_buf	= new ubyte[src_linesize + src_pad]; 
			auto bgra_line_buf	= (paletted) ? null : new ubyte[hdr.width * 4]; 
			auto result	= new ubyte[hdr.width * abs(hdr.height) * cast(int) tgt_chans]; 
			
			foreach(_; 0 .. abs(hdr.height))
			{
				stream.readExact(src_line_buf[], src_line_buf.length); 
				auto src_line = src_line_buf[0..src_linesize]; 
				
				if(paletted)
				{
					size_t ps = pe_bytes_pp; 
					size_t di = 0; 
					foreach(idx; src_line[])
					{
						if(idx > palette_length)
						throw new ImageIOException("invalid palette index"); 
						size_t i = idx * ps; 
						depaletted_line[di .. di+ps] = palette[i .. i+ps]; 
						if(ps == 4)
						{ depaletted_line[di+3] = 255; }
						di += ps; 
					}
					convert(depaletted_line[], result[ti .. (ti+tgt_linesize)]); 
				}else
				{
					for(size_t si, di;   si < src_line.length;   si+=bytes_pp, di+=4)
					{
						bgra_line_buf[di + 0] = src_line[si + bluei]; 
						bgra_line_buf[di + 1] = src_line[si + greeni]; 
						bgra_line_buf[di + 2] = src_line[si + redi]; 
						bgra_line_buf[di + 3] = (alpha_masked) ? src_line[si + alphai]
															   : 255; 
					}
					convert(bgra_line_buf[], result[ti .. (ti+tgt_linesize)]); 
				}
				
				ti += tgt_stride; 
			}
			
			IFImage ret = {
				w	: hdr.width,
				h	: abs(hdr.height),
				c	: cast(ColFmt) tgt_chans,
				pixels	: result,
			}; 
			return ret; 
		} 
		
		package void read_bmp_info(Reader stream, out int w, out int h, out int chans)
		{
			BMP_Header hdr = read_bmp_header(stream); 
			w = abs(hdr.width); 
			h = abs(hdr.height); 
			chans = (hdr.dib_version >= 3 && hdr.dib_v3_alpha_mask != 0 && hdr.bits_pp == 32)
					 ? ColFmt.RGBA
					 : ColFmt.RGB; 
		} 
		
		//----------------------------------------------------------------------
		//BMP encoder
		
		//Writes RGB or RGBA data.
		void write_bmp(Writer stream, long w, long h, in ubyte[] data, long tgt_chans = 0)
		{
			if(w < 1 || h < 1 || 0x7fff < w || 0x7fff < h)
			throw new ImageIOException("invalid dimensions"); 
			size_t src_chans = data.length / cast(size_t) w / cast(size_t) h; 
			if(src_chans < 1 || 4 < src_chans)
			throw new ImageIOException("invalid channel count"); 
			if(tgt_chans != 0 && tgt_chans != 3 && tgt_chans != 4)
			throw new ImageIOException("unsupported format for writing"); 
			if(src_chans * w * h != data.length)
			throw new ImageIOException("mismatching dimensions and length"); 
			
			if(tgt_chans == 0)
			tgt_chans = (src_chans == 1 || src_chans == 3) ? 3 : 4; 
			
			const dib_size = 108; 
			const size_t tgt_linesize = cast(size_t) (w * tgt_chans); 
			const size_t pad = 3 - ((tgt_linesize-1) & 3); 
			const size_t idat_offset = 14 + dib_size; 	//bmp file header + dib header
			const size_t filesize = idat_offset + cast(size_t) h *	(tgt_linesize + pad); 
			if(filesize > 0xffff_ffff)
			{ throw new ImageIOException("image too large"); }
			
			ubyte[14+dib_size] hdr; 
			hdr[0] = 0x42; 
			hdr[1] = 0x4d; 
			hdr[2..6] = nativeToLittleEndian(cast(uint) filesize); 
			hdr[6..10] = 0;                                                //reserved
			hdr[10..14] = nativeToLittleEndian(cast(uint) idat_offset);    //offset of pixel data
			hdr[14..18] = nativeToLittleEndian(cast(uint) dib_size);       //dib header size
			hdr[18..22] = nativeToLittleEndian(cast(int) w); 
			hdr[22..26] = nativeToLittleEndian(cast(int) h);            //positive -> bottom-up
			hdr[26..28] = nativeToLittleEndian(cast(ushort) 1);         //planes
			hdr[28..30] = nativeToLittleEndian(cast(ushort) (tgt_chans * 8)); //bits per pixel
			hdr[30..34] = nativeToLittleEndian((tgt_chans == 3) ? CMP_RGB : CMP_BITS); 
			hdr[34..54] = 0;                                          //rest of dib v1
			if(tgt_chans == 3)
			{
				hdr[54..70] = 0;    //dib v2 and v3
			}else
			{
				static immutable ubyte[16] b =
				[
					0, 0, 0xff, 0,
					0, 0xff, 0, 0,
					0xff, 0, 0, 0,
					0, 0, 0, 0xff
				]; 
				hdr[54..70] = b; 
			}
			static immutable ubyte[4] BGRs = ['B', 'G', 'R', 's']; 
			hdr[70..74] = BGRs; 
			hdr[74..122] = 0; 
			stream.rawWrite(hdr); 
			
			const LineConv!ubyte convert =
				get_converter!ubyte(
				src_chans, (tgt_chans == 3) ? _ColFmt.BGR
																		: _ColFmt.BGRA
			); 
			
			auto tgt_line = new ubyte[tgt_linesize + pad]; 
			const size_t src_linesize = cast(size_t) w * src_chans; 
			size_t si = cast(size_t) h * src_linesize; 
			
			foreach(_; 0..h)
			{
				si -= src_linesize; 
				convert(data[si .. si + src_linesize], tgt_line[0..tgt_linesize]); 
				stream.rawWrite(tgt_line); 
			}
			
			stream.flush(); 
		} 
	}version(/+$DIDE_REGION PNG+/all)
	{
		//module imageformats.png; 
		
		import std.algorithm	: min, reverse; 
		import std.bitmanip	: bigEndianToNative, nativeToBigEndian; 
		import std.digest.crc	: CRC32, crc32Of; 
		import std.zlib	: UnCompress, HeaderFormat, compress; 
		import std.typecons	: scoped; 
		
		private: 
		
		/// Header of a PNG file.
		public struct PNG_Header
		{
			int		 width; 
			int		 height; 
			ubyte		 bit_depth; 
			ubyte		 color_type; 
			ubyte		 compression_method; 
			ubyte		 filter_method; 
			ubyte		 interlace_method; 
		} 
		
		/// Returns the header of a PNG file.
		public PNG_Header read_png_header(in char[] filename)
		{
			auto reader = scoped!FileReader(filename); 
			return read_png_header(reader); 
		} 
		
		/// Returns the header of the image in the buffer.
		public PNG_Header read_png_header_from_mem(in ubyte[] source)
		{
			auto reader = scoped!MemReader(source); 
			return read_png_header(reader); 
		} 
		
		/// Reads an 8-bit or 16-bit PNG image and returns it as an 8-bit image.
		/// req_chans defines the format of returned image (you can use ColFmt here).
		public IFImage read_png(in char[] filename, long req_chans = 0)
		{
			auto reader = scoped!FileReader(filename); 
			return read_png(reader, req_chans); 
		} 
		
		/// Reads an 8-bit or 16-bit PNG image from a buffer and returns it as an
		/// 8-bit image.  req_chans defines the format of returned image (you can use
		/// ColFmt here).
		public IFImage read_png_from_mem(in ubyte[] source, long req_chans = 0)
		{
			auto reader = scoped!MemReader(source); 
			return read_png(reader, req_chans); 
		} 
		
		/// Reads an 8-bit or 16-bit PNG image and returns it as a 16-bit image.
		/// req_chans defines the format of returned image (you can use ColFmt here).
		public IFImage16 read_png16(in char[] filename, long req_chans = 0)
		{
			auto reader = scoped!FileReader(filename); 
			return read_png16(reader, req_chans); 
		} 
		
		/// Reads an 8-bit or 16-bit PNG image from a buffer and returns it as a
		/// 16-bit image.  req_chans defines the format of returned image (you can use
		/// ColFmt here).
		public IFImage16 read_png16_from_mem(in ubyte[] source, long req_chans = 0)
		{
			auto reader = scoped!MemReader(source); 
			return read_png16(reader, req_chans); 
		} 
		
		/// Writes a PNG image into a file.
		public void write_png(in char[] file, long w, long h, in ubyte[] data, long tgt_chans = 0)
		{
			auto writer = scoped!FileWriter(file); 
			write_png(writer, w, h, data, tgt_chans); 
		} 
		
		/// Writes a PNG image into a buffer.
		public ubyte[] write_png_to_mem(long w, long h, in ubyte[] data, long tgt_chans = 0)
		{
			auto writer = scoped!MemWriter(); 
			write_png(writer, w, h, data, tgt_chans); 
			return writer.result; 
		} 
		
		/// Returns width, height and color format information via w, h and chans.
		public void read_png_info(in char[] filename, out int w, out int h, out int chans)
		{
			auto reader = scoped!FileReader(filename); 
			return read_png_info(reader, w, h, chans); 
		} 
		
		/// Returns width, height and color format information via w, h and chans.
		public void read_png_info_from_mem(in ubyte[] source, out int w, out int h, out int chans)
		{
			auto reader = scoped!MemReader(source); 
			return read_png_info(reader, w, h, chans); 
		} 
		
		///Detects whether a PNG image is readable from stream.
		package bool detect_png(Reader stream)
		{
			try
			{
				ubyte[8] tmp = void; 
				stream.readExact(tmp, tmp.length); 
				return (tmp[0..8] == png_file_header[0..$]); 
			}catch(Throwable)
			{ return false; }finally
			{ stream.seek(0, SEEK_SET); }
		} 
		
		PNG_Header read_png_header(Reader stream)
		{
			ubyte[33] tmp = void;  //file header, IHDR len+type+data+crc
			stream.readExact(tmp, tmp.length); 
			
			ubyte[4] crc = crc32Of(tmp[12..29]); 
			reverse(crc[]); 
			if(
				tmp[0..8] != png_file_header[0..$]              ||
												tmp[8..16] != png_image_header                  ||
												crc != tmp[29..33]
			)
			throw new ImageIOException("corrupt header"); 
			
			PNG_Header header = {
				width	: bigEndianToNative!int(tmp[16..20]),
				height	: bigEndianToNative!int(tmp[20..24]),
				bit_depth	: tmp[24],
				color_type	: tmp[25],
				compression_method	: tmp[26],
				filter_method	: tmp[27],
				interlace_method	: tmp[28],
			}; 
			return header; 
		} 
		
		package IFImage read_png(Reader stream, long req_chans = 0)
		{
			PNG_Decoder dc = init_png_decoder(stream, req_chans, 8); 
			IFImage result = {
				w	: dc.w,
				h	: dc.h,
				c	: cast(ColFmt) dc.tgt_chans,
				pixels	: decode_png(dc).bpc8
			}; 
			return result; 
		} 
		
		IFImage16 read_png16(Reader stream, long req_chans = 0)
		{
			PNG_Decoder dc = init_png_decoder(stream, req_chans, 16); 
			IFImage16 result = {
				w	: dc.w,
				h	: dc.h,
				c	: cast(ColFmt) dc.tgt_chans,
				pixels	: decode_png(dc).bpc16
			}; 
			return result; 
		} 
		
		PNG_Decoder init_png_decoder(Reader stream, long req_chans, int req_bpc)
		{
			if(req_chans < 0 || 4 < req_chans)
			throw new ImageIOException("come on..."); 
			
			PNG_Header hdr = read_png_header(stream); 
			
			if(hdr.width < 1 || hdr.height < 1 || int.max < cast(ulong) hdr.width * hdr.height)
			throw new ImageIOException("invalid dimensions"); 
			if((hdr.bit_depth != 8 && hdr.bit_depth != 16) || (req_bpc != 8 && req_bpc != 16))
			throw new ImageIOException("only 8-bit and 16-bit images supported"); 
			if(
				! (
					hdr.color_type == PNG_ColorType.Y    ||
									 hdr.color_type == PNG_ColorType.RGB	 ||
									 hdr.color_type == PNG_ColorType.Idx	 ||
									 hdr.color_type == PNG_ColorType.YA	 ||
									 hdr.color_type == PNG_ColorType.RGBA
				)
			)
			throw new ImageIOException("color type not supported"); 
			if(
				hdr.compression_method != 0 || hdr.filter_method != 0 ||
					(hdr.interlace_method != 0 && hdr.interlace_method != 1)
			)
			throw new ImageIOException("not supported"); 
			
			PNG_Decoder dc = {
				stream	: stream,
				src_indexed	: (hdr.color_type == PNG_ColorType.Idx),
				src_chans	: channels(cast(PNG_ColorType) hdr.color_type),
				bpc	: hdr.bit_depth,
				req_bpc	: req_bpc,
				ilace	: hdr.interlace_method,
				w	: hdr.width,
				h	: hdr.height,
			}; 
			dc.tgt_chans = (req_chans == 0) ? dc.src_chans : cast(int) req_chans; 
			return dc; 
		} 
		
		immutable ubyte[8] png_file_header =
			[0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]; 
		
		immutable ubyte[8] png_image_header = 
			[0x0, 0x0, 0x0, 0xd, 'I','H','D','R']; 
		
		int channels(PNG_ColorType ct) pure nothrow
		{
			final switch(ct)
			with(PNG_ColorType)
			{
				case Y: return 1; 
				case RGB: return 3; 
				case YA: return 2; 
				case RGBA, Idx: return 4; 
			}
			
		} 
		
		PNG_ColorType color_type(long channels) pure nothrow
		{
			switch(channels)
			{
				case 1: return PNG_ColorType.Y; 
				case 2: return PNG_ColorType.YA; 
				case 3: return PNG_ColorType.RGB; 
				case 4: return PNG_ColorType.RGBA; 
				default: assert(0); 
			}
		} 
		
		struct PNG_Decoder
		{
			Reader stream; 
			bool src_indexed; 
			int src_chans; 
			int tgt_chans; 
			int bpc; 
			int req_bpc; 
			int w, h; 
			ubyte ilace; 
			
			UnCompress uc; 
			CRC32 crc; 
			ubyte[12] chunkmeta;  //crc | length and type
			ubyte[] read_buf; 
			ubyte[] uc_buf;     //uncompressed
			ubyte[] palette; 
			ubyte[] transparency; 
		} 
		
		Buffer decode_png(ref PNG_Decoder dc)
		{
			dc.uc = new UnCompress(HeaderFormat.deflate); 
			dc.read_buf = new ubyte[4096]; 
			
			enum Stage
			{
				IHDR_parsed,
				PLTE_parsed,
				IDAT_parsed,
				IEND_parsed,
			} 
			
			Buffer result; 
			auto stage = Stage.IHDR_parsed; 
			dc.stream.readExact(dc.chunkmeta[4..$], 8);  //next chunk's len and type
			
			while(stage != Stage.IEND_parsed)
			{
				int len = bigEndianToNative!int(dc.chunkmeta[4..8]); 
				if(len < 0)
				throw new ImageIOException("chunk too long"); 
				
				//standard allows PLTE chunk for non-indexed images too but we don't
				dc.crc.put(dc.chunkmeta[8..12]);  //type
				switch(cast(char[]) dc.chunkmeta[8..12])
				{
						//chunk type
					case "IDAT": 
						if(
						! (
							stage == Stage.IHDR_parsed ||
												  (stage == Stage.PLTE_parsed && dc.src_indexed)
						)
					)
					throw new ImageIOException("corrupt chunk stream"); 
						result = read_IDAT_stream(dc, len); 
						stage = Stage.IDAT_parsed; 
						break; 
					case "PLTE": 
						if(stage != Stage.IHDR_parsed)
					throw new ImageIOException("corrupt chunk stream"); 
						int entries = len / 3; 
						if(len % 3 != 0 || 256 < entries)
					throw new ImageIOException("corrupt chunk"); 
						dc.palette = new ubyte[len]; 
						dc.stream.readExact(dc.palette, dc.palette.length); 
						dc.crc.put(dc.palette); 
						dc.stream.readExact(dc.chunkmeta, 12); //crc | len, type
						ubyte[4] crc = dc.crc.finish; 
						reverse(crc[]); 
						if(crc != dc.chunkmeta[0..4])
					throw new ImageIOException("corrupt chunk"); 
						stage = Stage.PLTE_parsed; 
						break; 
					case "tRNS": 
						if(
						! (
							stage == Stage.IHDR_parsed ||
												  (stage == Stage.PLTE_parsed && dc.src_indexed)
						)
					)
					throw new ImageIOException("corrupt chunk stream"); 
						if(dc.src_indexed)
					{
						size_t entries = dc.palette.length / 3; 
						if(len > entries)
						throw new ImageIOException("corrupt chunk"); 
					}
						dc.transparency = new ubyte[len]; 
						dc.stream.readExact(dc.transparency, dc.transparency.length); 
						dc.stream.readExact(dc.chunkmeta, 12); 
						dc.crc.put(dc.transparency); 
						ubyte[4] crc = dc.crc.finish; 
						reverse(crc[]); 
						if(crc != dc.chunkmeta[0..4])
					throw new ImageIOException("corrupt chunk"); 
						break; 
					case "IEND": 
						if(stage != Stage.IDAT_parsed)
					throw new ImageIOException("corrupt chunk stream"); 
						dc.stream.readExact(dc.chunkmeta, 4); //crc
						static immutable ubyte[4] expectedCRC = [0xae, 0x42, 0x60, 0x82]; 
						if(len != 0 || dc.chunkmeta[0..4] != expectedCRC)
					throw new ImageIOException("corrupt chunk"); 
						stage = Stage.IEND_parsed; 
						break; 
					case "IHDR": 
						throw new ImageIOException("corrupt chunk stream"); 
					default: 
						//unknown chunk, ignore but check crc
						while(0 < len)
					{
						size_t bytes = min(len, dc.read_buf.length); 
						dc.stream.readExact(dc.read_buf, bytes); 
						len -= bytes; 
						dc.crc.put(dc.read_buf[0..bytes]); 
					}
						dc.stream.readExact(dc.chunkmeta, 12); //crc | len, type
						ubyte[4] crc = dc.crc.finish; 
						reverse(crc[]); 
						if(crc != dc.chunkmeta[0..4])
					throw new ImageIOException("corrupt chunk"); 
				}
			}
			
			return result; 
		} 
		
		enum PNG_ColorType : ubyte
		{
			Y	= 0,
			RGB	= 2,
			Idx	= 3,
			YA	= 4,
			RGBA	= 6,
		} 	 enum PNG_FilterType : ubyte
		{
			None	= 0,
			Sub	= 1,
			Up	= 2,
			Average	= 3,
			Paeth	= 4,
		} 	 enum InterlaceMethod
		{ None = 0, Adam7 = 1} 	 union Buffer
		{
			ubyte[] bpc8; 
			ushort[] bpc16; 
		} 
		
		Buffer read_IDAT_stream(ref PNG_Decoder dc, int len)
		{
			assert(dc.req_bpc == 8 || dc.req_bpc == 16); 
			
			bool metaready = false;     //chunk len, type, crc
			
			immutable size_t filter_step = dc.src_indexed ? 1 : dc.src_chans * ((dc.bpc == 8) ? 1 : 2); 
			
			ubyte[] depaletted = dc.src_indexed ? new ubyte[dc.w * 4] : null; 
			
			auto cline = new ubyte[dc.w * filter_step + 1]; //+1 for filter type byte
			auto pline = new ubyte[dc.w * filter_step + 1]; //+1 for filter type byte
			auto cline8 = (dc.req_bpc == 8 && dc.bpc != 8) ? new ubyte[dc.w * dc.src_chans] : null; 
			auto cline16 = (dc.req_bpc == 16)	? new ushort[dc.w * dc.src_chans] : null; 
			ubyte[]	result8	= (dc.req_bpc == 8)  ? new ubyte[dc.w * dc.h * dc.tgt_chans] : null; 
			ushort[]	result16	= (dc.req_bpc == 16) ? new ushort[dc.w * dc.h * dc.tgt_chans] : null; 
			
			const LineConv!ubyte convert8	= get_converter!ubyte(dc.src_chans, dc.tgt_chans); 
			const LineConv!ushort convert16	= get_converter!ushort(dc.src_chans, dc.tgt_chans); 
			
			if(dc.ilace == InterlaceMethod.None)
			{
				immutable size_t src_linelen = dc.w * dc.src_chans; 
				immutable size_t tgt_linelen = dc.w * dc.tgt_chans; 
				
				size_t ti = 0;    //target index
				foreach(j; 0 .. dc.h)
				{
					uncompress_line(dc, len, metaready, cline); 
					ubyte filter_type = cline[0]; 
					
					recon(cline[1..$], pline[1..$], filter_type, filter_step); 
					
					ubyte[] bytes;  //defiltered bytes or 8-bit samples from palette
					if(dc.src_indexed)
					{
						depalette(dc.palette, dc.transparency, cline[1..$], depaletted); 
						bytes = depaletted[0 .. src_linelen]; 
					}else
					{ bytes = cline[1..$]; }
					
					//convert colors
					if(dc.req_bpc == 8)
					{
						line8_from_bytes(bytes, dc.bpc, cline8); 
						convert8(cline8[0 .. src_linelen], result8[ti .. ti + tgt_linelen]); 
					}else
					{
						line16_from_bytes(bytes, dc.bpc, cline16); 
						convert16(cline16[0 .. src_linelen], result16[ti .. ti + tgt_linelen]); 
					}
					
					ti += tgt_linelen; 
					
					ubyte[] _swap = pline; 
					pline = cline; 
					cline = _swap; 
				}
			}else
			{
				//Adam7 interlacing
				
				immutable size_t[7] redw = [
					(dc.w + 7) / 8,
														(dc.w + 3) / 8,
														(dc.w + 3) / 4,
														(dc.w + 1) / 4,
														(dc.w + 1) / 2,
														(dc.w + 0) / 2,
														(dc.w + 0) / 1
				]; 
				
				immutable size_t[7] redh = [
					(dc.h + 7) / 8,
														(dc.h + 7) / 8,
														(dc.h + 3) / 8,
														(dc.h + 3) / 4,
														(dc.h + 1) / 4,
														(dc.h + 1) / 2,
														(dc.h + 0) / 2
				]; 
				
				auto redline8 = (dc.req_bpc == 8) ? new ubyte[dc.w * dc.tgt_chans] : null; 
				auto redline16 = (dc.req_bpc == 16) ? new ushort[dc.w * dc.tgt_chans] : null; 
				
				foreach(pass; 0 .. 7)
				{
					const A7_Catapult tgt_px = a7_catapults[pass];   //target pixel
					const size_t src_linelen = redw[pass] * dc.src_chans; 
					ubyte[] cln = cline[0 .. redw[pass] * filter_step + 1]; 
					ubyte[] pln = pline[0 .. redw[pass] * filter_step + 1]; 
					pln[] = 0; 
					
					foreach(j; 0 .. redh[pass])
					{
						uncompress_line(dc, len, metaready, cln); 
						ubyte filter_type = cln[0]; 
						
						recon(cln[1..$], pln[1..$], filter_type, filter_step); 
						
						ubyte[] bytes;  //defiltered bytes or 8-bit samples from palette
						if(dc.src_indexed)
						{
							depalette(dc.palette, dc.transparency, cln[1..$], depaletted); 
							bytes = depaletted[0 .. src_linelen]; 
						}else
						{ bytes = cln[1..$]; }
						
						//convert colors and sling pixels from reduced image to final buffer
						if(dc.req_bpc == 8)
						{
							line8_from_bytes(bytes, dc.bpc, cline8); 
							convert8(cline8[0 .. src_linelen], redline8[0 .. redw[pass]*dc.tgt_chans]); 
							for(size_t i, redi; i < redw[pass]; ++i, redi += dc.tgt_chans)
							{
								size_t tgt = tgt_px(i, j, dc.w) * dc.tgt_chans; 
								result8[tgt .. tgt + dc.tgt_chans] =
									redline8[redi .. redi + dc.tgt_chans]; 
							}
						}else
						{
							line16_from_bytes(bytes, dc.bpc, cline16); 
							convert16(cline16[0 .. src_linelen], redline16[0 .. redw[pass]*dc.tgt_chans]); 
							for(size_t i, redi; i < redw[pass]; ++i, redi += dc.tgt_chans)
							{
								size_t tgt = tgt_px(i, j, dc.w) * dc.tgt_chans; 
								result16[tgt .. tgt + dc.tgt_chans] =
									redline16[redi .. redi + dc.tgt_chans]; 
							}
						}
						
						ubyte[] _swap = pln; 
						pln = cln; 
						cln = _swap; 
					}
				}
			}
			
			if(!metaready)
			{
				dc.stream.readExact(dc.chunkmeta, 12);   //crc | len & type
				ubyte[4] crc = dc.crc.finish; 
				reverse(crc[]); 
				if(crc != dc.chunkmeta[0..4])
				throw new ImageIOException("corrupt chunk"); 
			}
			
			Buffer result; 
			switch(dc.req_bpc)
			{
				case 8: result.bpc8 = result8; return result; 
				case 16: result.bpc16 = result16; return result; 
				default: throw new ImageIOException("internal error"); 
			}
		} 
		
		void line8_from_bytes(ubyte[] src, int bpc, ref ubyte[] tgt)
		{
			switch(bpc)
			{
				case 8: 
					tgt = src; 
					break; 
				case 16: 
					for(size_t k, t;   k < src.length;   k+=2, t+=1)
				{ tgt[t] = src[k]; /*truncate*/}
					break; 
				default: throw new ImageIOException("unsupported bit depth (and bug)"); 
			}
		} 
		
		void line16_from_bytes(in ubyte[] src, int bpc, ushort[] tgt)
		{
			switch(bpc)
			{
				case 8: 
					for(size_t k;   k < src.length;   k+=1)
				{ tgt[k] = src[k] * 256 + 128; }
					break; 
				case 16: 
					for(size_t k, t;   k < src.length;   k+=2, t+=1)
				{ tgt[t] = src[k] << 8 | src[k+1]; }
					break; 
				default: throw new ImageIOException("unsupported bit depth (and bug)"); 
			}
		} 
		
		void depalette(in ubyte[] palette, in ubyte[] transparency, in ubyte[] src_line, ubyte[] depaletted) pure
		{
			for(size_t s, d;  s < src_line.length;  s+=1, d+=4)
			{
				ubyte pid = src_line[s]; 
				size_t pidx = pid * 3; 
				if(palette.length < pidx + 3)
				throw new ImageIOException("palette index wrong"); 
				depaletted[d .. d+3] = palette[pidx .. pidx+3]; 
				depaletted[d+3] = (pid < transparency.length) ? transparency[pid] : 255; 
			}
		} 
		
		alias A7_Catapult = size_t function(size_t redx, size_t redy, size_t dstw); 
		immutable A7_Catapult[7] a7_catapults = [
			&a7_red1_to_dst,
			&a7_red2_to_dst,
			&a7_red3_to_dst,
			&a7_red4_to_dst,
			&a7_red5_to_dst,
			&a7_red6_to_dst,
			&a7_red7_to_dst,
		]; 
		
		pure nothrow
		{
			size_t a7_red1_to_dst(size_t redx, size_t redy, size_t dstw)
			{ return redy*8*dstw + redx*8;     } 
			size_t a7_red2_to_dst(size_t redx, size_t redy, size_t dstw)
			{ return redy*8*dstw + redx*8+4;   } 
			size_t a7_red3_to_dst(size_t redx, size_t redy, size_t dstw)
			{ return (redy*8+4)*dstw + redx*4; } 
			size_t a7_red4_to_dst(size_t redx, size_t redy, size_t dstw)
			{ return redy*4*dstw + redx*4+2;   } 
			size_t a7_red5_to_dst(size_t redx, size_t redy, size_t dstw)
			{ return (redy*4+2)*dstw + redx*2; } 
			size_t a7_red6_to_dst(size_t redx, size_t redy, size_t dstw)
			{ return redy*2*dstw + redx*2+1;   } 
			size_t a7_red7_to_dst(size_t redx, size_t redy, size_t dstw)
			{ return (redy*2+1)*dstw + redx;   } 
		} 
		
		void uncompress_line(ref PNG_Decoder dc, ref int length, ref bool metaready, ubyte[] dst)
		{
			size_t readysize = min(dst.length, dc.uc_buf.length); 
			dst[0 .. readysize] = dc.uc_buf[0 .. readysize]; 
			dc.uc_buf = dc.uc_buf[readysize .. $]; 
			
			if(readysize == dst.length)
			return; 
			
			while(readysize != dst.length)
			{
				//need new data for dc.uc_buf...
				if(length <= 0)
				{
					  //IDAT is read -> read next chunks meta
					dc.stream.readExact(dc.chunkmeta, 12);   //crc | len & type
					ubyte[4] crc = dc.crc.finish; 
					reverse(crc[]); 
					if(crc != dc.chunkmeta[0..4])
					throw new ImageIOException("corrupt chunk"); 
					
					length = bigEndianToNative!int(dc.chunkmeta[4..8]); 
					if(dc.chunkmeta[8..12] != "IDAT")
					{
						//no new IDAT chunk so flush, this is the end of the IDAT stream
						metaready = true; 
						dc.uc_buf = cast(ubyte[]) dc.uc.flush(); 
						size_t part2 = dst.length - readysize; 
						if(dc.uc_buf.length < part2)
						throw new ImageIOException("not enough data"); 
						dst[readysize .. readysize+part2] = dc.uc_buf[0 .. part2]; 
						dc.uc_buf = dc.uc_buf[part2 .. $]; 
						return; 
					}
					if(
						length <= 0//empty IDAT chunk
					)
					throw new	ImageIOException("not enough data"); 
					dc.crc.put(dc.chunkmeta[8..12]); 	//type
				}
				
				size_t bytes = min(length, dc.read_buf.length); 
				dc.stream.readExact(dc.read_buf, bytes); 
				length -= bytes; 
				dc.crc.put(dc.read_buf[0..bytes]); 
				
				if(bytes <= 0)
				throw new ImageIOException("not enough data"); 
				
				dc.uc_buf = cast(ubyte[]) dc.uc.uncompress(dc.read_buf[0..bytes].dup); 
				
				size_t part2 = min(dst.length - readysize, dc.uc_buf.length); 
				dst[readysize .. readysize+part2] = dc.uc_buf[0 .. part2]; 
				dc.uc_buf = dc.uc_buf[part2 .. $]; 
				readysize += part2; 
			}
		} 
		
		void recon(ubyte[] cline, in ubyte[] pline, ubyte ftype, size_t fstep) pure
		{
			switch(ftype)
			with(PNG_FilterType)
			{
				case None: 
					break; 
				case Sub: 
					foreach(k; fstep .. cline.length)
				cline[k] += cline[k-fstep]; 
					break; 
				case Up: 
					foreach(k; 0 .. cline.length)
				cline[k] += pline[k]; 
					break; 
				case Average: 
					foreach(k; 0 .. fstep)
				cline[k] += pline[k] / 2; 
					foreach(k; fstep .. cline.length)
				cline[k] += cast(ubyte)
							((cast(uint) cline[k-fstep] + cast(uint) pline[k]) / 2); 
					break; 
				case Paeth: 
					foreach(i; 0 .. fstep)
				cline[i] += paeth(0, pline[i], 0); 
					foreach(i; fstep .. cline.length)
				cline[i] += paeth(cline[i-fstep], pline[i], pline[i-fstep]); 
					break; 
				default: 
					throw new ImageIOException("filter type not supported"); 
			}
			
		} 
		
		ubyte paeth(ubyte a, ubyte b, ubyte c) pure nothrow
		{
			int pc = cast(int) c; 
			int pa = cast(int) b - pc; 
			int pb = cast(int) a - pc; 
			pc = pa + pb; 
			if(pa < 0)
			pa = -pa; 
			if(pb < 0)
			pb = -pb; 
			if(pc < 0)
			pc = -pc; 
			
			if(pa <= pb && pa <= pc)
			{ return a; }else if(pb <= pc)
			{ return b; }
			return c; 
		} 
		
		//----------------------------------------------------------------------
		//PNG encoder
		
		void write_png(Writer stream, long w, long h, in ubyte[] data, long tgt_chans = 0)
		{
			if(w < 1 || h < 1 || int.max < w || int.max < h)
			throw new ImageIOException("invalid dimensions"); 
			uint src_chans = cast(uint) (data.length / w / h); 
			if(src_chans < 1 || 4 < src_chans || tgt_chans < 0 || 4 < tgt_chans)
			throw new ImageIOException("invalid channel count"); 
			if(src_chans * w * h != data.length)
			throw new ImageIOException("mismatching dimensions and length"); 
			
			PNG_Encoder ec = {
				stream	: stream,
				w	: cast(size_t) w,
				h	: cast(size_t) h,
				src_chans	: src_chans,
				tgt_chans	: tgt_chans ? cast(uint) tgt_chans : src_chans,
				data	: data,
			}; 
			
			write_png(ec); 
			stream.flush(); 
		} 
		
		struct PNG_Encoder
		{
			Writer stream; 
			size_t w, h; 
			uint src_chans; 
			uint tgt_chans; 
			const(ubyte)[] data; 
			
			CRC32 crc; 
			
			uint writelen; 	//how much written of current idat data
			ubyte[] chunk_buf; 		//len type data crc
			ubyte[] data_buf; 	 //slice of chunk_buf, for just chunk data
		} 
		
		void write_png(ref PNG_Encoder ec)
		{
			ubyte[33] hdr = void; 
			hdr[0 ..  8] = png_file_header; 
			hdr[8 .. 16] = png_image_header; 
			hdr[16 .. 20] = nativeToBigEndian(cast(uint) ec.w); 
			hdr[20 .. 24] = nativeToBigEndian(cast(uint) ec.h); 
			hdr[24      ] = 8;  //bit depth
			hdr[25      ] = color_type(ec.tgt_chans); 
			hdr[26 .. 29] = 0;  //compression, filter and interlace methods
			ec.crc.start(); 
			ec.crc.put(hdr[12 .. 29]); 
			ubyte[4] crc = ec.crc.finish(); 
			reverse(crc[]); 
			hdr[29 .. 33] = crc; 
			ec.stream.rawWrite(hdr); 
			
			write_IDATs(ec); 
			
			static immutable ubyte[12] iend =
				[0, 0, 0, 0, 'I','E','N','D', 0xae, 0x42, 0x60, 0x82]; 
			ec.stream.rawWrite(iend); 
		} 
		
		void write_IDATs(ref PNG_Encoder ec)
		{
			immutable long max_idatlen = 4 * 4096; 
			ec.writelen = 0; 
			ec.chunk_buf = new ubyte[8 + max_idatlen + 4]; 
			ec.data_buf = ec.chunk_buf[8 .. 8 + max_idatlen]; 
			static immutable ubyte[4] IDAT = ['I','D','A','T']; 
			ec.chunk_buf[4 .. 8] = IDAT; 
			
			immutable size_t linesize = ec.w * ec.tgt_chans + 1; //+1 for filter type
			ubyte[] cline = new ubyte[linesize]; 
			ubyte[] pline = new ubyte[linesize];    //initialized to 0
			
			ubyte[] filtered_line = new ubyte[linesize]; 
			ubyte[] filtered_image; 
			
			const LineConv!ubyte convert = get_converter!ubyte(ec.src_chans, ec.tgt_chans); 
			
			immutable size_t filter_step = ec.tgt_chans;   //step between pixels, in bytes
			immutable size_t src_linesize = ec.w * ec.src_chans; 
			
			size_t si = 0; 
			foreach(j; 0 .. ec.h)
			{
				convert(ec.data[si .. si+src_linesize], cline[1..$]); 
				si += src_linesize; 
				
				foreach(i; 1 .. filter_step+1)
				filtered_line[i] = cast(ubyte) (cline[i] - paeth(0, pline[i], 0)); 
				foreach(i; filter_step+1 .. cline.length)
				filtered_line[i] = cast(ubyte)
					(cline[i] - paeth(cline[i-filter_step], pline[i], pline[i-filter_step])); 
				
				filtered_line[0] = PNG_FilterType.Paeth; 
				
				filtered_image ~= filtered_line; 
				
				ubyte[] _swap = pline; 
				pline = cline; 
				cline = _swap; 
			}
			
			const (void)[] xx = compress(filtered_image, 6); 
			
			ec.write_to_IDAT_stream(xx); 
			if(0 < ec.writelen)
			ec.write_IDAT_chunk(); 
		} 
		
		void write_to_IDAT_stream(ref PNG_Encoder ec, in void[] _compressed)
		{
			ubyte[] compressed = cast(ubyte[]) _compressed; 
			while(compressed.length)
			{
				size_t space_left = ec.data_buf.length - ec.writelen; 
				size_t writenow_len = min(space_left, compressed.length); 
				ec.data_buf[ec.writelen .. ec.writelen + writenow_len] =
					compressed[0 .. writenow_len]; 
				ec.writelen += writenow_len; 
				compressed = compressed[writenow_len .. $]; 
				if(ec.writelen == ec.data_buf.length)
				ec.write_IDAT_chunk(); 
			}
		} 
		
		//chunk: len type data crc, type is already in buf
		void write_IDAT_chunk(ref PNG_Encoder ec)
		{
			ec.chunk_buf[0 .. 4] = nativeToBigEndian!uint(ec.writelen); 
			ec.crc.put(ec.chunk_buf[4 .. 8 + ec.writelen]);   //crc of type and data
			ubyte[4] crc = ec.crc.finish(); 
			reverse(crc[]); 
			ec.chunk_buf[8 + ec.writelen .. 8 + ec.writelen + 4] = crc; 
			ec.stream.rawWrite(ec.chunk_buf[0 .. 8 + ec.writelen + 4]); 
			ec.writelen = 0; 
		} 
		
		package void read_png_info(Reader stream, out int w, out int h, out int chans)
		{
			PNG_Header hdr = read_png_header(stream); 
			w = hdr.width; 
			h = hdr.height; 
			chans = channels(cast(PNG_ColorType) hdr.color_type); 
		} 
	}
	version(/+$DIDE_REGION TGA+/all)
	{
		//module imageformats.tga; 
		
		import std.algorithm	: min; 
		import std.bitmanip	: littleEndianToNative, nativeToLittleEndian; 
		import std.typecons	: scoped; 
		
		private: 
		
		/// Header of a TGA file.
		public struct TGA_Header
		{
			 ubyte id_length; 
			 ubyte palette_type; 
			 ubyte data_type; 
			 ushort palette_start; 
			 ushort palette_length; 
			 ubyte palette_bits; 
			 ushort x_origin; 
			 ushort y_origin; 
			 ushort width; 
			 ushort height; 
			 ubyte bits_pp; 
			 ubyte flags; 
		} 
		
		/// Returns the header of a TGA file.
		public TGA_Header read_tga_header(in char[] filename)
		{
			auto reader = scoped!FileReader(filename); 
			return read_tga_header(reader); 
		} 
		
		/// Reads the image header from a buffer containing a TGA image.
		public TGA_Header read_tga_header_from_mem(in ubyte[] source)
		{
			auto reader = scoped!MemReader(source); 
			return read_tga_header(reader); 
		} 
		
		/// Reads a TGA image. req_chans defines the format of returned image
		/// (you can use ColFmt here).
		public IFImage read_tga(in char[] filename, long req_chans = 0)
		{
			auto reader = scoped!FileReader(filename); 
			return read_tga(reader, req_chans); 
		} 
		
		/// Reads an image from a buffer containing a TGA image. req_chans defines the
		/// format of returned image (you can use ColFmt here).
		public IFImage read_tga_from_mem(in ubyte[] source, long req_chans = 0)
		{
			auto reader = scoped!MemReader(source); 
			return read_tga(reader, req_chans); 
		} 
		
		/// Writes a TGA image into a file.
		public void write_tga(in char[] file, long w, long h, in ubyte[] data, long tgt_chans = 0)
		{
			auto writer = scoped!FileWriter(file); 
			write_tga(writer, w, h, data, tgt_chans); 
		} 
		
		/// Writes a TGA image into a buffer.
		public ubyte[] write_tga_to_mem(long w, long h, in ubyte[] data, long tgt_chans = 0)
		{
			auto writer = scoped!MemWriter(); 
			write_tga(writer, w, h, data, tgt_chans); 
			return writer.result; 
		} 
		
		/// Returns width, height and color format information via w, h and chans.
		public void read_tga_info(in char[] filename, out int w, out int h, out int chans)
		{
			auto reader = scoped!FileReader(filename); 
			return read_tga_info(reader, w, h, chans); 
		} 
		
		/// Returns width, height and color format information via w, h and chans.
		public void read_tga_info_from_mem(in ubyte[] source, out int w, out int h, out int chans)
		{
			auto reader = scoped!MemReader(source); 
			return read_tga_info(reader, w, h, chans); 
		} 
		
		//Detects whether a TGA image is readable from stream.
		package bool detect_tga(Reader stream)
		{
			try
			{
				auto hdr = read_tga_header(stream); 
				return true; 
			}catch(Throwable)
			{ return false; }finally
			{ stream.seek(0, SEEK_SET); }
		} 
		
		TGA_Header read_tga_header(Reader stream)
		{
			ubyte[18] tmp = void; 
			stream.readExact(tmp, tmp.length); 
			
			TGA_Header hdr = {
				id_length	 : tmp[0],
				palette_type	 : tmp[1],
				data_type	 : tmp[2],
				palette_start	 : littleEndianToNative!ushort(tmp[3..5]),
				palette_length	 : littleEndianToNative!ushort(tmp[5..7]),
				palette_bits	 : tmp[7],
				x_origin	 : littleEndianToNative!ushort(tmp[8..10]),
				y_origin	 : littleEndianToNative!ushort(tmp[10..12]),
				width	 : littleEndianToNative!ushort(tmp[12..14]),
				height	 : littleEndianToNative!ushort(tmp[14..16]),
				bits_pp	 : tmp[16],
				flags	 : tmp[17],
			}; 
			
			if(
				hdr.width < 1 || hdr.height < 1 || hdr.palette_type > 1
					|| (
					hdr.palette_type == 0 && (
						hdr.palette_start
															 || hdr.palette_length
															 || hdr.palette_bits
					)
				)
					|| (4 <= hdr.data_type && hdr.data_type <= 8) || 12 <= hdr.data_type
			)
			throw new ImageIOException("corrupt TGA header"); 
			
			return hdr; 
		} 
		
		package IFImage read_tga(Reader stream, long req_chans = 0)
		{
			if(req_chans < 0 || 4 < req_chans)
			throw new ImageIOException("come on..."); 
			
			TGA_Header hdr = read_tga_header(stream); 
			
			if(hdr.width < 1 || hdr.height < 1)
			throw new ImageIOException("invalid dimensions"); 
			if(
				hdr.flags & 0xc0//two bits
			)
			throw new ImageIOException("interlaced TGAs not supported"); 
			if(hdr.flags & 0x10)
			throw new ImageIOException("right-to-left TGAs not supported"); 
			ubyte attr_bits_pp = (hdr.flags & 0xf); 
			if(
				! (attr_bits_pp == 0 || attr_bits_pp == 8)//some set it 0 although data has 8
			)
			throw new ImageIOException("only 8-bit alpha/attribute(s) supported"); 
			if(hdr.palette_type)
			throw new ImageIOException("paletted TGAs not supported"); 
			
			bool rle = false; 
			switch(hdr.data_type)
			with(TGA_DataType)
			{
				//case 1: ;   // paletted, uncompressed
				case TrueColor: 
					if(! (hdr.bits_pp == 24 || hdr.bits_pp == 32))
				throw new ImageIOException("not supported"); 
					break; 
				case Gray: 
					if(! (hdr.bits_pp == 8 || (hdr.bits_pp == 16 && attr_bits_pp == 8)))
				throw new ImageIOException("not supported"); 
					break; 
				//case 9: ;   // paletted, RLE
				case TrueColor_RLE: 
					if(! (hdr.bits_pp == 24 || hdr.bits_pp == 32))
				throw new ImageIOException("not supported"); 
					rle = true; 
					break; 
				case Gray_RLE: 
					if(! (hdr.bits_pp == 8 || (hdr.bits_pp == 16 && attr_bits_pp == 8)))
				throw new ImageIOException("not supported"); 
					rle = true; 
					break; 
				default: throw new ImageIOException("data type not supported"); 
			}
			
			
			int src_chans = hdr.bits_pp / 8; 
			
			if(hdr.id_length)
			stream.seek(hdr.id_length, SEEK_CUR); 
			
			TGA_Decoder dc = {
				stream	 : stream,
				w	 : hdr.width,
				h	 : hdr.height,
				origin_at_top	 : cast(bool) (hdr.flags & 0x20),
				bytes_pp	 : hdr.bits_pp / 8,
				rle	 : rle,
				tgt_chans	 : (req_chans == 0) ? src_chans : cast(int) req_chans,
			}; 
			
			switch(dc.bytes_pp)
			{
				case 1: dc.src_fmt = _ColFmt.Y; break; 
				case 2: dc.src_fmt = _ColFmt.YA; break; 
				case 3: dc.src_fmt = _ColFmt.BGR; break; 
				case 4: dc.src_fmt = _ColFmt.BGRA; break; 
				default: throw new ImageIOException("TGA: format not supported"); 
			}
			
			IFImage result = {
				w	: dc.w,
				h	: dc.h,
				c	: cast(ColFmt) dc.tgt_chans,
				pixels	: decode_tga(dc),
			}; 
			return result; 
		} 
		
		void write_tga(Writer stream, long w, long h, in ubyte[] data, long tgt_chans = 0)
		{
			if(w < 1 || h < 1 || ushort.max < w || ushort.max < h)
			throw new ImageIOException("invalid dimensions"); 
			ulong src_chans = data.length / w / h; 
			if(src_chans < 1 || 4 < src_chans || tgt_chans < 0 || 4 < tgt_chans)
			throw new ImageIOException("invalid channel count"); 
			if(src_chans * w * h != data.length)
			throw new ImageIOException("mismatching dimensions and length"); 
			
			TGA_Encoder ec = {
				stream	: stream,
				w	: cast(ushort) w,
				h	: cast(ushort) h,
				src_chans	: cast(int) src_chans,
				tgt_chans	: cast(int) ((tgt_chans) ? tgt_chans : src_chans),
				rle	: true,
				data	: data,
			}; 
			
			write_tga(ec); 
			stream.flush(); 
		} 
		
		struct TGA_Decoder
		{
			Reader stream; 
			int w, h; 
			bool origin_at_top;    //src
			uint bytes_pp; 
			bool rle;   //run length compressed
			_ColFmt src_fmt; 
			uint tgt_chans; 
		} 
		
		ubyte[] decode_tga(ref TGA_Decoder dc)
		{
			auto result = new ubyte[dc.w * dc.h * dc.tgt_chans]; 
			
			immutable size_t tgt_linesize = dc.w * dc.tgt_chans; 
			immutable size_t src_linesize = dc.w * dc.bytes_pp; 
			auto src_line = new ubyte[src_linesize]; 
			
			immutable ptrdiff_t tgt_stride	= (dc.origin_at_top) ? tgt_linesize : -tgt_linesize; 
			ptrdiff_t ti	= (dc.origin_at_top) ? 0 : (dc.h-1) * tgt_linesize; 
			
			const LineConv!ubyte convert = get_converter!ubyte(dc.src_fmt, dc.tgt_chans); 
			
			if(!dc.rle)
			{
				foreach(_j; 0 .. dc.h)
				{
					dc.stream.readExact(src_line, src_linesize); 
					convert(src_line, result[ti .. ti + tgt_linesize]); 
					ti += tgt_stride; 
				}
				return result; 
			}
			
			//----- RLE  -----
			
			auto rbuf = new ubyte[src_linesize]; 
			size_t plen = 0; 	//packet length
			bool its_rle = false; 	
			
			foreach(_j; 0 .. dc.h)
			{
				//fill src_line with uncompressed data (this works like a stream)
				size_t wanted = src_linesize; 
				while(wanted)
				{
					if(plen == 0)
					{
						dc.stream.readExact(rbuf, 1); 
						its_rle = cast(bool) (rbuf[0] & 0x80); 
						plen = ((rbuf[0] & 0x7f) + 1) * dc.bytes_pp; //length in bytes
					}
					const size_t gotten = src_linesize - wanted; 
					const size_t copysize = min(plen, wanted); 
					if(its_rle)
					{
						dc.stream.readExact(rbuf, dc.bytes_pp); 
						for(size_t p = gotten; p < gotten+copysize; p += dc.bytes_pp)
						src_line[p .. p+dc.bytes_pp] = rbuf[0 .. dc.bytes_pp]; 
					}else
					{
							//it's raw
						auto slice = src_line[gotten .. gotten+copysize]; 
						dc.stream.readExact(slice, copysize); 
					}
					wanted -= copysize; 
					plen -= copysize; 
				}
				
				convert(src_line, result[ti .. ti + tgt_linesize]); 
				ti += tgt_stride; 
			}
			
			return result; 
		} 
		
		//----------------------------------------------------------------------
		//TGA encoder
		
		immutable ubyte[18] tga_footer_sig =
			['T','R','U','E','V','I','S','I','O','N','-','X','F','I','L','E','.', 0]; 
		
		struct TGA_Encoder
		{
			Writer stream; 
			ushort w, h; 
			int src_chans; 
			int tgt_chans; 
			bool rle;   //run length compression
			const(ubyte)[] data; 
		} 
		
		void write_tga(ref TGA_Encoder ec)
		{
			ubyte data_type; 
			bool has_alpha = false; 
			switch(ec.tgt_chans)
			with(TGA_DataType)
			{
				case 1: data_type = ec.rle ? Gray_RLE : Gray; 	break; 
				case 2: data_type = ec.rle ? Gray_RLE : Gray; 	has_alpha = true; 	break; 
				case 3: data_type = ec.rle ? TrueColor_RLE : TrueColor; 		break; 
				case 4: data_type = ec.rle ? TrueColor_RLE : TrueColor; 	has_alpha = true; 	break; 
				default: throw new ImageIOException("internal error"); 
			}
			
			
			ubyte[18] hdr = void; 	
			hdr[0] = 0; 				//id length
			hdr[1] = 0; 				//palette type
			hdr[2] = data_type; 	
			hdr[3..8] = 0; 	//palette start (2), len (2), bits per palette entry (1)
			hdr[8..12] = 0;     //x origin (2), y origin (2)
			hdr[12..14] = nativeToLittleEndian(ec.w); 
			hdr[14..16] = nativeToLittleEndian(ec.h); 
			hdr[16] = cast(ubyte) (ec.tgt_chans * 8);     //bits per pixel
			hdr[17] = (has_alpha) ? 0x8 : 0x0;     //flags: attr_bits_pp = 8
			ec.stream.rawWrite(hdr); 
			
			write_image_data(ec); 
			
			ubyte[26] ftr = void; 
			ftr[0..4] = 0; 		 //extension area offset
			ftr[4..8] = 0; 		 //developer directory offset
			ftr[8..26] = tga_footer_sig; 
			ec.stream.rawWrite(ftr); 
		} 
		
		void write_image_data(ref TGA_Encoder ec)
		{
			_ColFmt tgt_fmt; 
			switch(ec.tgt_chans)
			{
				case 1: tgt_fmt = _ColFmt.Y; break; 
				case 2: tgt_fmt = _ColFmt.YA; break; 
				case 3: tgt_fmt = _ColFmt.BGR; break; 
				case 4: tgt_fmt = _ColFmt.BGRA; break; 
				default: throw new ImageIOException("internal error"); 
			}
			
			const LineConv!ubyte convert = get_converter!ubyte(ec.src_chans, tgt_fmt); 
			
			immutable size_t src_linesize = ec.w * ec.src_chans; 
			immutable size_t tgt_linesize = ec.w * ec.tgt_chans; 
			auto tgt_line = new ubyte[tgt_linesize]; 
			
			ptrdiff_t si = (ec.h-1) * src_linesize;     //origin at bottom
			
			if(!ec.rle)
			{
				foreach(_; 0 .. ec.h)
				{
					convert(ec.data[si .. si + src_linesize], tgt_line); 
					ec.stream.rawWrite(tgt_line); 
					si -= src_linesize; //origin at bottom
				}
				return; 
			}
			
			//----- RLE  -----
			
			immutable bytes_pp = ec.tgt_chans; 
			immutable size_t max_packets_per_line = (tgt_linesize+127) / 128; 
			auto tgt_cmp = new ubyte[tgt_linesize + max_packets_per_line];  //compressed line
			foreach(_; 0 .. ec.h)
			{
				convert(ec.data[si .. si + src_linesize], tgt_line); 
				ubyte[] compressed_line = rle_compress(tgt_line, tgt_cmp, ec.w, bytes_pp); 
				ec.stream.rawWrite(compressed_line); 
				si -= src_linesize; //origin at bottom
			}
		} 
		
		ubyte[] rle_compress(in ubyte[] line, ubyte[] tgt_cmp, in size_t w, in int bytes_pp) pure
		{
			immutable int rle_limit = (1 < bytes_pp) ? 2 : 3;  //run len worth an RLE packet
			size_t runlen = 0; 
			size_t rawlen = 0; 
			size_t raw_i = 0; //start of raw packet data in line
			size_t cmp_i = 0; 
			size_t pixels_left = w; 
			const (ubyte)[]	px; 
			for(size_t i = bytes_pp; pixels_left; i += bytes_pp)
			{
				runlen = 1; 
				px = line[i-bytes_pp .. i]; 
				while(i < line.length && line[i .. i+bytes_pp] == px[0..$] && runlen < 128)
				{
					++runlen; 
					i += bytes_pp; 
				}
				pixels_left -= runlen; 
				
				if(runlen < rle_limit)
				{
					//data goes to raw packet
					rawlen += runlen; 
					if(128 <= rawlen)
					{
							 //full packet, need to store it
						size_t copysize = 128 * bytes_pp; 
						tgt_cmp[cmp_i++] = 0x7f; //raw packet header
						tgt_cmp[cmp_i .. cmp_i+copysize] = line[raw_i .. raw_i+copysize]; 
						cmp_i += copysize; 
						raw_i += copysize; 
						rawlen -= 128; 
					}
				}else
				{
					//RLE packet is worth it
					
					//store raw packet first, if any
					if(rawlen)
					{
						assert(rawlen < 128); 
						size_t copysize = rawlen * bytes_pp; 
						tgt_cmp[cmp_i++] = cast(ubyte) (rawlen-1); //raw packet header
						tgt_cmp[cmp_i .. cmp_i+copysize] = line[raw_i .. raw_i+copysize]; 
						cmp_i += copysize; 
						rawlen = 0; 
					}
					
					//store RLE packet
					tgt_cmp[cmp_i++] = cast(ubyte) (0x80 | (runlen-1)); //packet header
					tgt_cmp[cmp_i .. cmp_i+bytes_pp] = px[0..$];       //packet data
					cmp_i += bytes_pp; 
					raw_i = i; 
				}
			}	//for
			
			if(rawlen)
			{
				   //last packet of the line
				size_t copysize = rawlen * bytes_pp; 
				tgt_cmp[cmp_i++] = cast(ubyte) (rawlen-1); //raw packet header
				tgt_cmp[cmp_i .. cmp_i+copysize] = line[raw_i .. raw_i+copysize]; 
				cmp_i += copysize; 
			}
			return tgt_cmp[0 .. cmp_i]; 
		} 
		
		enum TGA_DataType : ubyte
		{
			Idx	= 1,
			TrueColor	= 2,
			Gray	= 3,
			Idx_RLE	= 9,
			TrueColor_RLE	= 10,
			Gray_RLE	= 11,
		} 
		
		package void read_tga_info(Reader stream, out int w, out int h, out int chans)
		{
			TGA_Header hdr = read_tga_header(stream); 
			w = hdr.width; 
			h = hdr.height; 
			
			//TGA is awkward...
			auto dt = hdr.data_type; 
			if(
				(
					dt == TGA_DataType.TrueColor     || dt == TGA_DataType.Gray ||
							 dt == TGA_DataType.TrueColor_RLE || dt == TGA_DataType.Gray_RLE
				)
						 && (hdr.bits_pp % 8) == 0
			)
			{
				chans = hdr.bits_pp / 8; 
				return; 
			}else if(dt == TGA_DataType.Idx || dt == TGA_DataType.Idx_RLE)
			{
				switch(hdr.palette_bits)
				{
					case 15: chans = 3; return; 
					case 16: chans = 3; return; //one bit could be for some "interrupt control"
					case 24: chans = 3; return; 
					case 32: chans = 4; return; 
					default: 
				}
			}
			chans = 0; 	//unknown
		} 
	}version(/+$DIDE_REGION turboJPEG+/all)
	{
		//module turbojpeg.turbojpeg; 
			
		//Source:        https://github.com/rtbo/turbojpeg-d/blob/master/source/turbojpeg/turbojpeg.d
		//Documentation: https://github.com/D-Programming-Deimos/jpeg-turbo/blob/master/source/libjpeg/turbojpeg.d
		
		
		/+
			MIT License
			
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
			SOFTWARE.
		+/
		
		//extra stuff for the integration with hetlib ////////////////////////////////////
		
		pragma(lib, "turbojpeg-static.lib"); 
		
		void tjChk(tjhandle h, int res, string what)
		{
			if(res==0)
			return; 
			import std.format; 
			throw new Exception(format!"TurboJpeg Error: %s %s"(what, tjGetErrorStr2(h))); 
		} 
		
		//Auto-create a separate instance for each thread
		import std.exception : enforce; 
		auto tjDecoder()
		{
			static tjhandle h; if(!h)
			{ h = tjInitDecompress; enforce(h, "tjInitDecompress() fail."); }return h; 
		} 
		auto tjEncoder()
		{
			static tjhandle h; if(!h)
			{ h = tjInitCompress; enforce(h, "tjInitCompress() fail."  ); }return h; 
		} 
		
		//original stuff //////////////////////////////////////////////////////////////////
		
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
			int function(
				short* coeffs, tjregion arrayRegion, tjregion planeRegion,
							int componentIndex, int transformIndex, tjtransform* transform
			) customFilter; 
		} 
		
		alias tjhandle = void*; 
		
		extern (D) auto TJPAD(W)(in W width)
		{ return (width + 3) & (~3); } 
		
		extern (D) auto TJSCALED(D)(in D dimension, in tjscalingfactor scalingFactor)
		{ return (dimension * scalingFactor.num + scalingFactor.denom - 1) / scalingFactor.denom; } 
		
		tjhandle tjInitCompress(); 
		
		int tjCompress2(
			tjhandle handle, const(ubyte)* srcBuf, int width, int pitch,
				int height, int pixelFormat, ubyte** jpegBuf, c_ulong* jpegSize,
				int jpegSubsamp, int jpegQual, int flags
		); 
		
		int tjCompressFromYUV(
			tjhandle handle, const(ubyte)* srcBuf, int width, int pad,
				int height, int subsamp, ubyte** jpegBuf, c_ulong* jpegSize, int jpegQual, int flags
		); 
		
		int tjCompressFromYUVPlanes(
			tjhandle handle, const(ubyte)** srcPlanes,
				int width, const(int)* strides, int height, int subsamp, ubyte** jpegBuf,
				c_ulong* jpegSize, int jpegQual, int flags
		); 
		
		c_ulong tjBufSize(int width, int height, int jpegSubsamp); 
		
		c_ulong tjBufSizeYUV2(int width, int pad, int height, int subsamp); 
		
		c_ulong tjPlaneSizeYUV(int componentID, int width, int stride, int height, int subsamp); 
		
		int tjPlaneWidth(int componentID, int width, int subsamp); 
		
		int tjPlaneHeight(int componentID, int height, int subsamp); 
		
		int tjEncodeYUV3(
			tjhandle handle, const(ubyte)* srcBuf, int width, int pitch,
				int height, int pixelFormat, ubyte* dstBuf, int pad, int subsamp, int flags
		); 
		
		int tjEncodeYUVPlanes(
			tjhandle handle, const(ubyte)* srcBuf, int width, int pitch,
				int height, int pixelFormat, ubyte** dstPlanes, int* strides, int subsamp, int flags
		); 
		
		tjhandle tjInitDecompress(); 
		
		int tjDecompressHeader3(
			tjhandle handle, const(ubyte)* jpegBuf, c_ulong jpegSize,
				int* width, int* height, int* jpegSubsamp, int* jpegColorspace
		); 
		
		tjscalingfactor* tjGetScalingFactors(int* numscalingfactors); 
		
		int tjDecompress2(
			tjhandle handle, const(ubyte)* jpegBuf, c_ulong jpegSize,
				ubyte* dstBuf, int width, int pitch, int height, int pixelFormat, int flags
		); 
		
		int tjDecompressToYUV2(
			tjhandle handle, const(ubyte)* jpegBuf, c_ulong jpegSize,
				ubyte* dstBuf, int width, int pad, int height, int flags
		); 
		
		int tjDecompressToYUVPlanes(
			tjhandle handle, const(ubyte)* jpegBuf,
				c_ulong jpegSize, ubyte** dstPlanes, int width, int* strides, int height, int flags
		); 
		
		int tjDecodeYUV(
			tjhandle handle, const(ubyte)* srcBuf, int pad, int subsamp,
				ubyte* dstBuf, int width, int pitch, int height, int pixelFormat, int flags
		); 
		
		int tjDecodeYUVPlanes(
			tjhandle handle, const(ubyte)** srcPlanes,
				const int* strides, int subsamp, ubyte* dstBuf, int width, int pitch,
				int height, int pixelFormat, int flags
		); 
		
		tjhandle tjInitTransform(); 
		
		int tjTransform(
			tjhandle handle, const(ubyte)* jpegBuf, c_ulong jpegSize, int n,
				ubyte** dstBufs, c_ulong* dstSizes, tjtransform* transforms, int flags
		); 
		
		int tjDestroy(tjhandle handle); 
		
		ubyte* tjAlloc(int bytes); 
		
		ubyte* tjLoadImage(
			const(char)* filename, int* width, int alignment,
				int* height, int* pixelFormat, int flags
		); 
		
		int tjSaveImage(
			const(char)* filename, ubyte* buffer, int width, int pitch,
				int height, int pixelFormat, int flags
		); 
		
		void tjFree(ubyte* buffer); 
		
		char* tjGetErrorStr2(tjhandle handle); 
		
		int tjGetErrorCode(tjhandle handle); 
		
		
		deprecated: 
		
		c_ulong TJBUFSIZE(int width, int height); 
		
		c_ulong TJBUFSIZEYUV(int width, int height, int jpegSubsamp); 
		
		c_ulong tjBufSizeYUV(int width, int height, int subsamp); 
		
		int tjCompress(
			tjhandle handle, ubyte *srcBuf, int width,
									 int pitch, int height, int pixelSize,
									 ubyte *dstBuf, c_ulong *compressedSize,
									 int jpegSubsamp, int jpegQual, int flags
		); 
		
		int tjEncodeYUV(
			tjhandle handle, ubyte *srcBuf, int width,
										 int pitch, int height, int pixelSize,
										 ubyte *dstBuf, int subsamp, int flags
		); 
		
		int tjEncodeYUV2(
			tjhandle	handle, ubyte *srcBuf, int width,
										int pitch, int height, int pixelFormat,
										ubyte *dstBuf, int subsamp, int flags
		); 
		
		int tjDecompressHeader(
			tjhandle handle, ubyte *jpegBuf,
											 c_ulong jpegSize, int *width,
											 int *height
		); 
		
		int tjDecompressHeader2(
			tjhandle handle, ubyte *jpegBuf,
												 c_ulong jpegSize, int *width,
												 int *height, int *jpegSubsamp
		); 
		
		int tjDecompress(
			tjhandle	handle, ubyte *jpegBuf,
										c_ulong jpegSize, ubyte *dstBuf,
										int width, int pitch, int height, int pixelSize,
										int flags
		); 
		
		int tjDecompressToYUV(
			tjhandle handle, ubyte *jpegBuf,
											c_ulong jpegSize, ubyte *dstBuf,
											int flags
		); 
		
		char *tjGetErrorStr(); 
	}version(/+$DIDE_REGION WEBP+/all)
	{
		pragma(lib, "libwebp.lib"); 
		extern (C)
		{
			//Copyright 2011 Google Inc. All Rights Reserved.
			//
			//Use of this source code is governed by a BSD-style license
			//that can be found in the COPYING file in the root of the source
			//tree. An additional intellectual property rights grant can be found
			//in the file PATENTS. All contributing project authors may
			//be found in the AUTHORS file in the root of the source tree.
			//-----------------------------------------------------------------------------
			//
			//   WebP encoder: main interface
			//
			//Author: Skal (pascal.massimino@gmail.com)
				
			//public import webp.types;
			
			enum WEBP_ENCODER_ABI_VERSION = 0x0202;    //MAJOR(8b) + MINOR(8b)
			
			//Return the encoder's version number, packed in hexadecimal using 8bits for
			//each of major/minor/revision. E.g: v2.5.7 is 0x020507.
			int WebPGetEncoderVersion(); 
			
			//------------------------------------------------------------------------------
			//One-stop-shop call! No questions asked:
			
			//Returns the size of the compressed data (pointed to by *output), or 0 if
			//an error occurred. The compressed data must be released by the caller
			//using the call 'free(*output)'.
			//These functions compress using the lossy format, and the quality_factor
			//can go from 0 (smaller output, lower quality) to 100 (best quality,
			//larger output).
			size_t WebPEncodeRGB(
				in ubyte*	rgb,
				int width, int height, int stride,
				float quality_factor, ubyte** output
			); 
			size_t WebPEncodeBGR(
				in ubyte*	bgr,
				int width, int height, int stride,
				float quality_factor, ubyte** output
			); 
			size_t WebPEncodeRGBA(
				in ubyte* rgba,
				int width, int height, int stride,
				float quality_factor, ubyte** output
			); 
			size_t WebPEncodeBGRA(
				in ubyte* bgra,
				int width, int height, int stride,
				float quality_factor, ubyte** output
			); 
			
			//These functions are the equivalent of the above, but compressing in a
			//lossless manner. Files are usually larger than lossy format, but will
			//not suffer any compression loss.
			size_t WebPEncodeLosslessRGB(
				in ubyte* rgb,
				int width, int height, int stride,
				ubyte** output
			); 
			size_t WebPEncodeLosslessBGR(
				in ubyte* bgr,
				int width, int height, int stride,
				ubyte** output
			); 
			size_t WebPEncodeLosslessRGBA(
				in ubyte* rgba,
				int width, int height, int stride,
				ubyte** output
			); 
			size_t WebPEncodeLosslessBGRA(
				in ubyte* bgra,
				int width, int height, int stride,
				ubyte** output
			); 
			
			//------------------------------------------------------------------------------
			//Coding parameters
			
			//Image characteristics hint for the underlying encoder.
			enum WebPImageHint
			{
				WEBP_HINT_DEFAULT = 0,	 //default preset.
				WEBP_HINT_PICTURE,	 //digital picture, like portrait, inner shot
				WEBP_HINT_PHOTO,	 //outdoor photograph, with natural lighting
				WEBP_HINT_GRAPH,	 //Discrete tone image (graph, map-tile etc).
				WEBP_HINT_LAST
			} 
			
			//Compression parameters.
			struct WebPConfig
			{
				int lossless; 	         //Lossless encoding (0=lossy(default), 1=lossless).
				float quality; 	         //between 0 (smallest file) and 100 (biggest)
				int method; 	         //quality/speed trade-off (0=fast, 6=slower-better)
				
				WebPImageHint image_hint;  //Hint for image type (lossless only for now).
				
				//Parameters related to lossy compression only:
				int target_size; 	 //if non-zero, set the desired target size in bytes.
					//Takes precedence over the 'compression' parameter.
				float target_PSNR; 	 //if non-zero, specifies the minimal distortion to
					//try to achieve. Takes precedence over target_size.
				int segments; 	 //maximum number of segments to use, in [1..4]
				int sns_strength; 	 //Spatial Noise Shaping. 0=off, 100=maximum.
				int filter_strength; 	 //range: [0 = off .. 100 = strongest]
				int filter_sharpness; 	 //range: [0 = off .. 7 = least sharp]
				int filter_type; 	 //filtering type: 0 = simple, 1 = strong (only used
					//if filter_strength > 0 or autofilter > 0)
				int autofilter; 	 //Auto adjust filter's strength [0 = off, 1 = on]
				int alpha_compression; 	 //Algorithm for encoding the alpha plane (0 = none,
					//1 = compressed with WebP lossless). Default is 1.
				int alpha_filtering; 	 //Predictive filtering method for alpha plane.
					//0: none, 1: fast, 2: best. Default if 1.
				int alpha_quality; 	 //Between 0 (smallest size) and 100 (lossless).
					//Default is 100.
				int pass; 	 //number of entropy-analysis passes (in [1..10]).
				
				int show_compressed; 	 //if true, export the compressed picture back.
					//In-loop filtering is not applied.
				int preprocessing; 	 //preprocessing filter:
					//0=none, 1=segment-smooth, 2=pseudo-random dithering
				int partitions; 	 //log2(number of token partitions) in [0..3]. Default
					//is set to 0 for easier progressive decoding.
				int partition_limit; 	 //quality degradation allowed to fit the 512k limit
					//on prediction modes coding (0: no degradation,
					//100: maximum possible degradation).
				int emulate_jpeg_size; 	 //If true, compression parameters will be remapped
					//to better match the expected output size from
					//JPEG compression. Generally, the output size will
					//be similar but the degradation will be lower.
				int thread_level; 	 //If non-zero, try and use multi-threaded encoding.
				int low_memory; 	 //If set, reduce memory usage (but increase CPU use).
				
				uint[5] pad;            //padding for later use
			} 
			
			//Enumerate some predefined settings for WebPConfig, depending on the type
			//of source picture. These presets are used when calling WebPConfigPreset().
			enum WebPPreset
			{
				WEBP_PRESET_DEFAULT = 0,	 //default preset.
				WEBP_PRESET_PICTURE,	 //digital picture, like portrait, inner shot
				WEBP_PRESET_PHOTO,	 //outdoor photograph, with natural lighting
				WEBP_PRESET_DRAWING,	 //hand or line drawing, with high-contrast details
				WEBP_PRESET_ICON,	 //small-sized colorful images
				WEBP_PRESET_TEXT	 //text-like
			} 
			
			//Internal, version-checked, entry point
			int WebPConfigInitInternal(WebPConfig*, WebPPreset, float, int); 
			
			//Should always be called, to initialize a fresh WebPConfig structure before
			//modification. Returns false in case of version mismatch. WebPConfigInit()
			//must have succeeded before using the 'config' object.
			//Note that the default values are lossless=0 and quality=75.
			int WebPConfigInit(WebPConfig* config)
			{
				return WebPConfigInitInternal(
					config, WebPPreset.WEBP_PRESET_DEFAULT, 75.0f,
					WEBP_ENCODER_ABI_VERSION
				); 
			} 
			
			//This function will initialize the configuration according to a predefined
			//set of parameters (referred to by 'preset') and a given quality factor.
			//This function can be called as a replacement to WebPConfigInit(). Will
			//return false in case of error.
			int WebPConfigPreset(
				WebPConfig* config,
				WebPPreset preset, float quality
			)
			{
				return WebPConfigInitInternal(
					config, preset, quality,
					WEBP_ENCODER_ABI_VERSION
				); 
			} 
			
			//Returns true if 'config' is non-NULL and all configuration parameters are
			//within their valid ranges.
			int WebPValidateConfig(in WebPConfig* config); 
			
			//------------------------------------------------------------------------------
			//Input / Output
			//Structure for storing auxiliary statistics (mostly for lossy encoding).
			
			struct WebPAuxStats
			{
				int coded_size; 	//final size
					
				float[5] PSNR; 	//peak-signal-to-noise ratio for Y/U/V/All/Alpha
				int[3] block_count; 	//number of intra4/intra16/skipped macroblocks
				int[2] header_bytes; 	//approximate number of bytes spent for header
					//and mode-partition #0
				int[3][4] residual_bytes; 	//approximate number of bytes spent for
					//DC/AC/uv coefficients for each (0..3) segments.
				int[4] segment_size; 	//number of macroblocks in each segments
				int[4] segment_quant; 	//quantizer values for each segments
				int[4] segment_level; 	//filtering strength for each segments [0..63]
					
				int alpha_data_size; 	//size of the transparency data
				int layer_data_size; 	//size of the enhancement layer data
				
				//lossless encoder statistics
				uint lossless_features; 	//bit0:predictor bit1:cross-color transform
					//bit2:subtract-green bit3:color indexing
				int histogram_bits; 	//number of precision bits of histogram
				int transform_bits; 	//precision bits for transform
				int cache_bits; 	//number of bits for color cache lookup
				int palette_size; 	//number of color in palette, if used
				int lossless_size; 	//final lossless size
					
				uint[4] pad; 	//padding for later use
			} 
			
			//Signature for output function. Should return true if writing was successful.
			//data/data_size is the segment of data to write, and 'picture' is for
			//reference (and so one can make use of picture->custom_ptr).
			alias int function(
				in ubyte*	data, size_t data_size,
													in WebPPicture* picture
			) WebPWriterFunction; 
			
			//WebPMemoryWrite: a special WebPWriterFunction that writes to memory using
			//the following WebPMemoryWriter object (to be set as a custom_ptr).
			struct WebPMemoryWriter
			{
				ubyte* mem; 	 //final buffer (of size 'max_size', larger than 'size').
				size_t		 size; 	 //final size
				size_t		 max_size; 	 //total capacity
				uint[1] pad;        //padding for later use
			} 
			
			//The following must be called first before any use.
			void WebPMemoryWriterInit(WebPMemoryWriter* writer); 
			
			//The custom writer to be used with WebPMemoryWriter as custom_ptr. Upon
			//completion, writer.mem and writer.size will hold the coded data.
			//if (WEBP_ENCODER_ABI_VERSION > 0x0203)
			//writer.mem must be freed by calling WebPMemoryWriterClear.
			
			//} else {
			//writer.mem must be freed by calling 'free(writer.mem)'.
			//}
			int WebPMemoryWrite(
				in ubyte* data, size_t data_size,
												 in WebPPicture* picture
			); 
			
			//Progress hook, called from time to time to report progress. It can return
			//false to request an abort of the encoding process, or true otherwise if
			//everything is OK.
			alias int function(int percent, in WebPPicture* picture) WebPProgressHook; 
			
			//Color spaces.
			enum WebPEncCSP
			{
				//chroma sampling
				WEBP_YUV420	= 0,	  //4:2:0
				WEBP_YUV420A	= 4,	  //alpha channel variant
				WEBP_CSP_UV_MASK = 3,	  //bit-mask to get the UV sampling factors
				WEBP_CSP_ALPHA_BIT = 4	  //bit that is set if alpha is present
			} 
			
			//Encoding error conditions.
			enum WebPEncodingError
			{
				VP8_ENC_OK = 0,
				VP8_ENC_ERROR_OUT_OF_MEMORY,	 //memory error allocating objects
				VP8_ENC_ERROR_BITSTREAM_OUT_OF_MEMORY,	 //memory error while flushing bits
				VP8_ENC_ERROR_NULL_PARAMETER,	 //a pointer parameter is NULL
				VP8_ENC_ERROR_INVALID_CONFIGURATION,	 //configuration is invalid
				VP8_ENC_ERROR_BAD_DIMENSION,	 //picture has invalid width/height
				VP8_ENC_ERROR_PARTITION0_OVERFLOW,	 //partition is bigger than 512k
				VP8_ENC_ERROR_PARTITION_OVERFLOW,	 //partition is bigger than 16M
				VP8_ENC_ERROR_BAD_WRITE,	 //error while flushing bytes
				VP8_ENC_ERROR_FILE_TOO_BIG,	 //file is bigger than 4G
				VP8_ENC_ERROR_USER_ABORT,	 //abort request by user
				VP8_ENC_ERROR_LAST	 //list terminator. always last.
			} 
			
			//maximum width/height allowed (inclusive), in pixels
			enum WEBP_MAX_DIMENSION = 16383; 
			
			//Main exchange structure (input samples, output bytes, statistics)
			struct WebPPicture
			{
				//   INPUT
				//////////////
				//Main flag for encoder selecting between ARGB or YUV input.
				//It is recommended to use ARGB input (*argb, argb_stride) for lossless
				//compression, and YUV input (*y, *u, *v, etc.) for lossy compression
				//since these are the respective native colorspace for these formats.
				int use_argb; 
				
				//YUV input (mostly used for input to lossy compression)
				WebPEncCSP colorspace; 		  //colorspace: should be YUV420 for now (=Y'CbCr).
				int width, height; 			//dimensions (less or equal to WEBP_MAX_DIMENSION)
				ubyte* y, u, v; 		//pointers to luma/chroma planes.
				int y_stride, uv_stride; 	  //luma/chroma strides.
				ubyte* a; 	  //pointer to the alpha plane
				int a_stride; 	  //stride of the alpha plane
				uint[2] pad1;              //padding for later use
				
				//ARGB input (mostly used for input to lossless compression)
				uint* argb; 	          //Pointer to argb (32 bit) plane.
				int argb_stride; 	          //This is stride in pixels units, not bytes.
				uint[3] pad2;              //padding for later use
				
				//   OUTPUT
				///////////////
				//Byte-emission hook, to store compressed bytes as they are ready.
				WebPWriterFunction writer; 	 //can be NULL
				void* custom_ptr; 	 //can be used by the writer.
				
				//map for extra information (only for lossy compression mode)
				int extra_info_type; 	   //1: intra type, 2: segment, 3: quant
						 //4: intra-16 prediction mode,
						 //5: chroma prediction mode,
						 //6: bit cost, 7: distortion
				ubyte* extra_info; 	   //if not NULL, points to an array of size
						 //((width + 15) / 16) * ((height + 15) / 16) that
						 //will be filled with a macroblock map, depending
						 //on extra_info_type.
				
				//   STATS AND REPORTS
				///////////////////////////
				//Pointer to side statistics (updated only if not NULL)
				WebPAuxStats* stats; 
				
				//Error code for the latest error encountered during encoding
				WebPEncodingError error_code; 
				
				//If not NULL, report progress during encoding.
				WebPProgressHook progress_hook; 
				
				void* user_data; 	       //this field is free to be set to any value and
				       //used during callbacks (like progress-report e.g.).
				
				uint[3] pad3;           //padding for later use
				
				//Unused for now: original samples (for non-YUV420 modes)
				ubyte* pad4, pad5; 
				uint[8] pad6; 
				
				//PRIVATE FIELDS
				////////////////////
				void* memory_; 		//row chunk of memory for yuva planes
				void* memory_argb_; 		    //and for argb too.
				void*[2] pad7;          //padding for later use
			} 
			
			//Internal, version-checked, entry point
			int WebPPictureInitInternal(WebPPicture*, int); 
			
			//Should always be called, to initialize the structure. Returns false in case
			//of version mismatch. WebPPictureInit() must have succeeded before using the
			//'picture' object.
			//Note that, by default, use_argb is false and colorspace is WEBP_YUV420.
			int WebPPictureInit(WebPPicture* picture)
			{ return WebPPictureInitInternal(picture, WEBP_ENCODER_ABI_VERSION); } 
			
			//------------------------------------------------------------------------------
			//WebPPicture utils
			
			//Convenience allocation / deallocation based on picture->width/height:
			//Allocate y/u/v buffers as per colorspace/width/height specification.
			//Note! This function will free the previous buffer if needed.
			//Returns false in case of memory error.
			int WebPPictureAlloc(WebPPicture* picture); 
			
			//Release the memory allocated by WebPPictureAlloc() or WebPPictureImport*().
			//Note that this function does _not_ free the memory used by the 'picture'
			//object itself.
			//Besides memory (which is reclaimed) all other fields of 'picture' are
			//preserved.
			void WebPPictureFree(WebPPicture* picture); 
			
			//Copy the pixels of *src into *dst, using WebPPictureAlloc. Upon return, *dst
			//will fully own the copied pixels (this is not a view). The 'dst' picture need
			//not be initialized as its content is overwritten.
			//Returns false in case of memory allocation error.
			int WebPPictureCopy(in WebPPicture* src, WebPPicture* dst); 
			
			//Compute PSNR, SSIM or LSIM distortion metric between two pictures.
			//Result is in dB, stores in result[] in the Y/U/V/Alpha/All order.
			//Returns false in case of error (src and ref don't have same dimension, ...)
			//Warning: this function is rather CPU-intensive.
			int WebPPictureDistortion(
				in WebPPicture* src, in WebPPicture* _ref,
				int metric_type,           //0 = PSNR, 1 = SSIM, 2 = LSIM
				float* result
			); //[5]
			
			//self-crops a picture to the rectangle defined by top/left/width/height.
			//Returns false in case of memory allocation error, or if the rectangle is
			//outside of the source picture.
			//The rectangle for the view is defined by the top-left corner pixel
			//coordinates (left, top) as well as its width and height. This rectangle
			//must be fully be comprised inside the 'src' source picture. If the source
			//picture uses the YUV420 colorspace, the top and left coordinates will be
			//snapped to even values.
			int WebPPictureCrop(
				WebPPicture* picture,
												 int left, int top, int width, int height
			); 
			
			//Extracts a view from 'src' picture into 'dst'. The rectangle for the view
			//is defined by the top-left corner pixel coordinates (left, top) as well
			//as its width and height. This rectangle must be fully be comprised inside
			//the 'src' source picture. If the source picture uses the YUV420 colorspace,
			//the top and left coordinates will be snapped to even values.
			//Picture 'src' must out-live 'dst' picture. Self-extraction of view is allowed
			//('src' equal to 'dst') as a mean of fast-cropping (but note that doing so,
			//the original dimension will be lost). Picture 'dst' need not be initialized
			//with WebPPictureInit() if it is different from 'src', since its content will
			//be overwritten.
			//Returns false in case of memory allocation error or invalid parameters.
			int WebPPictureView(
				in WebPPicture* src,
												 int left, int top, int width, int height,
												 WebPPicture* dst
			); 
			
			//Returns true if the 'picture' is actually a view and therefore does
			//not own the memory for pixels.
			int WebPPictureIsView(in WebPPicture* picture); 
			
			//Rescale a picture to new dimension width x height.
			//If either 'width' or 'height' (but not both) is 0 the corresponding
			//dimension will be calculated preserving the aspect ratio.
			//No gamma correction is applied.
			//Returns false in case of error (invalid parameter or insufficient memory).
			int WebPPictureRescale(WebPPicture* pic, int width, int height); 
			
			//Colorspace conversion function to import RGB samples.
			//Previous buffer will be free'd, if any.
			//*rgb buffer should have a size of at least height * rgb_stride.
			//Returns false in case of memory error.
			int WebPPictureImportRGB(WebPPicture* picture, in ubyte* rgb, int rgb_stride); 
			//Same, but for RGBA buffer.
			int WebPPictureImportRGBA(WebPPicture* picture, in ubyte* rgba, int rgba_stride); 
			//Same, but for RGBA buffer. Imports the RGB direct from the 32-bit format
			//input buffer ignoring the alpha channel. Avoids needing to copy the data
			//to a temporary 24-bit RGB buffer to import the RGB only.
			
			int WebPPictureImportRGBX(WebPPicture* picture, in ubyte* rgbx, int rgbx_stride); 
			
			//Variants of the above, but taking BGR(A|X) input.
			int WebPPictureImportBGR(WebPPicture* picture, in ubyte* bgr, int bgr_stride); 
			int WebPPictureImportBGRA(WebPPicture* picture, in ubyte* bgra, int bgra_stride); 
			int WebPPictureImportBGRX(WebPPicture* picture, in ubyte* bgrx, int bgrx_stride); 
			
			//Converts picture->argb data to the YUV420A format. The 'colorspace'
			//parameter is deprecated and should be equal to WEBP_YUV420.
			//Upon return, picture->use_argb is set to false. The presence of real
			//non-opaque transparent values is detected, and 'colorspace' will be
			//adjusted accordingly. Note that this method is lossy.
			//Returns false in case of error.
			int WebPPictureARGBToYUVA(
				WebPPicture* picture,
													   WebPEncCSP colorspace
			); 
			
			//Same as WebPPictureARGBToYUVA(), but the conversion is done using
			//pseudo-random dithering with a strength 'dithering' between
			//0.0 (no dithering) and 1.0 (maximum dithering). This is useful
			//for photographic picture.
			int WebPPictureARGBToYUVADithered(WebPPicture* picture, WebPEncCSP colorspace, float dithering); 
			
			//Converts picture->yuv to picture->argb and sets picture->use_argb to true.
			//The input format must be YUV_420 or YUV_420A.
			//Note that the use of this method is discouraged if one has access to the
			//raw ARGB samples, since using YUV420 is comparatively lossy. Also, the
			//conversion from YUV420 to ARGB incurs a small loss too.
			//Returns false in case of error.
			int WebPPictureYUVAToARGB(WebPPicture* picture); 
			
			//Helper function: given a width x height plane of RGBA or YUV(A) samples
			//clean-up the YUV or RGB samples under fully transparent area, to help
			//compressibility (no guarantee, though).
			void WebPCleanupTransparentArea(WebPPicture* picture); 
			
			//Scan the picture 'picture' for the presence of non fully opaque alpha values.
			//Returns true in such case. Otherwise returns false (indicating that the
			//alpha plane can be ignored altogether e.g.).
			int WebPPictureHasTransparency(in WebPPicture* picture); 
			
			//Remove the transparency information (if present) by blending the color with
			//the background color 'background_rgb' (specified as 24bit RGB triplet).
			//After this call, all alpha values are reset to 0xff.
			void WebPBlendAlpha(WebPPicture* pic, uint background_rgb); 
			
			//------------------------------------------------------------------------------
			//Main call
			
			//Main encoding call, after config and picture have been initialized.
			//'picture' must be less than 16384x16384 in dimension (cf WEBP_MAX_DIMENSION),
			//and the 'config' object must be a valid one.
			//Returns false in case of error, true otherwise.
			//In case of error, picture->error_code is updated accordingly.
			//'picture' can hold the source samples in both YUV(A) or ARGB input, depending
			//on the value of 'picture->use_argb'. It is highly recommended to use
			//the former for lossy encoding, and the latter for lossless encoding
			//(when config.lossless is true). Automatic conversion from one format to
			//another is provided but they both incur some loss.
			int WebPEncode(in WebPConfig* config, WebPPicture* picture); 
			
			//------------------------------------------------------------------------------
			
		} extern (C)
		{
			//Copyright 2010 Google Inc. All Rights Reserved.
			//
			//Use of this source code is governed by a BSD-style license
			//that can be found in the COPYING file in the root of the source
			//tree. An additional intellectual property rights grant can be found
			//in the file PATENTS. All contributing project authors may
			//be found in the AUTHORS file in the root of the source tree.
			//-----------------------------------------------------------------------------
			//
			//Main decoding functions for WebP images.
			//
			//Author: Skal (pascal.massimino@gmail.com)
			
			import std.typecons; 
			
			enum WEBP_DECODER_ABI_VERSION = 0x0203;    //MAJOR(8b) + MINOR(8b)
			
			
			alias WebPIDecoder = Typedef!(void*); 
			
			
			//Return the decoder's version number, packed in hexadecimal using 8bits for
			//each of major/minor/revision. E.g: v2.5.7 is 0x020507.
			int WebPGetDecoderVersion(); 
			
			//Retrieve basic header information: width, height.
			//This function will also validate the header and return 0 in
			//case of formatting error.
			//Pointers 'width' and 'height' can be passed NULL if deemed irrelevant.
			int WebPGetInfo(
				in ubyte* data, size_t data_size,
								int* width, int* height
			); 
			
			//Decodes WebP images pointed to by 'data' and returns RGBA samples, along
			//with the dimensions in *width and *height. The ordering of samples in
			//memory is R, G, B, A, R, G, B, A... in scan order (endian-independent).
			//The returned pointer should be deleted calling free().
			//Returns NULL in case of error.
			ubyte* WebPDecodeRGBA(
				in ubyte* data, size_t data_size,
									  int* width, int* height
			); 
			
			//Same as WebPDecodeRGBA, but returning A, R, G, B, A, R, G, B... ordered data.
			ubyte* WebPDecodeARGB(
				in ubyte* data, size_t data_size,
									  int* width, int* height
			); 
			
			//Same as WebPDecodeRGBA, but returning B, G, R, A, B, G, R, A... ordered data.
			ubyte* WebPDecodeBGRA(
				in ubyte* data, size_t data_size,
									  int* width, int* height
			); 
			
			//Same as WebPDecodeRGBA, but returning R, G, B, R, G, B... ordered data.
			//If the bitstream contains transparency, it is ignored.
			ubyte* WebPDecodeRGB(
				in ubyte* data, size_t data_size,
									 int* width, int* height
			); 
			
			//Same as WebPDecodeRGB, but returning B, G, R, B, G, R... ordered data.
			ubyte* WebPDecodeBGR(
				in ubyte* data, size_t data_size,
									 int* width, int* height
			); 
			
			
			//Decode WebP images pointed to by 'data' to Y'UV format(*). The pointer
			//returned is the Y samples buffer. Upon return, *u and *v will point to
			//the U and V chroma data. These U and V buffers need NOT be free()'d,
			//unlike the returned Y luma one. The dimension of the U and V planes
			//are both (*width + 1) / 2 and (*height + 1)/ 2.
			//Upon return, the Y buffer has a stride returned as '*stride', while U and V
			//have a common stride returned as '*uv_stride'.
			//Return NULL in case of error.
			//(*) Also named Y'CbCr. See: http://en.wikipedia.org/wiki/YCbCr
			ubyte* WebPDecodeYUV(
				in ubyte* data, size_t data_size,
									 int* width, int* height,
									 ubyte** u, ubyte** v,
									 int* stride, int* uv_stride
			); 
			
			//These five functions are variants of the above ones, that decode the image
			//directly into a pre-allocated buffer 'output_buffer'. The maximum storage
			//available in this buffer is indicated by 'output_buffer_size'. If this
			//storage is not sufficient (or an error occurred), NULL is returned.
			//Otherwise, output_buffer is returned, for convenience.
			//The parameter 'output_stride' specifies the distance (in bytes)
			//between scanlines. Hence, output_buffer_size is expected to be at least
			//output_stride x picture-height.
			ubyte* WebPDecodeRGBAInto(
				in ubyte* data, size_t data_size,
				ubyte* output_buffer, size_t output_buffer_size, int output_stride
			); 
			ubyte* WebPDecodeARGBInto(
				in ubyte* data, size_t data_size,
				ubyte* output_buffer, size_t output_buffer_size, int output_stride
			); 
			ubyte* WebPDecodeBGRAInto(
				in ubyte* data, size_t data_size,
				ubyte* output_buffer, size_t output_buffer_size, int output_stride
			); 
			
			//RGB and BGR variants. Here too the transparency information, if present,
			//will be dropped and ignored.
			ubyte* WebPDecodeRGBInto(
				in ubyte* data, size_t data_size,
				ubyte* output_buffer, size_t output_buffer_size, int output_stride
			); 
			ubyte* WebPDecodeBGRInto(
				in ubyte* data, size_t data_size,
				ubyte* output_buffer, size_t output_buffer_size, int output_stride
			); 
			
			//WebPDecodeYUVInto() is a variant of WebPDecodeYUV() that operates directly
			//into pre-allocated luma/chroma plane buffers. This function requires the
			//strides to be passed: one for the luma plane and one for each of the
			//chroma ones. The size of each plane buffer is passed as 'luma_size',
			//'u_size' and 'v_size' respectively.
			//Pointer to the luma plane ('*luma') is returned or NULL if an error occurred
			//during decoding (or because some buffers were found to be too small).
			
			ubyte* WebPDecodeYUVInto(
				in ubyte* data, size_t data_size,
				ubyte* luma, size_t luma_size, int luma_stride,
				ubyte* u, size_t u_size, int u_stride,
				ubyte* v, size_t v_size, int v_stride
			); 
			
			//------------------------------------------------------------------------------
			//Output colorspaces and buffer
			
			//Colorspaces
			//Note: the naming describes the byte-ordering of packed samples in memory.
			//For instance, MODE_BGRA relates to samples ordered as B,G,R,A,B,G,R,A,...
			//Non-capital names (e.g.:MODE_Argb) relates to pre-multiplied RGB channels.
			//RGBA-4444 and RGB-565 colorspaces are represented by following byte-order:
			//RGBA-4444: [r3 r2 r1 r0 g3 g2 g1 g0], [b3 b2 b1 b0 a3 a2 a1 a0], ...
			//RGB-565: [r4 r3 r2 r1 r0 g5 g4 g3], [g2 g1 g0 b4 b3 b2 b1 b0], ...
			//In the case WEBP_SWAP_16BITS_CSP is defined, the bytes are swapped for
			//these two modes:
			//RGBA-4444: [b3 b2 b1 b0 a3 a2 a1 a0], [r3 r2 r1 r0 g3 g2 g1 g0], ...
			//RGB-565: [g2 g1 g0 b4 b3 b2 b1 b0], [r4 r3 r2 r1 r0 g5 g4 g3], ...
			
			enum WEBP_CSP_MODE
			{
				MODE_RGB = 0, MODE_RGBA = 1,
				MODE_BGR = 2, MODE_BGRA = 3,
				MODE_ARGB = 4, MODE_RGBA_4444 = 5,
				MODE_RGB_565 = 6,
				//RGB-premultiplied transparent modes (alpha value is preserved)
				MODE_rgbA = 7,
				MODE_bgrA = 8,
				MODE_Argb = 9,
				MODE_rgbA_4444 = 10,
				//YUV modes must come after RGB ones.
				MODE_YUV = 11, MODE_YUVA = 12,  //yuv 4:2:0
				MODE_LAST = 13
			} 
			
			//Some useful macros:
			static int WebPIsPremultipliedMode(WEBP_CSP_MODE mode)
			{
				return (
					mode == WEBP_CSP_MODE.MODE_rgbA || 
					mode == WEBP_CSP_MODE.MODE_bgrA || 
					mode == WEBP_CSP_MODE.MODE_Argb ||
					mode == WEBP_CSP_MODE.MODE_rgbA_4444
				); 
			} 
			
			static int WebPIsAlphaMode(WEBP_CSP_MODE mode)
			{
				return (
					mode == WEBP_CSP_MODE.MODE_RGBA || 
					mode == WEBP_CSP_MODE.MODE_BGRA || 
					mode == WEBP_CSP_MODE.MODE_ARGB ||
					mode == WEBP_CSP_MODE.MODE_RGBA_4444 || 
					mode == WEBP_CSP_MODE.MODE_YUVA ||
					WebPIsPremultipliedMode(mode)
				); 
			} 
			
			static int WebPIsRGBMode(WEBP_CSP_MODE mode)
			{ return (mode < WEBP_CSP_MODE.MODE_YUV); } 
			
			//------------------------------------------------------------------------------
			//WebPDecBuffer: Generic structure for describing the output sample buffer.
			
			struct WebPRGBABuffer
			{
					//view as RGBA
				ubyte* rgba;    //pointer to RGBA samples
				int stride; 	     //stride in bytes from one scanline to the next.
				size_t size; 	     //total size of the *rgba buffer.
			} ; 
			
			struct WebPYUVABuffer
			{
										//view as YUVA
				ubyte* y; 
				ubyte *u; 
				ubyte *v; 
				ubyte *a; 	//pointer to luma, chroma U/V, alpha samples
				int y_stride; 		    //luma stride
				int u_stride,	v_stride; 	    //chroma strides
				int a_stride; 					 //alpha stride
				size_t y_size; 				 //luma plane size
				size_t u_size, v_size; 	    //chroma planes size
				size_t a_size; 	    //alpha-plane size
			} ; 
			
			//Output buffer
			struct WebPDecBuffer
			{
				WEBP_CSP_MODE colorspace; 	//Colorspace.
				int width, height; 	//Dimensions.
				int is_external_memory; 	//If true, 'internal_memory' pointer is not used.
				union u
				{
					WebPRGBABuffer RGBA; 
					WebPYUVABuffer YUVA; 
				} //Nameless union of buffer parameters.
				uint[4] pad;               //padding for later use
				
				ubyte* private_memory; 	//Internally allocated memory (only when
					//is_external_memory is false). Should not be used
					//externally, but accessed via the buffer union.
			} ; 
			
			//Internal, version-checked, entry point
			int WebPInitDecBufferInternal(WebPDecBuffer*, int); 
			
			//Initialize the structure as empty. Must be called before any other use.
			//Returns false in case of version mismatch
			static int WebPInitDecBuffer(WebPDecBuffer* buffer)
			{ return WebPInitDecBufferInternal(buffer, WEBP_DECODER_ABI_VERSION); } 
			
			//Free any memory associated with the buffer. Must always be called last.
			//Note: doesn't free the 'buffer' structure itself.
			void WebPFreeDecBuffer(WebPDecBuffer* buffer); 
			
			//------------------------------------------------------------------------------
			//Enumeration of the status codes
			
			enum VP8StatusCode
			{
				VP8_STATUS_OK = 0,
				VP8_STATUS_OUT_OF_MEMORY,
				VP8_STATUS_INVALID_PARAM,
				VP8_STATUS_BITSTREAM_ERROR,
				VP8_STATUS_UNSUPPORTED_FEATURE,
				VP8_STATUS_SUSPENDED,
				VP8_STATUS_USER_ABORT,
				VP8_STATUS_NOT_ENOUGH_DATA
			} 
			
			//------------------------------------------------------------------------------
			//Incremental decoding
			//
			//This API allows streamlined decoding of partial data.
			//Picture can be incrementally decoded as data become available thanks to the
			//WebPIDecoder object. This object can be left in a SUSPENDED state if the
			//picture is only partially decoded, pending additional input.
			//Code example:
			//
			//   WebPInitDecBuffer(&buffer);
			//   buffer.colorspace = mode;
			//   ...
			//   WebPIDecoder* idec = WebPINewDecoder(&buffer);
			//   while (has_more_data) {
			//// ... (get additional data)
			//status = WebPIAppend(idec, new_data, new_data_size);
			//if (status != VP8_STATUS_SUSPENDED ||
			//   break;
			//}
			//
			//// The above call decodes the current available buffer.
			//// Part of the image can now be refreshed by calling to
			//// WebPIDecGetRGB()/WebPIDecGetYUVA() etc.
			//   }
			//   WebPIDelete(idec);
			
			//Creates a new incremental decoder with the supplied buffer parameter.
			//This output_buffer can be passed NULL, in which case a default output buffer
			//is used (with MODE_RGB). Otherwise, an internal reference to 'output_buffer'
			//is kept, which means that the lifespan of 'output_buffer' must be larger than
			//that of the returned WebPIDecoder object.
			//The supplied 'output_buffer' content MUST NOT be changed between calls to
			//WebPIAppend() or WebPIUpdate() unless 'output_buffer.is_external_memory' is
			//set to 1. In such a case, it is allowed to modify the pointers, size and
			//stride of output_buffer.u.RGBA or output_buffer.u.YUVA, provided they remain
			//within valid bounds.
			//All other fields of WebPDecBuffer MUST remain constant between calls.
			//Returns NULL if the allocation failed.
			WebPIDecoder* WebPINewDecoder(WebPDecBuffer* output_buffer); 
			
			//This function allocates and initializes an incremental-decoder object, which
			//will output the RGB/A samples specified by 'csp' into a preallocated
			//buffer 'output_buffer'. The size of this buffer is at least
			//'output_buffer_size' and the stride (distance in bytes between two scanlines)
			//is specified by 'output_stride'.
			//Additionally, output_buffer can be passed NULL in which case the output
			//buffer will be allocated automatically when the decoding starts. The
			//colorspace 'csp' is taken into account for allocating this buffer. All other
			//parameters are ignored.
			//Returns NULL if the allocation failed, or if some parameters are invalid.
			WebPIDecoder* WebPINewRGB(
				WEBP_CSP_MODE csp,
				ubyte* output_buffer, size_t output_buffer_size, 
				int output_stride
			); 
			
			//This function allocates and initializes an incremental-decoder object, which
			//will output the raw luma/chroma samples into a preallocated planes if
			//supplied. The luma plane is specified by its pointer 'luma', its size
			//'luma_size' and its stride 'luma_stride'. Similarly, the chroma-u plane
			//is specified by the 'u', 'u_size' and 'u_stride' parameters, and the chroma-v
			//plane by 'v' and 'v_size'. And same for the alpha-plane. The 'a' pointer
			//can be pass NULL in case one is not interested in the transparency plane.
			//Conversely, 'luma' can be passed NULL if no preallocated planes are supplied.
			//In this case, the output buffer will be automatically allocated (using
			//MODE_YUVA) when decoding starts. All parameters are then ignored.
			
			//Returns NULL if the allocation failed or if a parameter is invalid.
			WebPIDecoder* WebPINewYUVA(
				ubyte* luma, size_t luma_size, int luma_stride,
				ubyte* u, size_t u_size, int u_stride,
				ubyte* v, size_t v_size, int v_stride,
				ubyte* a, size_t a_size, int a_stride
			); 
			
			//Deprecated version of the above, without the alpha plane.
			//Kept for backward compatibility.
			WebPIDecoder* WebPINewYUV(
				ubyte* luma, size_t luma_size, int luma_stride,
				ubyte* u, size_t u_size, int u_stride,
				ubyte* v, size_t v_size, int v_stride
			); 
			
			//Deletes the WebPIDecoder object and associated memory. Must always be called
			//if WebPINewDecoder, WebPINewRGB or WebPINewYUV succeeded.
			void WebPIDelete(WebPIDecoder* idec); 
			
			//Copies and decodes the next available data. Returns VP8_STATUS_OK when
			//the image is successfully decoded. Returns VP8_STATUS_SUSPENDED when more
			//data is expected. Returns error in other cases.
			VP8StatusCode WebPIAppend(WebPIDecoder* idec, in ubyte* data, size_t data_size); 
			
			//A variant of the above function to be used when data buffer contains
			//partial data from the beginning. In this case data buffer is not copied
			//to the internal memory.
			//Note that the value of the 'data' pointer can change between calls to
			//WebPIUpdate, for instance when the data buffer is resized to fit larger data.
			VP8StatusCode WebPIUpdate(WebPIDecoder* idec, in ubyte* data, size_t data_size); 
			
			//Returns the RGB/A image decoded so far. Returns NULL if output params
			//are not initialized yet. The RGB/A output type corresponds to the colorspace
			//specified during call to WebPINewDecoder() or WebPINewRGB().
			//*last_y is the index of last decoded row in raster scan order. Some pointers
			//(*last_y, *width etc.) can be NULL if corresponding information is not
			//needed.
			ubyte* WebPIDecGetRGB(
				in WebPIDecoder* idec, int* last_y,
				int* width, int* height, int* stride
			); 
			
			//Same as above function to get a YUVA image. Returns pointer to the luma
			//plane or NULL in case of error. If there is no alpha information
			//the alpha pointer '*a' will be returned NULL.
			ubyte* WebPIDecGetYUVA(
				in WebPIDecoder* idec, int* last_y,
				ubyte** u, ubyte** v, ubyte** a,
				int* width, int* height, int* stride, int* uv_stride, int* a_stride
			); 
			
			//Deprecated alpha-less version of WebPIDecGetYUVA(): it will ignore the
			//alpha information (if present). Kept for backward compatibility.
			static ubyte* WebPIDecGetYUV(
				in WebPIDecoder* idec, int* last_y, ubyte** u, ubyte** v,
				int* width, int* height, int* stride, int* uv_stride
			)
			{
				return WebPIDecGetYUVA(
					idec, last_y, u, v, null, width, height,
											 stride, uv_stride, null
				); 
			} 
			
			//Generic call to retrieve information about the displayable area.
			//If non NULL, the left/right/width/height pointers are filled with the visible
			//rectangular area so far.
			//Returns NULL in case the incremental decoder object is in an invalid state.
			//Otherwise returns the pointer to the internal representation. This structure
			//is read-only, tied to WebPIDecoder's lifespan and should not be modified.
			
			//Todo: Review. I don't know, is this correct.
			//WEBP_EXTERN(const WebPDecBuffer*) WebPIDecodedArea(
			//const WebPIDecoder* idec, int* left, int* top, int* width, int* height);
			WebPDecBuffer* WebPIDecodedArea(in WebPIDecoder* idec, int* left, int* top, int* width, int* height); 
			
			//------------------------------------------------------------------------------
			//Advanced decoding parametrization
			//
			//Code sample for using the advanced decoding API
			/*
				 // A) Init a configuration object
				 WebPDecoderConfig config;
				 CHECK(WebPInitDecoderConfig(&config));
				
				 // B) optional: retrieve the bitstream's features.
				 CHECK(WebPGetFeatures(data, data_size, &config.input) == VP8_STATUS_OK);
				
				 // C) Adjust 'config', if needed
				 config.no_fancy_upsampling = 1;
				 config.output.colorspace = MODE_BGRA;
				 // etc.
				
				 // Note that you can also make config.output point to an externally
				 // supplied memory buffer, provided it's big enough to store the decoded
				 // picture. Otherwise, config.output will just be used to allocate memory
				 // and store the decoded picture.
				
				 // D) Decode!
				 CHECK(WebPDecode(data, data_size, &config) == VP8_STATUS_OK);
				
				 // E) Decoded image is now in config.output (and config.output.u.RGBA)
				
				 // F) Reclaim memory allocated in config's object. It's safe to call
				 // this function even if the memory is external and wasn't allocated
				 // by WebPDecode().
				 WebPFreeDecBuffer(&config.output);
			*/
			
			//Features gathered from the bitstream
			struct WebPBitstreamFeatures
			{
				int width; 	 //Width in pixels, as read from the bitstream.
				int height; 	 //Height in pixels, as read from the bitstream.
				int has_alpha; 	 //True if the bitstream contains an alpha channel.
				int has_animation; 	 //True if the bitstream is an animation.
				int format; 	 //0 = undefined (/mixed), 1 = lossy, 2 = lossless
				
				//Unused for now:
				int no_incremental_decoding; 	 //if true, using incremental decoding is not
				 //recommended.
				int rotate; 	 //TODO(later)
				int uv_sampling; 	 //should be 0 for now. TODO(later)
				uint[2] pad;              //padding for later use
			} ; 
			
			//Internal, version-checked, entry point
			VP8StatusCode WebPGetFeaturesInternal(const ubyte*, size_t, WebPBitstreamFeatures*, int); 
			
			//Retrieve features from the bitstream. The *features structure is filled
			//with information gathered from the bitstream.
			//Returns VP8_STATUS_OK when the features are successfully retrieved. Returns
			//VP8_STATUS_NOT_ENOUGH_DATA when more data is needed to retrieve the
			//features from headers. Returns error in other cases.
			static VP8StatusCode WebPGetFeatures(
				in ubyte* data, size_t data_size,
				WebPBitstreamFeatures* features
			)
			{
				return WebPGetFeaturesInternal(
					data, data_size, features,
					WEBP_DECODER_ABI_VERSION
				); 
			} 
			
			//Decoding options
			struct WebPDecoderOptions
			{
				int bypass_filtering; 	   //if true, skip the in-loop filtering
				int no_fancy_upsampling; 	   //if true, use faster pointwise upsampler
				int use_cropping; 	   //if true, cropping is applied _first_
				int crop_left, crop_top; 	   //top-left position for cropping.
				   //Will be snapped to even values.
				int crop_width, crop_height; 	   //dimension of the cropping area
				int use_scaling; 	   //if true, scaling is applied _afterward_
				int scaled_width, scaled_height; 	   //final resolution
				int use_threads; 	   //if true, use multi-threaded decoding
				int dithering_strength; 	   //dithering strength (0=Off, 100=full)
				
				//Unused for now:
				int force_rotation; 											      //forced rotation (to be applied _last_)
				int no_enhancement; 											      //if true, discard enhancement layer
				uint[4] pad;                        //padding for later use
			} 
			
			//Main object storing the configuration for advanced decoding.
			struct WebPDecoderConfig
			{
				WebPBitstreamFeatures input; 	 //Immutable bitstream features (optional)
				WebPDecBuffer output; 	 //Output buffer (can point to external mem)
				WebPDecoderOptions options; 	 //Decoding options
			} ; 
			
			//Internal, version-checked, entry point
			int WebPInitDecoderConfigInternal(WebPDecoderConfig*, int); 
			
			//Initialize the configuration as empty. This function must always be
			//called first, unless WebPGetFeatures() is to be called.
			//Returns false in case of mismatched version.
			static int WebPInitDecoderConfig(WebPDecoderConfig* config)
			{ return WebPInitDecoderConfigInternal(config, WEBP_DECODER_ABI_VERSION); } 
			
			//Instantiate a new incremental decoder object with the requested
			//configuration. The bitstream can be passed using 'data' and 'data_size'
			//parameter, in which case the features will be parsed and stored into
			//config->input. Otherwise, 'data' can be NULL and no parsing will occur.
			//Note that 'config' can be NULL too, in which case a default configuration
			//is used.
			//The return WebPIDecoder object must always be deleted calling WebPIDelete().
			//Returns NULL in case of error (and config->status will then reflect
			//the error condition).
			WebPIDecoder* WebPIDecode(
				in ubyte* data, size_t data_size,
				WebPDecoderConfig* config
			); 
			
			//Non-incremental version. This version decodes the full data at once, taking
			//'config' into account. Returns decoding status (which should be VP8_STATUS_OK
			//if the decoding was successful).
			VP8StatusCode WebPDecode(
				in ubyte* data, size_t data_size,
				WebPDecoderConfig* config
			); 
			
		} 
	}
} 
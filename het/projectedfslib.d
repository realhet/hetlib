module het.projectedfslib; 

import het; 

import core.sys.windows.windows :
	HRESULT_FROM_WIN32, S_OK, E_OUTOFMEMORY, 	ERROR_IO_PENDING, ERROR_INSUFFICIENT_BUFFER, 
	ERROR_FILE_NOT_FOUND, ERROR_INVALID_PARAMETER, ERROR_ACCESS_DENIED; 

enum HR_OK	= S_OK,
HR_OUTOFMEMORY	= E_OUTOFMEMORY,
HR_IO_PENDING	= HRESULT_FROM_WIN32(ERROR_IO_PENDING),
HR_INSUFFICIENT_BUFFER 	= HRESULT_FROM_WIN32(ERROR_INSUFFICIENT_BUFFER),
HR_FILE_NOT_FOUND	= HRESULT_FROM_WIN32(ERROR_FILE_NOT_FOUND),
HR_INVALID_PARAMETER	= HRESULT_FROM_WIN32(ERROR_INVALID_PARAMETER),
HR_ACCESS_DENIED	= HRESULT_FROM_WIN32(ERROR_ACCESS_DENIED); 

private alias PCWSTR = const wchar*, LPCWSTR = const wchar*, 
INT32 = int, UINT32 = uint, UINT8 = ubyte, BOOLEAN = bool, 
INT64 = long, LARGE_INTEGER = long; 


private
{
	class Loader
	{
		HANDLE lib; 
		bool success; 
		this()
		{
			lib = loadLibrary("projectedfslib.dll", false); 
			if(lib)
			{
				static foreach(name; __traits(allMembers, mixin(__MODULE__)))
				{
					{
						alias member = __traits(getMember, mixin(__MODULE__), name); 
						static if(__traits(compiles, typeof(member)))
						static if(typeof(member).stringof.startsWith("extern"))
						lib.getProcAddress(name, member, true); 
					}
				}
				success = true; 
			}
		} 
	} 
	
	alias loader = Singleton!Loader; 
} 

bool PrjInit(bool required=false)
{ auto res = loader.success; if(required) res.enforce("Unable to load projectedfslib.dll."); return res; } 

version(/+$DIDE_REGION Common structures+/all)
{
	enum PRJ_NOTIFY_
	{
		NONE	= 0x00000000,
		SUPPRESS_NOTIFICATIONS	= 0x00000001,
		FILE_OPENED	= 0x00000002,
		NEW_FILE_CREATED	= 0x00000004,
		FILE_OVERWRITTEN	= 0x00000008,
		PRE_DELETE	= 0x00000010,
		PRE_RENAME	= 0x00000020,
		PRE_SET_HARDLINK	= 0x00000040,
		FILE_RENAMED	= 0x00000080,
		HARDLINK_CREATED	= 0x00000100,
		FILE_HANDLE_CLOSED_NO_MODIFICATION 	= 0x00000200,
		FILE_HANDLE_CLOSED_FILE_MODIFIED	= 0x00000400,
		FILE_HANDLE_CLOSED_FILE_DELETED	= 0x00000800,
		FILE_PRE_CONVERT_TO_FULL	= 0x00001000,
		USE_EXISTING_MASK	= 0xFFFFFFFF
	} 
	alias PRJ_NOTIFY_TYPES = BitFlags!(PRJ_NOTIFY_, Yes.unsafe); 
	
	//DEFINE_ENUM_FLAG_OPERATORS(PRJ_NOTIFY_TYPES); 
	
	// This enum shares the same value space as PRJ_NOTIFY_TYPES, but
	// these values are not bit flags.
	enum PRJ_NOTIFICATION_
	{
		FILE_OPENED	= 0x00000002,
		NEW_FILE_CREATED	= 0x00000004,
		FILE_OVERWRITTEN	= 0x00000008,
		PRE_DELETE	= 0x00000010,
		PRE_RENAME	= 0x00000020,
		PRE_SET_HARDLINK	= 0x00000040,
		FILE_RENAMED	= 0x00000080,
		HARDLINK_CREATED	= 0x00000100,
		FILE_HANDLE_CLOSED_NO_MODIFICATION 	= 0x00000200,
		FILE_HANDLE_CLOSED_FILE_MODIFIED	= 0x00000400,
		FILE_HANDLE_CLOSED_FILE_DELETED	= 0x00000800,
		FILE_PRE_CONVERT_TO_FULL	= 0x00001000,
	} 
	alias PRJ_NOTIFICATION = BitFlags!PRJ_NOTIFICATION_; 
	
	alias PRJ_NAMESPACE_VIRTUALIZATION_CONTEXT = HANDLE; 
	alias PRJ_DIR_ENTRY_BUFFER_HANDLE = HANDLE; 
}

version(/+$DIDE_REGION Virtualization instance APIs+/all)
{
	struct PRJ_NOTIFICATION_MAPPING
	{
		PRJ_NOTIFY_TYPES NotificationBitMask; 
		PCWSTR NotificationRoot; 
	} 
	
	enum PRJ_FLAG_
	{
		NONE	= 0x00000000,
		USE_NEGATIVE_PATH_CACHE 	= 0x00000001
	} 
	alias PRJ_STARTVIRTUALIZING_FLAGS = BitFlags!PRJ_FLAG_; 
	
	struct PRJ_STARTVIRTUALIZING_OPTIONS
	{
		PRJ_STARTVIRTUALIZING_FLAGS Flags; 
		UINT32 PoolThreadCount; 
		UINT32 ConcurrentThreadCount; 
		PRJ_NOTIFICATION_MAPPING* NotificationMappings; 
		UINT32 NotificationMappingsCount; 
	} 
	
	__gshared extern(Windows) HRESULT function
		(
		const PCWSTR virtualizationRootPath,
		const PRJ_CALLBACKS* callbacks,
		const void* instanceContext,
		const PRJ_STARTVIRTUALIZING_OPTIONS* options,
		out PRJ_NAMESPACE_VIRTUALIZATION_CONTEXT  namespaceVirtualizationContext
	) PrjStartVirtualizing; 
	
	__gshared extern(Windows) void function
		(const PRJ_NAMESPACE_VIRTUALIZATION_CONTEXT namespaceVirtualizationContext) PrjStopVirtualizing; 
	
	__gshared extern(Windows) HRESULT function
		(
		const PRJ_NAMESPACE_VIRTUALIZATION_CONTEXT namespaceVirtualizationContext,
		out UINT32 totalEntryNumber
	) PrjClearNegativePathCache; 
	
	struct PRJ_VIRTUALIZATION_INSTANCE_INFO
	{
		GUID InstanceID; 
		UINT32 WriteAlignment; 
	} 
	
	__gshared extern(Windows) HRESULT function
		(
		const PRJ_NAMESPACE_VIRTUALIZATION_CONTEXT namespaceVirtualizationContext,
		out PRJ_VIRTUALIZATION_INSTANCE_INFO virtualizationInstanceInfo
	) PrjGetVirtualizationInstanceInfo; 
}

version(/+$DIDE_REGION Placeholder and File APIs+/all)
{
	enum PRJ_PLACEHOLDER_ID_LENGTH = 128; 
	
	struct PRJ_PLACEHOLDER_VERSION_INFO
	{
		UINT8[PRJ_PLACEHOLDER_ID_LENGTH] ProviderID; 
		UINT8[PRJ_PLACEHOLDER_ID_LENGTH] ContentID; 
	} 
	
	__gshared extern(Windows) HRESULT function
		(
		const PCWSTR rootPathName,
		const PCWSTR targetPathName,
		const PRJ_PLACEHOLDER_VERSION_INFO* versionInfo,
		const GUID* virtualizationInstanceID
	) PrjMarkDirectoryAsPlaceholder; 
	
	struct PRJ_FILE_BASIC_INFO
	{
		BOOLEAN IsDirectory; 
		INT64 FileSize; 
		LARGE_INTEGER CreationTime; 
		LARGE_INTEGER LastAccessTime; 
		LARGE_INTEGER LastWriteTime; 
		LARGE_INTEGER ChangeTime; 
		UINT32 FileAttributes; 
	} 
	
	struct PRJ_PLACEHOLDER_INFO
	{
		PRJ_FILE_BASIC_INFO FileBasicInfo; 
		
		struct TEaInformation
		{
			UINT32 EaBufferSize; 
			UINT32 OffsetToFirstEa; 
		} TEaInformation EaInformation; 
		
		struct TSecurityInformation
		{
			UINT32 SecurityBufferSize; 
			UINT32 OffsetToSecurityDescriptor; 
		} TSecurityInformation SecurityInformation; 
		
		struct TStreamsInformation
		{
			UINT32 StreamsInfoBufferSize; 
			UINT32 OffsetToFirstStreamInfo; 
		} TStreamsInformation StreamsInformation; 
		
		PRJ_PLACEHOLDER_VERSION_INFO VersionInfo; 
		UINT8[1] VariableData; 
	} 
	
	__gshared extern(Windows) HRESULT function
		(
		const PRJ_NAMESPACE_VIRTUALIZATION_CONTEXT namespaceVirtualizationContext,
		const PCWSTR destinationFileName,
		const PRJ_PLACEHOLDER_INFO* placeholderInfo,
		const UINT32 placeholderInfoSize
	) PrjWritePlaceholderInfo; 
	
	enum PRJ_UPDATE_
	{
		NONE	= 0x00000000,
		ALLOW_DIRTY_METADATA	= 0x00000001,
		ALLOW_DIRTY_DATA	= 0x00000002,
		ALLOW_TOMBSTONE	= 0x00000004,
		RESERVED1	= 0x00000008,
		RESERVED2	= 0x00000010,
		ALLOW_READ_ONLY	= 0x00000020,
		MAX_VAL = (ALLOW_READ_ONLY << 1)
	} 
	alias PRJ_UPDATE_TYPES = BitFlags!PRJ_UPDATE_; 
	
	enum PRJ_UPDATE_FAILURE_CAUSE_
	{
		NONE	= 0x00000000,
		DIRTY_METADATA	= 0x00000001,
		DIRTY_DATA	= 0x00000002,
		TOMBSTONE	= 0x00000004,
		READ_ONLY	= 0x00000008,
	} 
	alias PRJ_UPDATE_FAILURE_CAUSES = BitFlags!PRJ_UPDATE_FAILURE_CAUSE_; 
	
	__gshared extern(Windows) HRESULT function
		(
		const PRJ_NAMESPACE_VIRTUALIZATION_CONTEXT namespaceVirtualizationContext,
		const PCWSTR destinationFileName,
		const PRJ_PLACEHOLDER_INFO* placeholderInfo,
		const UINT32 placeholderInfoSize,
		const PRJ_UPDATE_TYPES updateFlags,
		out PRJ_UPDATE_FAILURE_CAUSES failureReason
	) PrjUpdateFileIfNeeded; 
	
	__gshared extern(Windows) HRESULT function
		(
		const PRJ_NAMESPACE_VIRTUALIZATION_CONTEXT namespaceVirtualizationContext,
		const PCWSTR destinationFileName,
		const PRJ_UPDATE_TYPES updateFlags,
		out PRJ_UPDATE_FAILURE_CAUSES failureReason
	) PrjDeleteFile; 
	
	__gshared extern(Windows) HRESULT function
		(
		const PRJ_NAMESPACE_VIRTUALIZATION_CONTEXT namespaceVirtualizationContext,
		const GUID* dataStreamId,
		const void* buffer,
		const UINT64 byteOffset,
		const UINT32 length
	) PrjWriteFileData; 
	
	enum PRJ_FILE_STATE_
	{
		PLACEHOLDER	= 0x00000001,
		HYDRATED_PLACEHOLDER 	= 0x00000002,
		DIRTY_PLACEHOLDER	= 0x00000004,
		FULL	= 0x00000008,
		TOMBSTONE	= 0x00000010,
	} 
	alias PRJ_FILE_STATE = BitFlags!PRJ_FILE_STATE_; 
	
	__gshared extern(Windows) HRESULT function
		(
		const PCWSTR destinationFileName,
		out PRJ_FILE_STATE fileState
	) PrjGetOnDiskFileState; 
	
	__gshared extern(Windows) void* function
		(
		const PRJ_NAMESPACE_VIRTUALIZATION_CONTEXT namespaceVirtualizationContext,
		const size_t size
	) PrjAllocateAlignedBuffer; 
	
	__gshared extern(Windows) void function
		(const void* buffer) PrjFreeAlignedBuffer; 
}

version(/+$DIDE_REGION Callback support+/all)
{
	enum PRJ_CB_DATA_FLAG_
	{
		ENUM_RESTART_SCAN	= 0x00000001,
		ENUM_RETURN_SINGLE_ENTRY 	= 0x00000002
	} 
	alias PRJ_CALLBACK_DATA_FLAGS = BitFlags!PRJ_CB_DATA_FLAG_; 
	
	struct PRJ_CALLBACK_DATA
	{
		UINT32 Size; 
		PRJ_CALLBACK_DATA_FLAGS Flags; 
		PRJ_NAMESPACE_VIRTUALIZATION_CONTEXT NamespaceVirtualizationContext; 
		INT32 CommandId; 
		GUID FileId; 
		GUID DataStreamId; 
		PCWSTR FilePathName; 
		PRJ_PLACEHOLDER_VERSION_INFO* VersionInfo; 
		UINT32 TriggeringProcessId; 
		PCWSTR TriggeringProcessImageFileName; 
		void* InstanceContext; 
	} 
	
	alias PRJ_START_DIRECTORY_ENUMERATION_CB = extern(Windows) HRESULT function
		(
		const PRJ_CALLBACK_DATA* callbackData,
		const GUID* enumerationId
	); 
	
	alias PRJ_GET_DIRECTORY_ENUMERATION_CB = extern(Windows) HRESULT function
		(
		const PRJ_CALLBACK_DATA* callbackData,
		const GUID* enumerationId,
		const PCWSTR searchExpression,
		const PRJ_DIR_ENTRY_BUFFER_HANDLE dirEntryBufferHandle
	); 
	
	alias PRJ_END_DIRECTORY_ENUMERATION_CB = extern(Windows) HRESULT function
		(
		const PRJ_CALLBACK_DATA* callbackData,
		const GUID* enumerationId
	); 
	
	alias PRJ_GET_PLACEHOLDER_INFO_CB = extern(Windows) HRESULT function
		(const PRJ_CALLBACK_DATA* callbackData); 
	
	alias PRJ_GET_FILE_DATA_CB = extern(Windows) HRESULT function
		(
		const PRJ_CALLBACK_DATA* callbackData,
		const UINT64 byteOffset,
		const UINT32 length
	); 
	
	alias PRJ_QUERY_FILE_NAME_CB = extern(Windows) HRESULT function
		(const PRJ_CALLBACK_DATA* callbackData); 
	
	union PRJ_NOTIFICATION_PARAMETERS
	{
		struct TPostCreate { PRJ_NOTIFY_TYPES NotificationMask; } 
		TPostCreate PostCreate; 
		
		struct TFileRenamed { PRJ_NOTIFY_TYPES NotificationMask; } 
		TFileRenamed FileRenamed; 
		
		struct TFileDeletedOnHandleClose { BOOLEAN IsFileModified; } 
		TFileDeletedOnHandleClose FileDeletedOnHandleClose; 
	} 
	
	alias PRJ_NOTIFICATION_CB = extern(Windows) HRESULT function
		(
		const PRJ_CALLBACK_DATA* callbackData,
		const BOOLEAN isDirectory,
		const PRJ_NOTIFICATION notification,
		const PCWSTR destinationFileName,
		PRJ_NOTIFICATION_PARAMETERS* operationParameters
	); 
	
	alias PRJ_CANCEL_COMMAND_CB = extern(Windows) void function
	(const PRJ_CALLBACK_DATA* callbackData); 
	
	struct PRJ_CALLBACKS 
	{
		PRJ_START_DIRECTORY_ENUMERATION_CB StartDirectoryEnumerationCallback; 
		PRJ_END_DIRECTORY_ENUMERATION_CB EndDirectoryEnumerationCallback; 
		PRJ_GET_DIRECTORY_ENUMERATION_CB GetDirectoryEnumerationCallback; 
		PRJ_GET_PLACEHOLDER_INFO_CB GetPlaceholderInfoCallback; 
		PRJ_GET_FILE_DATA_CB GetFileDataCallback; 
		
		PRJ_QUERY_FILE_NAME_CB QueryFileNameCallback; 
		PRJ_NOTIFICATION_CB NotificationCallback; 
		PRJ_CANCEL_COMMAND_CB CancelCommandCallback; 
	} 
	
	enum PRJ_COMPLETE_COMMAND_TYPE_
	{
		NOTIFICATION = 1,
		ENUMERATION = 2
	} 
	
	struct PRJ_COMPLETE_COMMAND_EXTENDED_PARAMETERS
	{
		PRJ_COMPLETE_COMMAND_TYPE_ CommandType; 
		
		union  {
			struct TNotification { PRJ_NOTIFY_TYPES NotificationMask; } 
			TNotification Notification; 
			
			struct TEnumeration { PRJ_DIR_ENTRY_BUFFER_HANDLE DirEntryBufferHandle; } 
			TEnumeration Enumeration; 
		} 
	} 
	
	__gshared extern(Windows) HRESULT function
		(
		const PRJ_NAMESPACE_VIRTUALIZATION_CONTEXT namespaceVirtualizationContext,
		const INT32 commandId,
		const HRESULT completionResult,
		const PRJ_COMPLETE_COMMAND_EXTENDED_PARAMETERS* extendedParameters
	) PrjCompleteCommand; 
}

version(/+$DIDE_REGION Enumeration APIs+/all)
{
	__gshared extern(Windows) HRESULT function
		(
		const PCWSTR fileName,
		const PRJ_FILE_BASIC_INFO* fileBasicInfo,
		const PRJ_DIR_ENTRY_BUFFER_HANDLE dirEntryBufferHandle
	)PrjFillDirEntryBuffer; 
	
	__gshared extern(Windows) BOOLEAN function
		(
		const PCWSTR fileNameToCheck,
		const PCWSTR pattern
	)PrjFileNameMatch; 
	
	__gshared extern(Windows) int function
		(
		const PCWSTR fileName1,
		const PCWSTR fileName2
	)PrjFileNameCompare; 
	
	__gshared extern(Windows) BOOLEAN function
		(const LPCWSTR fileName)PrjDoesNameContainWildCards; 
}
version(/+$DIDE_REGION Example usage+/all)
{
	
	version(/+$DIDE_REGION+/none)
	{
		class DynamicFileProvider/+It's the example based on MS docs.+/
		{
			const Path rootPath; 
			
			GUID instanceId; 
			PRJ_NAMESPACE_VIRTUALIZATION_CONTEXT context; 
			
			protected
			{
				struct EnumEntry
				{
					string Name; 
					size_t FileSize; 
					bool IsDirectory; 
				} 
				
				struct EnumSession
				{
					GUID EnumerationId; 
					EnumEntry[] Entries; 
					int index; 
					wstring SearchExpression; 
					bool SearchExpressionCaptured; 
				} 
				
				EnumSession[GUID] enumSessions; 
				
				auto getEnumSession(in GUID Id)
				{
					synchronized(this)
					{ return &enumSessions.require(Id, EnumSession(Id)); } 
				} 
				
				void removeEnumSession(GUID Id)
				{
					synchronized(this)
					{ enumSessions.remove(Id); } 
				} 
				
				
				protected static extern(Windows)
				{
					HRESULT MyStartEnumCallback
						(
						const PRJ_CALLBACK_DATA* callbackData,
						const GUID* enumerationId
					) 
					{
						with((cast(DynamicFileProvider)(callbackData.InstanceContext)))
						{
							auto session = getEnumSession(*enumerationId); /+just allocate+/
							
							static if((常!(bool)(0))/+give it some files for testing+/)
							{
								const path = Path(`c:\docs`); 
								session.Entries = chain(
									path.files.map!((f)=>(EnumEntry(f.name, f.size))), 
									path.paths.map!((p)=>(EnumEntry(p.name, 0, true)))
								).array
									.sort!((a,b)=>(
									PrjFileNameCompare(a.Name.toUTF16z, b.Name.toUTF16z)<0
									/+Opt: original method is perfect, but a bit slow because of conversions...+/
								)).array; 
							}
							
							return S_OK; 
						}
					} 
					
					HRESULT MyGetEnumCallback
						(
						const PRJ_CALLBACK_DATA* callbackData,
						const GUID* enumerationId,
						const PCWSTR searchExpression,
						const PRJ_DIR_ENTRY_BUFFER_HANDLE dirEntryBufferHandle
					) 
					{
						with((cast(DynamicFileProvider)(callbackData.InstanceContext)))
						{
							auto session = getEnumSession(*enumerationId); 
							
							if(callbackData.Flags & PRJ_CB_DATA_FLAG_.ENUM_RESTART_SCAN)
							{
								session.index = 0; 
								session.SearchExpressionCaptured = false; 
							}
							
							if(session.SearchExpressionCaptured.chkSet)
							{ session.SearchExpression = ((searchExpression)?(searchExpression.to!wstring~'\0'):("")); }
							
							while(session.index < session.Entries.length)
							{
								auto entry = &session.Entries[session.index++]; 
								PCWSTR name = entry.Name.toUTF16z; 
								if(session.SearchExpression.length)
								if(!PrjFileNameMatch(name, session.SearchExpression.ptr)) continue; 
								auto basicInfo = mixin(體!((PRJ_FILE_BASIC_INFO),q{
									IsDirectory 	: entry.IsDirectory,
									FileSize	: entry.FileSize
								})); 
								auto hr = PrjFillDirEntryBuffer(name, &basicInfo, dirEntryBufferHandle); 
								
								if(hr == S_OK)	continue; 
								else if(hr == HR_INSUFFICIENT_BUFFER)	break; 
								else	{ ERR(hr, name.text.quoted); return hr; }
							}
							
							return S_OK; 
						}
					} 
					
					HRESULT MyEndEnumCallback
						(
						const PRJ_CALLBACK_DATA* callbackData,
						const GUID* enumerationId
					) 
					{
						with((cast(DynamicFileProvider)(callbackData.InstanceContext)))
						{
							removeEnumSession(*enumerationId); 
							return S_OK; 
						}
					} 
					
					
					
					HRESULT MyGetPlaceholderInfoCallback
						(const PRJ_CALLBACK_DATA* callbackData) 
					{
						LOG(callbackData.FilePathName.text); 
						return HR_ACCESS_DENIED; 
					} 
					
					HRESULT MyGetFileDataCallback
						(
						const PRJ_CALLBACK_DATA* callbackData,
						const UINT64 byteOffset,
						const UINT32 length
					) 
					{ return HR_ACCESS_DENIED; } 
					
					HRESULT MyQueryFileNameCallback
						(const PRJ_CALLBACK_DATA* callbackData)
					{
						LOG(callbackData.FilePathName.text); 
						return S_OK; 
					} 
				} 
			} 
			this(Path rootPath_)
			{
				PrjInit(true); 
				
				version(/+$DIDE_REGION Create virtualization root+/all)
				{
					version(/+$DIDE_REGION 1. Create a directory to serve as the virtualization root.+/all)
					{
						rootPath = rootPath_; 
						enforce(rootPath, "Root path can't be null."); 
						enforce(!rootPath.exists, "Root path can't be an existing path.  It will be wiped after exit."); 
						rootPath.make(true); 
					}
					
					version(/+$DIDE_REGION 2. Create a virtualization instance ID.+/all)
					{ hrChk!CoCreateGuid(&instanceId); }
					
					version(/+$DIDE_REGION 3. Mark the new directory as the virtualization root+/all)
					{
						hrChk!PrjMarkDirectoryAsPlaceholder(
							rootPath.fullPath.toUTF16z, 
							null, null, &instanceId
						); 
					}
				}
				
				version(/+$DIDE_REGION Start virtualization instance+/all)
				{
					version(/+$DIDE_REGION 1. Set up the callback table.+/all)
					{
						auto callbackTable = 
						mixin(體!((PRJ_CALLBACKS),q{
							// Supply required callbacks.
							StartDirectoryEnumerationCallback 	: &MyStartEnumCallback,
							GetDirectoryEnumerationCallback	: &MyGetEnumCallback,
							EndDirectoryEnumerationCallback	: &MyEndEnumCallback,
							GetPlaceholderInfoCallback	: &MyGetPlaceholderInfoCallback,
							GetFileDataCallback	: &MyGetFileDataCallback,
							
							// The rest of the callbacks are optional.
							QueryFileNameCallback	: null,
							NotificationCallback	: null,
							CancelCommandCallback 	: null,
						})); 
					}
					
					version(/+$DIDE_REGION 2. Start the instance.+/all)
					{
						PrjStartVirtualizing(
							rootPath.fullPath.toUTF16z,
							&callbackTable, (cast(void*)(this)), null, context
						); 
					}
				}
			} 
			
			//Link: file:///C:/dl/windows-win32-projfs.pdf
			
			~this()
			{
				version(/+$DIDE_REGION Shutting down virtualization instance+/all)
				{
					PrjStopVirtualizing(context); context = null; 
					rootPath.wipe(false); 
				}
			} 
			
		} 
	}
}
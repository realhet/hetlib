module het.ai; 

import het; 

class AiChat
{
	mixin SmartChild!(q{@PARENT AiModel model}); 
	import std.json; 
	import std.net.curl : HTTP; 
	
	enum roleSystem 	= "system"	,
	roleUser 	= "user"	,
	roleAssistant 	= "assistant"	; 
	
	struct Message
	{
		string role/+system, user, assistant+/; 
		string content; 
	} 
	
	struct Query
	{
		Message[] messages; 
		string model; 
		float temperature = 1.0; 
		bool stream; 
		
		File cacheFile; 
		ulong cacheHash; 
	} 
	
	protected
	{
		Query query; 
		string apiUrl, apiKey; 
		SSQueue!string msgQueue; 	
		int incomingMessageIdx; 
		bool workerPending; 
		string buffer; 
	} 
	
	void _construct()
	{}  void _destruct()
	{ stop; } 
	
	
	@property
	{
		bool running() const
		=> workerPending; 
		bool firstMessageIsSystem() const
		=> query.messages.length
		&& query.messages[0].role==roleSystem; 
		const messages()
		=> query.messages; 
	} 
	
	
	enum Event { text, error, warning, done } 
	
	void printEvent(Event event, string s)
	{
		final switch(event)
		{
			case Event.text: 	write(s); 	break; 
			case Event.error: 	print(EgaColor.ltRed("\nError: "~s)); 	break; 
			case Event.warning: 	print(EgaColor.yellow("\nWarning: "~s)); 	break; 
			case Event.done: 	print(EgaColor.ltGreen("\nDone: "~s)); 	break; 
		}
	} 
	
	static private void worker(shared AiChat _chat)
	{
		/+this is where the blocking CURL HTTP client runs.+/
		auto chat = cast()_chat; 
		if(!chat || !chat.incomingMessageIdx) return; 
		
		scope(exit) chat.workerPending = false/+This is the idle state+/; 
		
		//prepare data
		auto 	header 	= [
			"Content-Type"	: "application/json",
			"Authorization"	: "Bearer "~tea_dec(chat.apiKey, "apiKey")
		],
			msg 	= chat.query.toJson(true); 
		string[string] responseHeader; 
		
		//prepare curl
		auto http = HTTP(); 
		foreach(k, v; header) http.addRequestHeader(k, v); 
		http.method 	= HTTP.Method.post,
		http.url 	= chat.apiUrl,
		http.onSend 	= ((void[] data) {
			auto m = cast(void[]) msg; 
			size_t length = m.length > data.length ? data.length : m.length; 
			if(length == 0) return 0; 
			data[0 .. length] = m[0 .. length]; 
			msg = msg[length..$]; 
			return length; 
		}),
		http.onReceiveHeader 	= ((in char[] key, in char[] value) { responseHeader[key.idup] = value.idup; }),
		http.onReceive 	= ((ubyte[] data) {
			if(!chat.workerPending)
			{
				enum CURL_READFUNC_ABORT = 0x10000000; 
				return CURL_READFUNC_ABORT; 
			}
			
			chat.msgQueue.put((cast(string)(data.idup))); 
			return data.length; 
		}); 
		
		http.perform(No.throwOnError); 
		
		if(!mixin(界3(q{200},q{http.statusLine.code},q{299})))
		{ chat.msgQueue.put(i"\nerror: $(http.statusLine.code) $(http.statusLine.reason)\n\n".text); }
	} 
	struct StreamDataEvent
	{
		//string id; //a guid.
		string object; //must be "chat.completion.chunk"
		//uint created; //unix timestamp
		//string model; //""
		//string system_fingerprint; //"fp_3a5770e1b4_prod"
		
		struct Choice
		{
			//int index; // always 0
			struct MessageDelta
			{
				//string role; //"assistant"  only the first data event has this.
				string content; 
			} 
			MessageDelta delta; 
			//logprobs:null,
			string finish_reason; //stop, length, function call, content filter
		} 
		Choice[] choices; 
		
		struct Usage
		{
			int 	prompt_tokens, 
				completion_tokens; 
			struct Details
			{ int cached_tokens; } 
			Details prompt_tokens_details; 
			
			@property cached_prompt_tokens() const 
			=> prompt_tokens_details.cached_tokens; 
			@property total_tokens() const 
			=> prompt_tokens + completion_tokens; 
			
			string toString() const
			{
				const 	st 	= now.localSystemTime, 
					hour	= st.wHour + st.wMinute/60.0,
					scale 	= ((mixin(界3(q{1.5},q{hour},q{17.5})))?(1.0/+Note: normal+/):(0.5/+Note: discount+/)); 
				//Todo: model dependent prices.  this is chat only
				return i"Usage(prompt_hit: $(cached_prompt_tokens), ".text~
				i"prompt_miss: $(prompt_tokens), ".text~
				i"completion: $(completion_tokens), ".text~
				format!"HUF: %.2f, "
				(
					(
						cached_prompt_tokens	*0.07*scale+
						(prompt_tokens-cached_prompt_tokens)	*0.27*scale+
						completion_tokens	*1.10*scale
					)
					/ 1e6 * 380 /+Todo: more accurate usd to huf+/
				)~
				format!"price: %3d%%)"((scale*100).iround); 
			} 
		} 
		Usage usage; 
	} 
	
	void ask(Message[] messages, bool refreshCache=false)
	{
		if(running) return; 
		if(messages.empty) return; 
		
		//Refresh query parameters.
		apiUrl = model.apiUrl; 
		apiKey = model.apiKey; 
		query.model = model.model; 
		query.stream = true; 
		query.temperature = model.temperature; 
		query.messages = messages; 
		
		//cache logic
		const cacheEnabled = model.cached && model.cachePath; 
		query.cacheHash 	= ((cacheEnabled)?(query.messages.hashOf):(0)),
		query.cacheFile 	= ((cacheEnabled) ?(
			File(
				model.cachePath, 
				"ai_"~query.cacheHash.to!string(26)~".chat"
			)
		):(File.init)); 
		
		//Alloc reply message for "assistant" role
		incomingMessageIdx = query.messages.length.to!int; 
		query.messages ~= Message(roleAssistant, ""); 
		
		//Create safeQueue if needed
		if(!msgQueue) msgQueue = new typeof(msgQueue); 
		
		workerPending = true; buffer = ""; 
		
		bool readFromCache()
		{
			if(!refreshCache && query.cacheFile && query.cacheHash)
			{
				Message[] cachedMessages; 
				ignoreExceptions({ cachedMessages.fromJson(query.cacheFile.readStr); }); 
				if(cachedMessages.length && cachedMessages[0..$-1].hashOf==query.cacheHash)
				{
					const s = cachedMessages.back.content.toJson; 
					msgQueue.put
					(
						`data: {"choices":[{"index":0,"delta":{"content":`~s~`},"finish_reason":null}]}`~"\n\n\n"~
						`data: {"choices":[{"index":0,"delta":{"content":""},"finish_reason":"stopCached"}]}`~"\n\n\n"
					); 
					workerPending = false; 
					return true; 
				}
			}
			return false; 
		} 
		
		if(!readFromCache)
		spawn(&worker, cast(shared)this); 
	} 
	
	void ask(string[][] messages, bool refreshCache=false)
	{
		auto m = messages.map!((a)=>(Message(a.get(0), a.get(1)))).array; 
		
		foreach(a; m)
		enforce(
			a.role.among(roleUser, roleAssistant, roleSystem), 
			i"Invalid Ai role: $(a.role.quoted)".text
		); 
		
		const hasSystem = m.any!((a)=>(a.role==roleSystem)); 
		if(!hasSystem) m = Message(roleSystem, model.system) ~ m; 
		
		ask(m, refreshCache); 
	} 
	
	///this is continuing the current chat
	void ask(string prompt, bool refreshCache=false)
	{
		if(running) return; 
		if(prompt.strip=="") return; 
		
		//First message is always from the "system" role
		if(query.messages.empty) query.messages.length = 1; 
		query.messages[0] = Message(roleSystem, model.system); 
		
		//Append current message
		query.messages ~= Message(roleUser, prompt); 
		
		ask(query.messages, refreshCache); 
	} 
	
	void stop()
	{ workerPending = false; } 
	
	
	bool update(void delegate(Event, string) onEvent=null)
	{
		if(onEvent is null) onEvent = &printEvent; 
		
		bool res; 
		
		void processEvent(ref Message message, string event)
		{
			res = true/+there was a change+/; 
			
			event = event.strip; 
			
			bool TRY(string prefix, bool doStrip = true)
			{
				if(event.startsWith(prefix))
				{
					if(doStrip) event = event[prefix.length..$].strip; 
					return true; 
				}
				return false; 
			} 
			if(TRY("data: "))
			{
				if(event=="[DONE]")
				{/+redundant.  finish_reason is enough.+/}
				else if(event.startsWith('{') && event.endsWith('}'))
				{
					StreamDataEvent a; 
					a.fromJson(event, "AIStreamData", ErrorHandling.warn); 
					if(a.choices.length)
					{
						const delta = a.choices[0].delta.content; 
						if(delta!="")
						{
							message.content ~= delta; 
							onEvent(Event.text, delta); 
						}
						switch(a.choices[0].finish_reason)
						{
							case "stop": 	{
								onEvent(Event.done, a.usage.text); 
								
								if(
									query.messages.length>=2 &&
									query.cacheFile && query.cacheHash
								)
								{ query.cacheFile.write(query.messages.toJson); }
							}break; 
							case "stopCached": 	{ onEvent(Event.done, ""); }break; 
							case "length": 	{/+Todo:+/}break; 
							case "function call": 	{/+Todo:+/}break; 
							case "content filter": 	{/+Todo:+/}break; 
							default: 
						}
					}
				}
			}
			else if(TRY(`{"error":`, false))
			{ onEvent(Event.error, event/+Todo: better format these messages+/); }
			else if(TRY("error: "))
			{ onEvent(Event.error, event/+Todo: better format these messages+/); }
			else
			{ onEvent(Event.warning, event); }
		} 
		
		if(msgQueue) foreach(a; msgQueue.fetchAll) { buffer ~= a; }
		
		if(incomingMessageIdx && incomingMessageIdx.inRange(query.messages))
		{
			loop: while(1)
			{
				static foreach(separ; ["\r\n\r\n", "\n\n"])
				{
					{
						const i = buffer.byChar.indexOf(separ); 
						if(i>=0) {
							processEvent(query.messages[incomingMessageIdx], buffer[0..i]); 
							buffer = buffer[i+separ.length..$]; 
							continue loop; 
						}
					}
				}
				break loop; 
			}
		}
		
		return res /+true: messages updated.+/; 
	} 
	static class MarkdownProcessor
	{
		int backtickCount, backtickLevel, asteriskCount, asteriskLevel, codeLineIdx; 
		
		void delegate(dchar ch) onChar; 
		void delegate() onFinalizeCode, onFinish; 
		
		version(/+$DIDE_REGION+/none) {
			//example events
			void onChar(dchar ch) 
			{
				if(ch=='\n')
				{ writeln("CR"); }
				else
				{
					write(
						"\34"~
						(
							backtickLevel ? (codeLineIdx>0 ? "\3" : "\2") : 
							asteriskLevel==1 ? "\5" : 
							asteriskLevel==2 ? "\6" : 
							"\10"
						)
						~ch.text~"\34\0"
					); 
				}
			} 
			void onFinalizeCode()
			{ write("\33\15[CODE]\33\7"); } 
		}
		
		
		void process(dchar ch /+must call with a \0 at the very end.+/)
		{
			
			bool processEnterExit(in dchar marker, ref int count, ref int level, void delegate() onExit = null)
			{
				if(ch==marker) { count++; return true; }
				if(count)
				{
					if(level==0)	{/+enter+/level = count; }
					else if(level==count)	{/+leave+/if(onExit) onExit(); level = 0; }
					else	{/+as is+/foreach(i; 0..level) onChar(marker); }
					count=0; 
				}
				return false; 
			} 
			
			if(processEnterExit('`', backtickCount, backtickLevel, { if(codeLineIdx>0) onFinalizeCode(); })) return; 
			if(!backtickLevel) if(processEnterExit('*', asteriskCount, asteriskLevel)) return; 
			
			
			void finalizeLine()
			{
				asteriskCount = 0; asteriskLevel = 0; 
				backtickCount = 0; 
				if(backtickLevel.inRange(1, 2)) { onFinalizeCode(); backtickLevel = 0;  }
				if(backtickLevel) codeLineIdx++; else codeLineIdx = 0; 
			} 
			
			if(ch=='\r') return; 
			if(ch=='\n') { finalizeLine; onChar('\n'); return; }
			if(ch=='\0') { finalizeLine; onFinish(); return; }
			
			onChar(ch); 
		} 
	} 
	
	MarkdownProcessor markdownProcessor; 
	
	bool update_markDown(
		void delegate(dchar) onChar/+Called when have to inject a char. State can be examined.+/, 
		void delegate() onFinalizeCode/+Called at the end of a multiline code block.+/,
		void delegate() onFinish/+The very end of document+/
	)
	{
		void init()
		{
			if(!markdownProcessor) markdownProcessor = new MarkdownProcessor; 
			markdownProcessor.onChar 	= onChar,
			markdownProcessor.onFinalizeCode 	= onFinalizeCode,
			markdownProcessor.onFinish 	= onFinish; 
		} 
		void emit(string s)
		{
			if(s=="") return; 
			init; foreach(ch; s.byDchar) markdownProcessor.process(ch); 
		} 
		void emitBlock(string b, string s)
		{ emit("\n\n/+"~b~": "~s.safeDCommentBody~"+/\n"); } 
		
		scope(exit) if(!running && markdownProcessor) { emit("\0"); markdownProcessor.free; }
		return update(
			(Event event, string s)
			{
				final switch(event)
				{
					/+Todo: These events should be passed forward, so the caller could decide what to do.+/
					case Event.text: 	emit(s); 	break; 
					case Event.error: 	emitBlock("Error", s); 	break; 
					case Event.warning: 	emitBlock("Warning", s); 	break; 
					case Event.done: 	if(s!="") emitBlock("Note", s); 	break; 
				}
			}
		); 
	} 
	
} 
class AiModel
{
	mixin SmartParent!(
		q{
			@STORED string 	apiUrl,
			@STORED string 	model,
			@STORED string 	system 	= "You are a helpful assistant."	,
			@STORED float 	temperature 	= .625	
		}
	); 
	
	string apiKey; 
	Path cachePath; 
	bool cached; 
	
	void _construct()
	{}  void _destruct()
	{} 
	
	auto newChat()
	{ return new AiChat(this); } 
	
	///This is the blocking version.  Use newChat.ask() for background version.
	string ask(T)(
		T prompt, bool debugPrint=false, 
		void delegate(AiChat.Event e, string) userEvent=null,
		bool refreshCache=false
	)
	{
		if(prompt.empty) return ""; 
		
		auto c = newChat; c.ask(prompt, refreshCache); 
		
		void nullEvent(AiChat.Event e, string s) {} 
		auto onEvent = ((userEvent)?(userEvent):(((debugPrint)?(null):(&nullEvent)))); 
		
		do { c.update(onEvent); sleep(15); }while(c.running); 
		c.update(onEvent)/+fetch all remaining parts+/; 
		
		if(!c.query.messages.empty && c.query.messages.back.role==AiChat.roleAssistant)
		return c.query.messages.back.content; 
		
		return ""; 
	} 
} 
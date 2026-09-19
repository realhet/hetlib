module het.http; 

import het; 

//Todo: libCUrl dll-t statikusan linkelni! Jelenleg az ldc2\bin-ben levo van hasznalva

//enum _log = true; //todo: ezt a logolast kozpontositani

auto curlGet(string url)
{
	import std.net.curl; 
	if(url.canFind(" ")) url = url.urlEncode; 
	return cast(string)get!(AutoProtocol, ubyte)(url); 
} 

auto curlGet_noThrow(string url)
{
	try	return curlGet(url); 
	catch(Exception e)	return "Error: "~e.msg; 
} 

auto curlPostJson(string url, string body, out string responseBody)
{
	import std.net.curl : HTTP; 
	auto http = HTTP(); 
	http.url	= url,
	http.method 	= HTTP.Method.post; 
	http.addRequestHeader("Content-Type", "application/json"); 
	http.addRequestHeader("Accept",       "application/json"); 
	
	responseBody = ""; 
	http.onSend = 	((void[] data) {
		const tmp = body.fetchFrontN(data.length); 
		data[0..tmp.length] = (cast(void[])(tmp)); 
		return tmp.length; 
	}),
	http.onReceiveHeader = 	((in char[] key, in char[] value){}),
	http.onReceive = 	((ubyte[] data) {
		responseBody ~= (cast(string)(data.idup)); 
		return data.length; 
	}); 
	
	http.perform(No.throwOnError); 
	
	return http; 
} 

struct Request
{
	 //this is also the response
	string query; 
	string owner; 	//every client is filtered by this. Can get one with identityStr()
	string category; 	/+
		- if not "", then only the last request of each category will be served.
		- if "", then all requests will be server in a sequential order. It can be overloaded.
	+/
	bool valid;    //pop returns an invalid if the queue is empty
	string response, error; 
	
	string toString()
	{
		return format!"Request: %s\n  own: %s cat: %s  valid: %s\n  len: %d  %s: %s\n"
		(query, owner, category, valid, response.length, !error.empty ? "ERROR: " : "response: ", response ~ error); 
	} 
} 

//Todo: replace the queues with SafeQueue

synchronized class RequestQueue
{
	private Request[] requests; 
	
	void push(Request r)
	{
		r.valid = true; 
		if(r.category!="")
		{
			const idx = requests.map!((a)=>(a.category==r.category && a.owner==r.owner)).countUntil(true); 
			if(idx<0)	requests ~= r /+append+/; 
			else	requests[idx] = r /+keep new, ignore the older one+/; 
		}
		else { requests ~= r /+always append+/; }
	} 
	
	Request pop()
	=> requests.fetchFront; 
} 

synchronized class ResponseQueue
{
	private Request[] responses; 
	
	void push(Request r)
	{ r.valid = true; responses ~= r; } 
	
	Request pop(string owner)
	{
		/+
			Todo: What happens with the responses when an owner disappears?
			Not the memory is simply lost forever.
		+/
		Request r; 
		auto i = responses.map!(a => a.owner==owner).countUntil(true); 
		
		if(i >= 0)
		{
			r = responses[i]; 
			responses = responses.remove(i); 
		}
		return r; 
	} 
	
	Request[] popAll(string owner)
	{
		Request[] res; 
		while(1) {
			auto r = pop(owner); 
			if(!r.valid) break; 
			res ~= r; 
		}
		return res; 
	} 
	
	int length() const
	{ return responses.length.to!int; } 
} 

class HttpQueue
{
		//must be freed, otherwise the thread will stuck.
	public: 
		string getImplementation(string q)
	{
		return curlGet(q.urlEncode); //Todo: this is bad because of query handling "?&=" chars
	} 
	
		struct State
	{
		int commCnt, errorCnt; 
		bool comm, error, idle; 
		double alive; //for timeout checking
		
		auto goodCnt() const
		{ return commCnt-errorCnt; } 
	} 
	private: 
		/+
		Note: here if I use new RequestQueue, then it will be the same shared instance between all HttpQueue classes. 
		Here I need a separate instance. Terminated and state_ is ok, but newExpression means a global constructor here!!
	+/
		shared RequestQueue inbox; 
		shared ResponseQueue outbox; 
	
		shared int terminated = 0; //1= terminate, 2 = ack
		shared State state_; 
	
		static void httpWorker(
		string name, 	shared RequestQueue inbox, 	shared ResponseQueue outbox, 
			shared int* terminated, 	shared State* state_
	)
	{
		import core.thread; 
		Thread.getThis.isDaemon = true; 
		
		enum log = 0; 
		
		auto st = cast(State*) state_; 
		while(*terminated == 0)
		{
			st.alive = QPS.value(second); //Todo: now
			auto r = inbox.pop; 
			if(r.valid)
			{
				st.idle = false; 
				
				if(log)
				LOG("httpWorker fetching: ", r.query); 
				double t0 = 0; if(log)
				t0 = QPS.value(second);  //Todo: now
				
				st.comm = true; 
				st.commCnt++; 
				
				try {
					r.response = curlGet(r.query); 
					if(log)
					LOG("Done fetching: ", r.query, QPS.value(second)-t0); 
					st.error = false; 
				}
				catch(Exception e)
				{
					if(log)
					WARN("ERROR fetching: ", r.query, QPS.value(second)-t0, e.msg); 
					r.error = e.msg; 
					st.error = true; 
					st.errorCnt++; 
				}
				
				if(r.owner != "") outbox.push(r); 
				
				st.comm = false; 
			}
			else
			{
				st.idle = true; 
				sleep(1); 
			}
		}
		*terminated = 2; //ack
	} 
	
		struct StatusLedState
	{
		BinarySignalSmootherNew!4 smComm; 
		int lastCommCnt; 
		enum maxTimeOut = 5; //must be high, because CURL is blocking. Even if it's called from different threads.
		//Todo: replace CURL
		bool commState; 
		bool errorState; 
		
		uint tick; 
		
		void update(State state)
		{
			if(chkSet(tick, application.tick))
			{
				commState = smComm.process(lastCommCnt.chkSet(state.commCnt)); 
				errorState = state.error || (QPS.value(second)-state.alive) > maxTimeOut; //Todo: now
			}
		} 
		
		enum Style
		{ greenRedBlack, greenRedYellow} 
		Style style; 
		
		auto ledState()
		{
			final switch(style)
			{
				case Style.greenRedBlack: return tuple(!commState, errorState ? clRed : clLime); 
				case Style.greenRedYellow: return tuple(true      , commState ? clYellow : errorState ? clRed : clLime); 
			}
		} 
	} 
	
		StatusLedState statusLedState; 
	
		const string name; 
	
	public: 
		this(string name = "")
	{
		this.name = name=="" ? this.identityStr : name; 
		inbox = new shared RequestQueue; 
		outbox = new shared ResponseQueue; 
		
		import std.concurrency : spawn; 
		spawn(&httpWorker, this.name, inbox, outbox, &terminated, &state_); 
	} 
	
		~this()
	{
			//must be called manually, or the class must be allocated with scoped!
		terminated = 1; 
		while(terminated != 2)
		sleep(1); 
	} 
	
		void request(T)(in T owner, string url, string category="")
	{ inbox.push(Request(url, identityStr(owner), category)); } 
	
		void post(string url, string category="")
	{
		/+
			owner is "", so it will forgotten after perform().
			Not the same as HTTP POST!!!
		+/
		request(null, url, category); 
	} 
	
		int pending()
	{ return outbox.length; } 
	
		Request[] receive(T)(in T owner)
	{
		auto res = outbox.popAll(owner.identityStr); 
		return res; 
	} 
	
		State state()
	{ return state_; } 
	
		auto ledState()
	{
		statusLedState.update(state); 
		return statusLedState.ledState; 
	} 
	
} 

class GlobalHttpQueue : HttpQueue
{
	this()
	{ super("globalHttpQueue"); } 
} 

alias globalHttpQueue = Singleton!GlobalHttpQueue; 

void globalHttpRequest(T)(in T owner, string url, string category="")
{ globalHttpQueue.request(owner, url, category); } 

auto globalHttpReceive(T)(in T owner)
{ return globalHttpQueue.receive(owner); } 

void testHttpQueue()
{
	const 	urls = [
		"google.com", 
		"https://www.w3.org/MarkUp/Test/xhtml-print/20050519/tests/jpeg444.jpg", 
		"will not access because of category", 
		"https://www.youtube.com/"
	],
		categories = ["", "", "cat1", "cat1"]; 
	
	foreach(i, url; urls)
	globalHttpRequest("testHttpQueue", url, categories[i]); 
	
	int cnt=0; 
	while(1)
	foreach(r; globalHttpReceive("testHttpQueue"))
	{
		cnt++; 
		print(r.owner, r.query, r.category, r.error, r.response.length); 
		
		if(cnt==3)
		{
			safePrint("http test successful. Press enter to continue"); 
			readln; 
			return; 
		}
	}
} 

shared static ~this()
{
	//Todo: it's never getting called from a gui app... why?
	//std.stdio.writeln("FUCK");
	//std.stdio.readln;
	if(globalHttpQueue.pending)
	WARN("GlobalHttpQueue: There are pending http requests."); 
} 
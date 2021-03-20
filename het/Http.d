module het.http;

import het.utils;

//todo: libCUrl dll-t statikusan linkelni! Jelenleg az ldc2\bin-ben levo van hasznalva

//enum _log = true; //todo: ezt a logolast kozpontositani

auto curlGet(string url){
  import std.net.curl;
  if(url.canFind(" ")) url = url.urlEncode;
  return cast(string)get!(AutoProtocol, ubyte)(url);
}

auto curlGet_noThrow(string url){
  try{
    return curlGet(url);
  }catch(Exception e){
    return "Error: "~e.msg;
  }
}

struct Request{ //this is also the response
  string query;
  string owner;    //every client is filtered by this. Can get one with identityStr()
  string category; //if not empty, then only the last of this kind is served
  bool valid;    //pop returns an invalid if the queue is empty
  string response, error;

  string toString(){
    return format!"Request: %s\n  own: %s cat: %s  valid: %s\n  len: %d  %s: %s\n"(query, owner, category, valid, response.length, !error.empty ? "ERROR: " : "response: ", response ~ error);
  }
}

synchronized class RequestQueue{
  private Request[] requests;

  void push(Request r) {
    r.valid = true;
    if(r.category!=""){
      auto idx = requests.map!(a => a.category==r.category && a.owner==r.owner).countUntil(true);
      if(idx<0) requests ~= r;
           else requests[idx] = r;
    }else{
      requests ~= r;
    }
  }

  Request pop() {
    Request r;
    if(!requests.empty){
      r = requests[0];
      requests = requests[1 .. $];
    }
    return r;
  }
}

synchronized class ResponseQueue{
  private Request[] responses;

  void push(Request r) {
    r.valid = true;
    responses ~= r;
  }

  Request pop(string owner){
    Request r;
    auto i = responses.map!(a => a.owner==owner).countUntil(true);

    if(i >= 0){
      r = responses[i];
      responses = responses.remove(i);
    }
    return r;
  }

  Request[] popAll(string owner){
    Request[] res;
    while(1){
      auto r = pop(owner);
      if(!r.valid) break;
      res ~= r;
    }
    return res;
  }

  int length() const{
    return responses.length.to!int;
  }
}

struct DigitalSignal{
  private{
    ubyte _raw;
    import std.bitmanip; mixin(bitfields!(
          bool, "current"  , 1,
          bool, "changed"  , 1,
          bool, "displayed", 1,
          int , "_dummy"   , 5));
  }

  void pulse(bool value){
    current = value;
    changed = true;
  }

  void set(bool value){
    if(value != current) pulse(value);
  }

  void opAssign(in bool rhs){ set(rhs); }

  bool get(){
    displayed = !displayed;

/*    if(changed){ displayed = !displayed; changed = false; }
           else displayed = current;*/

    return displayed;
  }
}

struct DigitalSignal_smoothed{
  float minDeltaTime = 0.3; //sec

  private DigitalSignal ds;
  private float lastDisplayChanged = 0;
  private bool lastDisplayed;

  void pulse    (bool after)  { ds.pulse(after); }
  void set      (bool value)  { ds.set(value); }
  void opAssign (in bool rhs) { set(rhs); }

  bool get(float now){
    const dt = now-lastDisplayChanged;

    if(dt >= minDeltaTime){
      const act  = ds.get;
      if(lastDisplayed != act){
        lastDisplayed = act;
        lastDisplayChanged = now;
      }
    }

    return lastDisplayed;
  }

  bool get(){ return get(QPS); }
}


class HttpQueue{  //must be freed, otherwise the thread will stuck.
public:
  string getImplementation(string q){
    return curlGet(q.urlEncode); //todo: this is bad because of query handling "?&=" chars
  }

  struct State{
    int commCnt, errorCnt;
    bool comm, error, idle;
    double alive; //for timeout checking
  }

private:
  //note: here if I use new RequestQueue, then it will be the same shared instance between all HttpQueue classes. Here I need a separate instance. Terminated and state_ is ok, but newExpression means a global constructor here!!
  shared RequestQueue inbox;
  shared ResponseQueue outbox;

  shared int terminated = 0; // 1= terminate, 2 = ack
  shared State state_;

  static void httpWorker(string name, shared RequestQueue inbox, shared ResponseQueue outbox, shared int* terminated, shared State* state_){
    enum log = false;

    auto st = cast(State*) state_;
    while(*terminated == 0){
      st.alive = QPS;
      auto r = inbox.pop;
      if(r.valid){
        st.idle = false;

        if(log) LOG("httpWorker fetching: ", r.query);
        double t0 = 0; if(log) t0 = QPS;

        st.comm = true;
        st.commCnt++;

        try{
          r.response = curlGet(r.query);
          if(log) LOG("Done fetching: ", r.query, QPS-t0);
          st.error = false;
        }catch(Exception e){
          if(log) WARN("ERROR fetching: ", r.query, QPS-t0, e.msg);
          r.error = e.msg;
          st.error = true;
          st.errorCnt++;
        }

        if(r.owner ~= "")
          outbox.push(r);

        st.comm = false;
      }else{
        st.idle = true;
        sleep(1);
      }
    }
    *terminated = 2; //ack
  }

public:
  this(string name = ""){
    inbox = new shared RequestQueue;
    outbox = new shared ResponseQueue;

    import std.concurrency : spawn;
    spawn(&httpWorker, name, inbox, outbox, &terminated, &state_);
  }

  ~this(){ //must be called manually, or the class must be allocated with scoped!
    terminated = 1;
    while(terminated != 2)
      sleep(1);
  }

  void request(T)(in T owner, string url, string category=""){
    inbox.push(Request(url, identityStr(owner), category));
  }

  void post(string url, string category=""){
    request(null, url, category);
  }

  int pending(){
    return outbox.length;
  }

  Request[] receive(T)(in T owner){
    auto res = outbox.popAll(owner.identityStr);
    return res;
  }

  State state(){
    return state_;
  }
}

class GlobalHttpQueue : HttpQueue{ this(){ super("globalHttpQueue"); } }

alias globalHttpQueue = Singleton!GlobalHttpQueue;

void globalHttpRequest(T)(in T owner, string url, string category=""){
  globalHttpQueue.request(owner, url, category);
}

auto globalHttpReceive(T)(in T owner){
  return globalHttpQueue.receive(owner);
}

void testHttpQueue(){
  const urls = ["google.com", "https://www.w3.org/MarkUp/Test/xhtml-print/20050519/tests/jpeg444.jpg", "https://www.youtube.com/", "will not access because of category"],
        categories = ["", "", "1", "1"];

  foreach(i, url; urls)
    globalHttpRequest("testHttpQueue", url, categories[i]);

  int cnt=0;
  while(1) foreach(r; globalHttpReceive("testHttpQueue")){
    cnt++;
    print(r.owner, r.query, r.category, r.error, r.response.length);

//    safePrint(format(`File #%d arrived. %s %(%x %)`, cnt, r.response[0..min(16, $)], cast(ubyte[])(r.response)[0..min(16, $)]));
    if(cnt==3){
      safePrint("http test successful. Press enter to continue");
      readln;
      return;
    }
  }
}

shared static ~this(){
  //todo: it's never getting called from a gui app... why?
  //std.stdio.writeln("FUCK");
  //std.stdio.readln;
  if(globalHttpQueue.pending)
    WARN("GlobalHttpQueue: There are pending http requests.");
}
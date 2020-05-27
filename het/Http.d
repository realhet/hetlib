module het.http;

import het.utils;

//todo: libCUrl dll-t statikusan linkelni! Jelenleg az ldc2\bin-ben levo van hasznalva

enum _log = false; //todo: ezt a logolast kozpontositani

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


class HttpQueue{  //must be freed, otherwise the thread will stuck.
public:
  string getImplementation(string q){
    return curlGet(q.urlEncode);
  }
private:
  auto inbox = new shared RequestQueue;
  auto outbox = new shared ResponseQueue;
  shared int terminated = 0; // 1= terminate, 2 = ack

  static void httpWorker(shared RequestQueue inbox, shared ResponseQueue outbox, shared int* terminated){
    enum log = false;

    while(*terminated == 0){
      auto r = inbox.pop;
      if(r.valid){
        if(log) LOG("httpWorker fetching: ", r.query);
        const t0 = QPS;
        try{
          r.response = curlGet(r.query);
          if(log) LOG("Done fetching: ", r.query, QPS-t0);
        }catch(Exception e){
          if(log) WARN("ERROR fetching: ", r.query, QPS-t0, e.msg);
          r.error = e.msg;
        }
        if(r.owner ~= "")
          outbox.push(r);
      }else{
        sleep(1);
      }
    }
    *terminated = 2; //ack
  }

public:
  this(){
    import std.concurrency;
    spawn(&httpWorker, inbox, outbox, &terminated);
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
}


//easy global access for a queue
HttpQueue globalHttpQueue(){
  __gshared static HttpQueue que;
  if(que is null) que = new HttpQueue;
  return que;
}

void httpRequest(T)(in T owner, string url, string category=""){
  globalHttpQueue.request(owner, url, category);
}

auto httpReceive(T)(in T owner){
  return globalHttpQueue.receive(owner);
}

void testHttpQueue(){
  const urls = ["google.com", "https://www.w3.org/MarkUp/Test/xhtml-print/20050519/tests/jpeg444.jpg", "https://www.youtube.com/", "will not access because of category"],
        categories = ["", "", "1", "1"];

  foreach(i, url; urls)
    httpRequest("testHttpQueue", url, categories[i]);

  int cnt=0;
  while(1) foreach(r; httpReceive("testHttpQueue")){
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
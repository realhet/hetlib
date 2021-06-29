module het.graph;

import het, het.ui, het.keywords;

class GraphLabel(Node) : Row { // GraphLabel /////////////////////////////
  Node parent;
  bool isReference; // a non reference is the caption of the definition
  string name;

  this(){}

  this(Node parent, bool isReference, string name, string caption, in TextStyle ts){
    this.name = name;
    this.parent = parent;
    this.isReference = isReference;
    appendStr(caption, ts);
  }

  this(Node parent, bool isReference, string name, in TextStyle ts){
    this(parent, isReference, name, name, ts);
  }

  this(Node parent, bool isReference, string name){ //todo: this is for languageGraph only
    auto ts = tsNormal;
    ts.applySyntax(isReference ? SyntaxKind.Whitespace : SyntaxKind.BasicType);
    ts.underline = isReference;
    ts.italic = true;
    this(parent, isReference, name, ts);
  }

  auto absOuterBounds() const{ return innerBounds + parent.absInnerPos; }
  auto absOutputPos  () const{ return absOuterBounds.rightCenter; }
  auto absInputPos   () const{ return absOuterBounds.leftCenter ; }
}

class GraphNode(Graph, Label) : Row { // GraphNode /////////////////////////////
  mixin CachedDrawing;

  Graph parent;

  this(){
    flags._measureOnlyOnce = true;
  }

  bool isSelected, oldSelected;
  bool isHovered() { return this is parent.hoveredNode; }

  string groupName_original;
  string groupName_override;
  string groupName() const { return groupName_override.length ? groupName_override : groupName_original; }

  string fullName() const { return groupName ~ "/" ~ name; }

  auto labels    (){ return subCells.map!(a => cast(Label)a).filter!"a"; }
  auto targets   (){ return labels.filter!(a => !a.isReference); }
  auto references(){ return labels.filter!(a =>  a.isReference); }

  Label nameLabel(){
    pragma(msg, Label, typeof(this));
    foreach(t; targets) return t; return null;
  }

  string name() const { //default implementation
    foreach(t; (cast()this).targets) return t.name;
    ERR("Unable to get default name. Should override GraphNode.name().");
    return "";
  }

  auto absInnerBounds() const{ return innerBounds + parent.innerPos; };
  auto absInnerPos   () const{ return innerPos    + parent.innerPos; };
}

class ContainerGraph(Node : Cell, Label : GraphLabel!Node) : Container { // ContainerGraph ///////////////////////////////////////////
  bool showSelection = true;

  static assert(__traits(compiles, {
    Node n; string s = n.groupName; //this could be optional.
  }), "Field requirements not met.");

  SelectionManager!Node selection;

  bool invertEdgeDirection;
  float groupMargin = 30;

  auto nodes        (){ return cast(Node[])subCells; } //note: all subcells' type must be Node
  auto selectedNodes(){ return nodes.filter!(a => a.isSelected); }
  auto hoveredNode  (){ return selection.hoveredItem; }

  private Node[string] nodeByName;

  auto findNode(string name){ auto a = name in nodeByName; return a ? *a : null; }

  Node addNode(string name, Node node){
    enforce(cast(Node)node !is null     , "addNode() param must be an instance of "~Node.stringof       );
    enforce(name.length                 , "Name must be non-empty."                                     );
    enforce(findNode(name) is null      , "Node named "~name.quoted~" already exists"                   );
    enforce(!node.parent                , "Node already has a parent."                                  );

    const bnd = allBounds;
    const nextPos = bnd.valid ? bnd.bottomLeft + vec2(0, 32) : vec2(0);
    node.outerPos = nextPos;

    nodeByName[name] = node;
    append(node); //this is Container.append()
    return node;
  }

  Node findAddNode(string name, lazy Node node){
    if(auto n = findNode(name)) return n;
    return addNode(name, node/+lazy!!!+/);
  }

  bool removeNode(Node node){
    const oldLen = subCells.length;
    subCells = subCells.filter!(c => c !is node).array; //todo: use remove()
    if(subCells.length < oldLen){
      nodeByName.remove(node.name);
      selection.notifyRemove(node);
      return true;
    }else
      return false;
  }

  bool removeNode(string name){
    if(auto node = findNode(name)){
      removeNode(node);
      return true;
    }else
      return false;
  }

  auto removeNodes(R)(R nodes) if(isInputRange!R && is(ElementType!R == Node)){
    return nodes.count!(n => removeNode(n)).to!int;
  }

  auto removeNodes(string nameFilter){
    return nodes.filter!(n => n.name.isWild(nameFilter));
  }

  Node toggleNode(string name, lazy Node node){
    if(removeNode(name)) return null;
                    else return addNode(name, node/+lazy!!!+/);
  }

  void removeAll(){
    subCells = [];
    nodeByName.clear;
    selection.notifyRemoveAll;
  }

  auto nodeGroups(){ return nodes.dup.sort!((a, b) => a.groupName < b.groupName).groupBy; } //note .dup is important because .sort works in-place.

  auto groupBounds(){
    return nodeGroups.filter!(g => g.front.groupName!="")          //exclude unnamed groups
                     .map!(grp => grp.map!(a => a.outerBounds)
                                     .fold!"a|b");
  }

  auto allBounds(){
    return nodes.map!(n => n.outerBounds)
                .fold!"a|b"(bounds2.init);
  }


  Container.SearchResult[] searchResults;
  bool searchBoxVisible;
  string searchText;

  // inputs from outside
  private{
    float viewScale = 1; //used for automatic screenspace linewidth
    vec2[2] searchBezierStart; //first 2 point of search bezier lines. Starting from the GUI matchCount display.
  }

  this(){
    bkColor = clBlack;
    selection = new typeof(selection);
  }

  struct Link{ Label from; Node to; }
  Link[] _links;

  auto links(){
    if(_links.empty)
      foreach(d; nodes)
        foreach(from; d.labels)
          if(from.isReference) if(auto to = findNode(from.name))
            _links ~= Link(from, to);
    return _links;
  }

  void update(View2D view, vec2[2] searchBezierStart){
    this.viewScale = view.scale;
    this.searchBezierStart = searchBezierStart;

    selection.update(!im.wantMouse, view, subCells.map!(a => cast(Node)a).array);
  }

  // drawing routines ////////////////////////////////////////////

  protected void drawSearchResults(Drawing dr, RGB clSearchHighLight){ with(dr){
    foreach(sr; searchResults)
      sr.drawHighlighted(dr, clSearchHighLight);

    lineWidth = -2 * sqr(sin(QPS.fract*PIf*2));
    alpha = 0.66;
    color = clSearchHighLight;
    foreach(sr; searchResults)
      bezier2(searchBezierStart[0], searchBezierStart[1], sr.absInnerPos + sr.cells.back.outerBounds.rightCenter);

    alpha = 1;
  }}

  protected void drawSelectedItems(Drawing dr, RGB clSelected, float selectedAlpha, RGB clHovered, float hoveredAlpha){ with(dr){
    color = clSelected; alpha = selectedAlpha;  foreach(a; selectedNodes) dr.fillRect(a.outerBounds);
    color = clHovered ; alpha = hoveredAlpha ;  if(hoveredNode !is null) dr.fillRect(hoveredNode.outerBounds);
    alpha = 1;
  }}

  protected void drawSelectionRect(Drawing dr, RGB clRect){
    if(auto bnd = selection.selectionBounds) with(dr) {
      lineWidth = -1;
      color = clRect;
      drawRect(bnd);
    }
  }

  protected void drawGroupBounds(Drawing dr, RGB clGroupFrame){ with(dr){
    color = clGroupFrame;
    lineWidth = -1;
    foreach(bnd; groupBounds) drawRect(bnd.inflated(groupMargin));
  }}

  protected void drawLinks(Drawing dr){ with(dr){
    alpha = 0.66;
    foreach(link; links){
      const h1 = link.from.parent.isHovered, h2 = link.to.isHovered;

      //hide interGroup links
      if(!h1 && !h2 && link.from.parent.groupName != link.to.groupName) continue;

      color  = h1 && !h2 ? clAqua
             : h2 && !h1 ? clLime
                         : clSilver;

      lineWidth = viewScale>1 ? 1 : -1; //line can't be thinner than 1 pixel, but can be thicker

      //OutputPos = rightCenter, InputPos = leftCenter

      vec2 P0, P1, P2, P3, P4, ofs;
      if(!invertEdgeDirection){ //arrows go the the right. It's good for a grammar graph
        P0 = link.from.absOutputPos; P4 = link.to.nameLabel.absInputPos;
        float a = min(50, distance(P0, P4)/3);
        ofs = P0.x<P4.x ? vec2(a, 0) : vec2(a, -a);
      }else{ //arrows go to the left. Good for module hierarchy. Rightmost module is the main project.
        P0 = link.from.absInputPos; P4 = link.to.nameLabel.absOutputPos;
        float a = min(50, distance(P0, P4)/3);
        ofs = P0.x>P4.x ? vec2(-a, 0) : vec2(-a, -a);
      }
      P1 = P0 + ofs,
      P3 = P4 + ofs*vec2(-1, 1),
      P2 = avg(P1, P3);
      bezier2(P0, P1, P2);
      bezier2(P2, P3, P4);

    }
    alpha = 1;
  }}

  protected void drawOverlay(Drawing dr){ with(dr){
    drawLinks(dr);
    if(showSelection) drawSelectedItems(dr, clAccent, 0.25, clWhite, 0.2);
    drawSelectionRect(dr, clWhite);
    drawGroupBounds(dr, clSilver);
    drawSearchResults(dr, clYellow);
  }}

  override void draw(Drawing dr){
    super.draw(dr); //draw cached stuff

    auto dr2 = dr.clone;
    drawOverlay(dr2); //draw uncached stuff on top
    dr.subDraw(dr2);
  }

  void UI_SearchBox(View2D view){ // UI SearchBox ////////////////////////////////
    with(im) Row({
      //Keyboard shortcuts
      auto kcFind      = KeyCombo("Ctrl+F"),
           kcFindZoom  = KeyCombo("Enter"), //only when edit is focused
           kcFindClose = KeyCombo("Esc"); //always

      if(kcFind.pressed) searchBoxVisible = true; //this is needed for 1 frame latency of the Edit
      //todo: focus on the edit when turned on
      if(searchBoxVisible){
        width = fh*12;

        Text("Find ");
        .Container editContainer;
        if(Edit(searchText, kcFind, { flex = 1; editContainer = actContainer; })){
          //refresh search results
          searchResults = search(searchText);
        }

        // display the number of matches. Also save the location of that number on the screen.
        const matchCnt = searchResults.length;
        Row({
          if(matchCnt) Text(" ", clGray, matchCnt.text, " ");
        });

        if(Btn(symbol("Zoom"), isFocused(editContainer) ? kcFindZoom : KeyCombo(""), enable(matchCnt>0), hint("Zoom screen on search results."))){
          const maxScale = max(view.scale, 1);
          view.zoomBounds(searchResults.map!(r => r.bounds).fold!"a|b", 12);
          view.scale = min(view.scale, maxScale);
        }

        if(Btn(symbol("ChromeClose"), kcFindClose, hint("Close search box."))){
          searchBoxVisible = false;
          searchText = "";
          searchResults = [];
        }
      }else{

        if(Btn(symbol("Zoom"       ), kcFind, hint("Start searching."))){
          searchBoxVisible = true ; //todo: Focus the Edit control
        }
      }
    });
  }

  //scroller state
  Node actNode; //state
  auto topIndex = 0; //state
  enum pageSize = 10;

  void UI_Editor(){ alias GraphNode = Node; /*todo: fucking name collision with im.Node */   with(im){ // UI_Editor ///////////////////////////////////
    // WildCard filter
    static hideUI = true;
    static filterStr = "";
    Row({ ChkBox(hideUI, "Hide Graph UI "); });

    if(!hideUI){

      Row({ Text("Filter "); Edit(filterStr, { flex = 1; }); });

      //filtered data source
      auto filteredNodes = nodes.filter!(a => a.name.isWild(filterStr~"*")).array;
      ScrollListBox(actNode, filteredNodes, (in GraphNode n){ Text(n.name); width = 260; }, pageSize, topIndex);

      Spacer;
      Row({
        auto selected = selectedNodes.array;
        Row({ Text("Selected items: "), Static(selected.length), Text("  Total: "), Static(nodes.length); });

        const selectedGroupNames = selected.map!(a => a.groupName).array.sort.uniq.array;
        static string editedGroupName;
        Row({
          Text("Selected groups: ");
          foreach(i, name; selectedGroupNames)
            if(Btn(name, genericId(i))) editedGroupName = name;
        });

        Spacer;
        Row({
          Text("Group name os felected items: \n");
          Edit(editedGroupName, { width = 200; });
          if(Btn("Set", enable(selected.length>0))) foreach(a; selected) a.groupName_override = editedGroupName;
        });

      });

      Spacer;
      if(Btn("test")){
      }

    }
  }}

}

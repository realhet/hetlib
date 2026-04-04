//@exe
//@debug
//@/release

//@compile --d-version=VulkanUI

/+
	Must solve later:
	/+Todo: inheritance+/
	/+Todo: multiple inheritance+/
	/+Todo: entity names: globally unique or not+/
	/+
		Todo: attribute cardinality
			single, multi, sorted, sequence
	+/
	/+Todo: default attributes+/
+/

import het.ui, amdb; 

struct TestCase
{ string schema, data; } 

static struct testCases
{
	static: 
	
	version(/+$DIDE_REGION types+/all)
	{
		auto types = TestCase
		(
			schema:
			`ShortInt is an Int
UByte is a ShortInt
WideString is a String`
		); 
	}
	
	version(/+$DIDE_REGION cars+/all)
	{
		auto cars = TestCase
		(
			schema:
			`Car is an Entity
Horse carriage is a Car
Gas powered car subtype of Car
Electric car is a subtype of Car
Hybrid car is a subtype of Gas powered car
//Hybrid car is a subtype of Electric car
//no multiple inheritance supported`
		); 
	}
	
	version(/+$DIDE_REGION animals+/all)
	{
		auto animals = TestCase
		(
			schema: 
			`Organism is an Entity
Animal is an Organism
Chordate is an Animal
Vertebrate is a Chordate
Mammal is a Vertebrate
Therian is a Mammal
Eutherian is a Therian
Carnivore is an Eutherian
Feliformia is a Carnivore
Felidae is a Feliformia
Pantherinae is a Felidae
Panthera is a Pantherinae
Lion is a Panthera
Leopard is a Panthera
Jaguar is a Panthera
Tiger is a Panthera
Snow Leopard is a Panthera
Caniformia is a Carnivore
Canidae is a Caniformia
Canis is a Canidae
Wolf is a Canis
Dog is a Canis
Fox is a Canidae
Red Fox is a Fox
Ursidae is a Caniformia
Bear is a Ursidae
Brown Bear is a Bear
Polar Bear is a Bear
Cetacean is a Eutherian
Whale is a Cetacean
Blue Whale is a Whale
Dolphin is a Cetacean
Bottlenose Dolphin is a Dolphin
Rodent is an Eutherian
Mouse is a Rodent
Rat is a Rodent
Squirrel is a Rodent
Lagomorph is an Eutherian
Rabbit is a Lagomorph
Hare is a Lagomorph
Bird is a Vertebrate
Falconiformes is a Bird
Falcon is a Falconiformes
Peregrine Falcon is a Falcon
Passerine is a Bird
Sparrow is a Passerine
Robin is a Passerine
Fish is a Vertebrate
Actinopterygii is a Fish
Salmon is an Actinopterygii
Trout is a Salmon
Shark is a Fish
Great White Shark is a Shark
Reptile is a Vertebrate
Squamata is a Reptile
Lizard is a Squamata
Iguana is a Lizard
Snake is a Squamata
Python is a Snake
Amphibian is a Vertebrate
Anura is an Amphibian
Frog is an Anura
Toad is an Anura
Arthropod is an Animal
Insect is an Arthropod
Lepidoptera is an Insect
Butterfly is a Lepidoptera
Monarch Butterfly is a Butterfly
Coleoptera is an Insect
Beetle is a Coleoptera
Ladybug is a Beetle`
		); 
	}
	
	version(/+$DIDE_REGION leds+/all)
	{
		auto leds = TestCase
		(
			schema: 
			`LED is an Entity
	... forward voltage  String
	... driver voltage  String
		... suggested resistor  String
			... current  String`,
			data: 
			`Red LED is a LED... forward voltage  2.0 V
	... driver voltage  3.3 V ... suggested resistor  220 Ω... current  6 mA
	... driver voltage  5.0 V ... suggested resistor  510 Ω... current  6 mA
	... driver voltage  12.0 V... suggested resistor  1.8 kΩ... current  5.5 mA
	... driver voltage  24.0 V... suggested resistor  3.9 kΩ... current  5.6 mA
Orange LED is a LED... forward voltage  2.0 V
	... driver voltage  3.3 V ... suggested resistor  270 Ω... current  5 mA
	... driver voltage  5.0 V ... suggested resistor  620 Ω... current  5 mA
	... driver voltage  12.0 V... suggested resistor  2.2 kΩ... current  4.5 mA
	... driver voltage  24.0 V... suggested resistor  4.7 kΩ... current  4.7 mA
Yellow LED is a LED... forward voltage  2.0 V
	... driver voltage  3.3 V ... suggested resistor  220 Ω... current  6 mA
	... driver voltage  5.0 V ... suggested resistor  510 Ω... current  6 mA
	... driver voltage  12.0 V... suggested resistor  1.8 kΩ... current  5.5 mA
	... driver voltage  24.0 V... suggested resistor  3.9 kΩ... current  5.6 mA
Green LED is a LED... forward voltage  3.2 V
	... driver voltage  3.3 V ... suggested resistor  33 Ω... current  3 mA
	... driver voltage  5.0 V ... suggested resistor  470 Ω... current  4 mA
	... driver voltage  12.0 V... suggested resistor  2.2 kΩ... current  4 mA
	... driver voltage  24.0 V... suggested resistor  4.7 kΩ... current  4.4 mA
Blue LED is a LED... forward voltage  3.2 V
	... driver voltage  3.3 V ... suggested resistor  100 Ω... current  1 mA
	... driver voltage  5.0 V ... suggested resistor  1.8 kΩ... current  1 mA
	... driver voltage  12.0 V... suggested resistor  8.2 kΩ... current  1 mA
	... driver voltage  24.0 V... suggested resistor  22 kΩ... current  0.9 mA
White LED is a LED... forward voltage  3.2 V
	... driver voltage  3.3 V ... suggested resistor  100 Ω... current  1 mA
	... driver voltage  5.0 V ... suggested resistor  1.8 kΩ... current  1 mA
	... driver voltage  12.0 V... suggested resistor  8.2 kΩ... current  1 mA
	... driver voltage  24.0 V... suggested resistor  22 kΩ... current  0.9 mA
Purple LED is a LED... forward voltage  3.2 V
	... driver voltage  3.3 V ... suggested resistor  68 Ω... current  1.5 mA
	... driver voltage  5.0 V ... suggested resistor  1 kΩ... current  1.8 mA
	... driver voltage  12.0 V... suggested resistor  4.7 kΩ... current  1.8 mA
	... driver voltage  24.0 V... suggested resistor  12 kΩ... current  1.7 mA`
		); 
	}
	
	version(/+$DIDE_REGION factory+/all)
	{
		auto factory = TestCase
		(
			schema:
			`Task is an Entity
	...  description  String
Machine  is an  Entity
	...  type  String
	...  status  String
	...  task  Task
		...  time_minutes  Time
Product  is a  Entity
	...  description  String
	...  task  Task
		...  step_number  Int
Customer  is a  Entity
	...  contact_email  String
	...  phone  String
ManufacturingOrder  is a  Entity
	...  product  Product
	...  customer  Customer
	...  quantity  Int
	...  order_date  Date
	...  due_date  Date
	...  status  String
ProductionSchedule  is a  Entity
	...  manufacturing_order  ManufacturingOrder
	...  technological_step  Int
	...  task  Task
	...  machine  Machine
	...  scheduled_start  DateTime
	...  scheduled_end  DateTime
	...  actual_start  DateTime
	...  actual_end  DateTime
	...  status  String`,
			data:
			`Cut Raw Material  is a  Task  ...  description  Cuts raw material to size
Mill Slot  is a  Task  ...  description  Mills a precision slot
Drill Holes  is a  Task  ...  description  Drills a pattern of holes
Polish Surface  is a  Task  ...  description  Polishes the surface to a fine finish
Bend Frame  is a  Task  ...  description  Bends the main structural frame
Final Assembly  is a  Task  ...  description  Assembles all components

CNC-Mill-01  is a  Machine
	...  type  CNC Mill
	...  status  Active
	...  task  Cut Raw Material
		...  time_minutes  15
	...  task  Mill Slot
		...  time_minutes  25
CNC-Mill-02  is a  Machine
	...  type  CNC Mill
	...  status  Active
	...  task  Cut Raw Material
		...  time_minutes  20
	...  task  Mill Slot
		...  time_minutes  30
Lathe-01  is a  Machine
	...  type  Lathe
	...  status  Maintenance
	...  task  Drill Holes
		...  time_minutes  10
Press-01  is a  Machine
	...  type  Hydraulic Press
	...  status  Active
	...  task  Bend Frame
		...  time_minutes  45
Assembly-Station-1  is a  Machine
	...  type  Assembly
	...  status  Active
	...  task  Final Assembly
		...  time_minutes  60
Painting-Booth-01  is a  Machine
	...  type  Painting
	...  status  Active
	...  task  Polish Surface
		...  time_minutes  35

Widget A  is a  Product
	...  description  Standard precision widget
	...  task  Cut Raw Material
		...  step_number  1
	...  task  Mill Slot
		...  step_number  2
	...  task  Polish Surface
		...  step_number  3
Gizmo B  is a  Product
	...  description  Advanced gizmo with cooling
	...  task  Cut Raw Material
		...  step_number  1
	...  task  Drill Holes
		...  step_number  2
	...  task  Polish Surface
		...  step_number  3
Thingamajig C  is a  Product
	...  description  Large assembly unit
	...  task  Bend Frame
		...  step_number  1
	...  task  Mill Slot
		...  step_number  2
	...  task  Drill Holes
		...  step_number  3
	...  task  Polish Surface
		...  step_number  4

Acme Corporation  is a  Customer
	...  contact_email  orders@acme.com
	...  phone  +1-555-0101
Globex Inc.  is a  Customer
	...  contact_email  procurement@globex.com
	...  phone  +1-555-0102
Stark Industries  is a  Customer
	...  contact_email  production@stark.com
	...  phone  +1-555-0103
Wayne Enterprises  is a  Customer
	...  contact_email  bruce.wayne@wayne-ent.com
	...  phone  +1-555-0104
Cyberdyne Systems  is a  Customer
	...  contact_email  sarah@cyberdyne.com
	...  phone  +1-555-0105

MO-001  is a  ManufacturingOrder
	...  product  Widget A
	...  customer  Acme Corporation
	...  quantity  100
	...  order_date  2024-01-02
	...  due_date  2024-01-10
	...  status  Completed
MO-002  is a  ManufacturingOrder
	...  product  Gizmo B
	...  customer  Globex Inc.
	...  quantity  50
	...  order_date  2024-01-03
	...  due_date  2024-01-15
	...  status  Completed
MO-003  is a  ManufacturingOrder
	...  product  Thingamajig C
	...  customer  Stark Industries
	...  quantity  25
	...  order_date  2024-01-05
	...  due_date  2024-01-20
	...  status  Completed
MO-004  is a  ManufacturingOrder
	...  product  Widget A
	...  customer  Wayne Enterprises
	...  quantity  150
	...  order_date  2024-01-15
	...  due_date  2024-01-25
	...  status  Completed
MO-005  is a  ManufacturingOrder
	...  product  Gizmo B
	...  customer  Cyberdyne Systems
	...  quantity  75
	...  order_date  2024-01-20
	...  due_date  2024-01-31
	...  status  In Progress

PS-001  is a  ProductionSchedule
	...  manufacturing_order  MO-001
	...  technological_step  1
	...  task  Cut Raw Material
	...  machine  CNC-Mill-01
	...  scheduled_start  2024-01-03T08:00
	...  scheduled_end  2024-01-03T12:30
	...  actual_start  2024-01-03T08:05
	...  actual_end  2024-01-03T12:25
	...  status  Completed
PS-002  is a  ProductionSchedule
	...  manufacturing_order  MO-001
	...  technological_step  2
	...  task  Mill Slot
	...  machine  CNC-Mill-01
	...  scheduled_start  2024-01-03T13:00
	...  scheduled_end  2024-01-03T17:45
	...  actual_start  2024-01-03T13:00
	...  actual_end  2024-01-03T17:40
	...  status  Completed
PS-003  is a  ProductionSchedule
	...  manufacturing_order  MO-001
	...  technological_step  3
	...  task  Polish Surface
	...  machine  Painting-Booth-01
	...  scheduled_start  2024-01-04T09:00
	...  scheduled_end  2024-01-04T16:20
	...  actual_start  2024-01-04T09:10
	...  actual_end  2024-01-04T16:15
	...  status  Completed
PS-004  is a  ProductionSchedule
	...  manufacturing_order  MO-002
	...  technological_step  1
	...  task  Cut Raw Material
	...  machine  CNC-Mill-02
	...  scheduled_start  2024-01-04T08:00
	...  scheduled_end  2024-01-04T12:40
	...  actual_start  2024-01-04T08:00
	...  actual_end  2024-01-04T12:35
	...  status  Completed
PS-005  is a  ProductionSchedule
	...  manufacturing_order  MO-002
	...  technological_step  2
	...  task  Drill Holes
	...  machine  Lathe-01
	...  scheduled_start  2024-01-04T13:30
	...  scheduled_end  2024-01-04T15:20
	...  actual_start  2024-01-04T13:45
	...  actual_end  2024-01-04T15:25
	...  status  Completed
PS-006  is a  ProductionSchedule
	...  manufacturing_order  MO-002
	...  technological_step  3
	...  task  Polish Surface
	...  machine  Painting-Booth-01
	...  scheduled_start  2024-01-05T08:00
	...  scheduled_end  2024-01-05T13:10
	...  actual_start  2024-01-05T08:00
	...  actual_end  2024-01-05T13:00
	...  status  Completed
PS-007  is a  ProductionSchedule
	...  manufacturing_order  MO-003
	...  technological_step  1
	...  task  Bend Frame
	...  machine  Press-01
	...  scheduled_start  2024-01-08T08:00
	...  scheduled_end  2024-01-08T14:45
	...  actual_start  2024-01-08T08:00
	...  actual_end  2024-01-08T14:40
	...  status  Completed
PS-008  is a  ProductionSchedule
	...  manufacturing_order  MO-003
	...  technological_step  2
	...  task  Mill Slot
	...  machine  CNC-Mill-02
	...  scheduled_start  2024-01-09T08:00
	...  scheduled_end  2024-01-09T11:30
	...  actual_start  2024-01-09T08:15
	...  actual_end  2024-01-09T11:20
	...  status  Completed
PS-009  is a  ProductionSchedule
	...  manufacturing_order  MO-003
	...  technological_step  3
	...  task  Drill Holes
	...  machine  Lathe-01
	...  scheduled_start  2024-01-09T13:00
	...  scheduled_end  2024-01-09T14:10
	...  actual_start  2024-01-09T13:00
	...  actual_end  2024-01-09T14:05
	...  status  Completed
PS-010  is a  ProductionSchedule
	...  manufacturing_order  MO-003
	...  technological_step  4
	...  task  Polish Surface
	...  machine  Painting-Booth-01
	...  scheduled_start  2024-01-10T08:00
	...  scheduled_end  2024-01-10T12:35
	...  actual_start  2024-01-10T08:00
	...  actual_end  2024-01-10T12:30
	...  status  Completed
PS-011  is a  ProductionSchedule
	...  manufacturing_order  MO-004
	...  technological_step  1
	...  task  Cut Raw Material
	...  machine  CNC-Mill-01
	...  scheduled_start  2024-01-16T08:00
	...  scheduled_end  2024-01-16T15:30
	...  actual_start  2024-01-16T08:00
	...  actual_end  2024-01-16T15:25
	...  status  Completed
PS-012  is a  ProductionSchedule
	...  manufacturing_order  MO-004
	...  technological_step  2
	...  task  Mill Slot
	...  machine  CNC-Mill-01
	...  scheduled_start  2024-01-17T08:00
	...  scheduled_end  2024-01-17T14:30
	...  actual_start  2024-01-17T08:10
	...  actual_end  2024-01-17T14:20
	...  status  Completed
PS-013  is a  ProductionSchedule
	...  manufacturing_order  MO-004
	...  technological_step  3
	...  task  Polish Surface
	...  machine  Painting-Booth-01
	...  scheduled_start  2024-01-18T08:00
	...  scheduled_end  2024-01-18T16:45
	...  actual_start  2024-01-18T08:05
	...  actual_end  2024-01-18T16:40
	...  status  Completed
PS-014  is a  ProductionSchedule
	...  manufacturing_order  MO-005
	...  technological_step  1
	...  task  Cut Raw Material
	...  machine  CNC-Mill-02
	...  scheduled_start  2024-01-22T08:00
	...  scheduled_end  2024-01-22T13:00
	...  actual_start  2024-01-22T08:00
	...  actual_end  2024-01-22T12:55
	...  status  Completed
PS-015  is a  ProductionSchedule
	...  manufacturing_order  MO-005
	...  technological_step  2
	...  task  Drill Holes
	...  machine  Lathe-01
	...  scheduled_start  2024-01-22T13:30
	...  scheduled_end  2024-01-22T16:00
	...  actual_start  2024-01-22T13:30
	...  actual_end  2024-01-22T15:50
	...  status  Completed
PS-016  is a  ProductionSchedule
	...  manufacturing_order  MO-005
	...  technological_step  3
	...  task  Polish Surface
	...  machine  Painting-Booth-01
	...  scheduled_start  2024-01-23T08:00
	...  scheduled_end  2024-01-23T15:45
	...  actual_start  2024-01-23T08:00
	...  actual_end  NULL
	...  status  In Progress`
		); 
	}
	
	version(/+$DIDE_REGION firebird+/all)
	{
		auto firebird_test()
		{
			import firebird; 
			
			test_makeDBSchema; 
			
			
			return TestCase(
				schema:
				`TestEntity is an Entity`,
				data:
				`"Hello World" is a TestEntity`
			); 
		} 
		
		
	}
} 
string replaceNonLeadingTabsWithDoubleSpaces(string s)
=> s.splitLines.map!((s){
	const tabs = s.countUntil!`a!='\t'`.max(0); 
	return s[0..tabs]~s[tabs..$].replace("\t", "  "); 
}).join("\n"); 

struct AMDBNode
{
	enum showETypeInEntity 	= (常!(bool)(0)),
	showEntitiesInEType	= (常!(bool)(1)), /+Todo: implement this with a custom node!+/
	showTargetEntityInAssociation 	= (常!(bool)(1)); 
	
	AMDB.Explorer assoc; //contains `db` and `idx`
	
	auto db()
	=> assoc.db; auto idx()
	=> assoc.idx; 
	
	//Todo: Generate the is* functions by a mixin automatically!  `alias this` seems too dangerous here.
	
	bool isRoot()
	=> assoc.isNull; /+
		Todo: This must go. 
		Null is just null null. And the root subnode is populated from outside.
	+/
	
	string name()
	=> assoc.sourceOrThis.text; string verb()
	=> assoc.verb.text; string typeName()
	=> assoc.target.sourceOrThis.text; 
	bool isEType()
	=> assoc.isEType; bool isDType()
	=> assoc.isDType; bool isType()
	=> assoc.isType; bool isAType()
	=> assoc.isAType; bool isInverseVerb()
	=> assoc.isInverseVerb; 
	
	bool isEntity()
	=> assoc.isEntity; bool isAttribute()
	=> assoc.isAttribute; 
	
	bool opened; 
	AMDBNode[] subNodes; 
	
	/+
		Todo: There is a matrix here:
			Rows: AType, EType, DType, etc
			Columns:  canOpen(), open(), UI()
	+/
	
	void close()
	{
		opened = false; 
		subNodes = []; 
	} 	 void toggle()
	{
		if(opened)	close; 
		else	open; 
	} 	
	
	@property bool canOpen()
	{
		if(isRoot)	{ return db.hasAnyTypes; }
		else if(isAType)	{
			return assoc.target.isAssociation ||
			db.exploreATypes.filter!((a)=>(a.source.idx==this.idx)).any; 
		}
		else if(isEType)	{
			return db.exploreATypes.filter!((a)=>(a.source.idx==this.idx)).any ||
			db.exploreETypes.filter!((a)=>(a.target.idx==this.idx)).any ||
			assoc.hasInverseVerbs
			/+
				Todo: Must optimize all these searches 
				and make it clearer/centralized.
			+/; 
		}
		else if(isDType)	{ return db.exploreDTypes.filter!((a)=>(a.target.idx==this.idx)).any; }
		else if(isInverseVerb)	{ return true; }
		else if(isEntity)	{
			return showETypeInEntity 
			|| !db.findAssociationsBySource(idx).empty; 
		}
		else if(isAttribute)	{
			return showTargetEntityInAssociation && assoc.target.isEntity
			|| !db.findAssociationsBySource(idx).empty; 
		}
		return false; 
	} 
	
	static auto sortedNodes(alias sortBy, R)(R input)
	=> input	.array/+Opt: This allocates the db too! Uses 4x more memory+/
		.sort!((a, b)=>(sortBy(a) < sortBy(b)))
		.map!((a)=>(AMDBNode(a)))/+Opt: This uses even more, but it's the final form.+/
		.array; 
	static auto sortByIdx(R)(R input) => sortedNodes!((a)=>(a.source.idx))(input); 
	static auto sortByText(R)(R input) => sortedNodes!((a)=>(a.sourceOrThis.text))(input); 
	
	void open()
	{
		if(/+canOpen && +/opened.chkSet)
		{
			if(isRoot)
			{
				subNodes 	= sortByText(db.exploreDTypes.filter!((a)=>(!a.target.isAssociation)))
					~ sortByIdx(db.exploreETypes.filter!((a)=>(!a.target.isAssociation))); 
			}
			else if(isAType)
			{
				subNodes = []; 
				subNodes ~= sortByIdx(db.exploreATypes.filter!((a)=>(a.source.idx==this.idx))); 
				if(assoc.target.isAssociation) subNodes ~= AMDBNode(assoc.target); 
			}
			else if(isEType)
			{
				subNodes 	= sortByIdx(db.exploreATypes.filter!((a)=>(a.source.idx==this.idx)))
					~ sortByIdx(db.exploreETypes.filter!((a)=>(a.target.idx==this.idx))); 
				if(auto inverseVerbIndices = db.getInverseVerbATypes_of_EType(this.idx))
				subNodes ~= (*inverseVerbIndices).map!((a)=>(AMDBNode(db.explore(a)))).array; 
			}
			else if(isDType)
			{ subNodes 	= sortByIdx(db.exploreDTypes.filter!((a)=>(a.target.idx==this.idx))); }
			else if(isInverseVerb)
			{ subNodes = [AMDBNode(assoc.source.source)]; }
			else if(isEntity)
			{
				subNodes 	= ((showETypeInEntity)?([AMDBNode(assoc.target)]):([]))
					~ sortByIdx(db.findAssociationsBySource(idx).map!((idx)=>(db.explore(idx)))); 
			}
			else if(isAttribute)
			{
				subNodes = 	((
					showTargetEntityInAssociation &&
					assoc.target.isEntity
				)?([AMDBNode(assoc.target)]):([]))
					~ sortByIdx(db.findAssociationsBySource(idx).map!((idx)=>(db.explore(idx)))); 
				/+Todo: Do inverse attributes too!+/
				//Todo: Handle single/multiple cardinality too with custom attribute list nodes
				//Todo: Research way of storage for ordered, unordered and sorted sequences!
			}
		}
	} 
	
	void UI(void delegate() onEntitiesClicked)
	{
		with(im)
		{
			void Icon(string name, int hue)
			{ Img(File(i`c:\dl\red_$(name).png?shiftHUE=$(hue)`.text)); Spacer(fh/4); } 
			if(isRoot)	{ Icon(`brick`, -60); Text("Types"); }
			else if(isAType)	{
				Icon(`right_down_arrow`, assoc.target.isDType ? -120 : -60); 
				Text(assoc.verb.text, ", ", assoc.target.sourceOrThis.text); 
			}
			else if(isEType)	{
				Icon(`brick`, -60); Text(name); Spacer(fh/4); 
				if(Btn(i" $(db.getEntityCount_of_EType(idx, true)) ".text))
				{ onEntitiesClicked(); }
			}
			else if(isDType)	{ Icon(`brick`, -120); Text(name); }
			else if(isInverseVerb)	{
				Icon(`left_up_arrow`, -60); 
				Text(assoc.target.text, ", ", assoc.source.source.source.text); 
			}
			else if(isEntity)	{
				Icon(`brick`, 60); Text(assoc.source); 
				if(Btn("Dump")) { clipboard.text = assoc.dump; beep; }
			}
			else if(isAttribute)	{
				Icon(`right_down_arrow`, 30); 
				Text(assoc.verb.verb, ", ", assoc.target.sourceOrThis); 
				if(Btn("Dump")) { clipboard.text = assoc.dump; beep; }
			}
			else	{ Text({ style.fontColor = clGray; }, i" (assoc: $(assoc.idx))"); }
		}
	} 
	
	
} 

class AMDBTreeView : VirtualTreeView!AMDBNode
{} 

class AMDBSchemaTreeView : AMDBTreeView
{
	this(AMDB db)
	{
		AMDBNode rootNode; rootNode.assoc.db = db; rootNode.opened = true; 
		auto rootEType = db.explore(db.get("Entity")); 
		rootNode.subNodes = 	AMDBNode.sortByText(db.exploreDTypes.filter!((a)=>(!a.target.isAssociation)))
			~((rootEType)?([AMDBNode(rootEType)]):([])); 
		
		showBullet = true, showRoot = false; 
		root = rootNode; 
		
		if(rootEType) root.subNodes.back.open; 
	} 
} 

class AMDBDataTreeView : AMDBTreeView
{
	this(R)(AMDB db, R indices)
	{
		AMDBNode rootNode; rootNode.assoc.db = db; rootNode.opened = true; 
		rootNode.subNodes = indices.map!((idx)=>(AMDBNode(db.explore(idx)))).array; 
		
		showBullet = true, showRoot = false; 
		root = rootNode; 
	} 
} 

class MainForm : UIWindow
{
	mixin autoCreate; mixin SetupMegaShader!""; 
	
	enum NumPanels = 1; 
	AMDB db; 
	AMDBTreeView[NumPanels] schemaTreeView, dataTreeView; 
	
	override void onCreate()
	{
		caption = "AMDB Management Studio"; 
		
		static if((常!(bool)(1))) testSER, testSentenceProcessor; 
		
		
		const 	cases 	= mixin((
			(表([
				[q{(常!(bool)(1))},q{types}],
				[q{(常!(bool)(0))},q{cars}],
				[q{(常!(bool)(1))},q{animals}],
				[q{(常!(bool)(1))},q{leds}],
				[q{(常!(bool)(1))},q{factory}],
				[q{(常!(bool)(1))},q{firebird_test}],
			]))
		).調!(GEN_Selection!testCases)),
			batches 	= 2; 
		db = new AMDB; 
		foreach(batch; 0..batches)
		{ db.schema(cases.map!((a)=>(a.schema)).join("\n").replaceNonLeadingTabsWithDoubleSpaces/+Todo: implement nonleading tab handling in sentence parser+/); }
		if((常!(bool)(0))) db.streamDump.print; 
		if((常!(bool)(0))) db.streamBytes.saveTo(File(`c:\dl\test.amdb`)); 
		
		foreach(batch; 0..batches)
		{
			db.data(cases.retro.map!((a)=>(a.data)).join("\n").replaceNonLeadingTabsWithDoubleSpaces/+Todo: implement nonleading tab handling in sentence parser+/); 
			if((常!(bool)(0))) db.streamBytes.saveTo(File(i`c:\dl\test_data_$(batch).amdb`.text)); 
		}
		if((常!(bool)(0))) db.streamDump.print; 
		
		foreach(panelIdx; 0..NumPanels)
		{
			schemaTreeView[panelIdx] 	= new AMDBSchemaTreeView(db),
			dataTreeView[panelIdx] 	= new AMDBDataTreeView(db, AMDB.Idx[].init); 
		}
	} 
	override void onUpdate()
	{
		showFPS = (互!((bool),(0),(0x5BD83898B722))); 
		with(im)
		{
			foreach(panelIdx; 0..NumPanels)
			{
				Panel(
					PanelPosition.leftClient, ((panelIdx).名!q{id}),
					{
						void initTreeView()
						{
							with(flags) {
								clipSubCells 	= (常!(bool)(1)),
								wordWrap 	= (常!(bool)(0)),
								hScrollState 	= mixin(舉!((ScrollState),q{auto_})),
								vScrollState 	= mixin(舉!((ScrollState),q{auto_})); 
							}
							width 	= (clientWidth/2-1.35*fh)/NumPanels * .92, 
							height 	= clientHeight-2*fh; 
						} 
						
						Row(
							{
								Grp(
									"Schema",
									{
										schemaTreeView[panelIdx].UI
										(
											{ initTreeView; },
											((AMDBNode* node) {
												node.UI(
													onEntitiesClicked: 
													{
														with(node.db)
														dataTreeView[panelIdx] = new AMDBDataTreeView
															(node.db, findAssociationsByVerbTarget(get(mixin(舉!((SysVerb),q{instance_of}))), node.idx)); 
													}
												); 
											})
										); 
									}
									,((1).名!q{id})
								); 
								Grp(
									"Data",
									{
										dataTreeView[panelIdx].UI
										(
											{ initTreeView; },
											((AMDBNode* node) { node.UI(onEntitiesClicked : { beep; }); })
										); 
									}
									,((2).名!q{id})
								); 
							}
						); 
					}
				); 
			}
		}
	} 
} 
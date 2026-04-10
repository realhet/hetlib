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

enum TREEVIEW_GUI_APP 	= (常!(bool)(1)); 

static if(!TREEVIEW_GUI_APP)
{ void main() { console({ testCases.firebird_test; print("DONE"); }); } }


import het.ui, het.amdb, het.firebird; 

version(/+$DIDE_REGION+/all) {}




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
			with(
				DBSchemaImporter
				(
					`c:\Program Files\Firebird\Firebird_2_5\examples\empbuild\EMPLOYEE.FDB`, 
					"SYSDBA", "masterkey"
				)
			)
			{
				clipboard.text = generateScript; 
				
				with(db) (查((位!()),iq{},iq{select * from employee})).formatTable(mixin(舉!((TableStyle),q{norton}))).print; 
			}
			
			string amdbSchema, amdbData; 
			static if((常!(bool)(1)))
			{
				{
					auto db = new FbDatabase(`c:\Program Files\Firebird\Firebird_2_5\examples\empbuild\EMPLOYEE.FDB`, "SYSDBA", "masterkey"); scope(exit) db.free; 
					auto tr = db.startTransaction; scope(exit) tr.free; 
					DBSchemaImporter sch; 
					
					amdbSchema ~= `Short is an Int
ISC_BLOB is a String
ISC_ARRAY is a String`~"\n"; 
					
					void 查(Args...)(LOCATION_t loc, Args args)
					{
						if(0) { sch.addTable(tr.查!Args(loc, args)); (*sch.actTable).print; }
						
						//print; 
						//res.formatTable(TableStyle.norton).print; 
						
						auto res = tr.查!Args(loc, args); 
						string ETypeName = res.fields[0].relName.sanitizeDLangTypeIdentifier.singularize; 
						amdbSchema ~= ETypeName~" is an Entity\n"; 
						foreach(f; res.fields.vars)
						{ amdbSchema ~= "\t..."~f.aliasName.sanitizeDLangFieldIdentifier~"  "~f.baseDType.capitalize~"\n"; }
						amdbSchema ~= "\n"; 
						
						int idx; 
						foreach(row; res)
						{
							amdbData ~= i"$(ETypeName)_$(idx++)  is a  $(ETypeName)\n".text; 
							foreach(f; res.fields.vars)
							{ if(!f.isNull) amdbData ~= i"\t...$(f.aliasName.sanitizeDLangFieldIdentifier)  $(f.toPlainText.quoted)\n".text; }
						}
					} 
					{
						(查((位!()),iq{},iq{
							SELECT 	COUNTRY	AS "country"	/+Type: /+Code: string+/ PrimaryKey(0) Examples: /+Code: "USA", "England", "Canada"+/+/,
								CURRENCY	AS "currency"	/+Type: /+Code: string+/ Examples: /+Code: "Dollar", "Pound", "CdnDlr"+/+/
							FROM COUNTRY AS "Country"
						})); 
						(查((位!()),iq{},iq{
							SELECT 	JOB_CODE	AS "job_code"	/+Type: /+Code: string+/ PrimaryKey(0) Examples: /+Code: "CEO", "CFO", "VP"+/+/,
								JOB_GRADE	AS "job_grade"	/+Type: /+Code: short+/ PrimaryKey(1) Examples: /+Code: short(1), short(2), short(3)+/+/,
								JOB_COUNTRY	AS "job_country"	/+Type: /+Code: string+/ PrimaryKey(2) ForeignKey(0, COUNTRY.COUNTRY) Examples: /+Code: "USA", "England", "Japan"+/+/,
								JOB_TITLE	AS "job_title"	/+Type: /+Code: string+/ Examples: /+Code: "Chief Executive Officer", "Chief Financial Officer", "Vice President"+/+/,
								MIN_SALARY	AS "min_salary"	/+Type: /+Code: double+/ Examples: /+Code: 130000.00, 85000.00, 80000.00+/+/,
								MAX_SALARY	AS "max_salary"	/+Type: /+Code: double+/ Examples: /+Code: 250000.00, 140000.00, 130000.00+/+/,
								JOB_REQUIREMENT	AS "job_requirement"	/+Type: /+Code: Nullable!(ISC_BLOB)+/ Examples: /+Code: Nullable!(ISC_BLOB)(ISC_BLOB(129:241)), Nullable!(ISC_BLOB)(ISC_BLOB(129:243)), Nullable!(ISC_BLOB)(ISC_BLOB(129:251))+/+/,
								LANGUAGE_REQ	AS "language_req"	/+Type: /+Code: Nullable!(ISC_ARRAY)+/ Examples: /+Code: Nullable!(ISC_ARRAY).init, Nullable!(ISC_ARRAY)(ISC_ARRAY(129:31)), Nullable!(ISC_ARRAY)(ISC_ARRAY(129:33))+/+/
							FROM JOB AS "Job"
						})); 
						(查((位!()),iq{},iq{
							SELECT 	DEPT_NO	AS "dept_no"	/+Type: /+Code: string+/ PrimaryKey(0) Examples: /+Code: "000", "100", "600"+/+/,
								DEPARTMENT	AS "department"	/+Type: /+Code: string+/ Examples: /+Code: "Corporate Headquarters", "Sales and Marketing", "Engineering"+/+/,
								HEAD_DEPT	AS "head_dept"	/+Type: /+Code: Nullable!(string)+/ ForeignKey(0, DEPARTMENT.DEPT_NO) Examples: /+Code: Nullable!(string).init, Nullable!(string)("000"), Nullable!(string)("100")+/+/,
								MNGR_NO	AS "mngr_no"	/+Type: /+Code: Nullable!(short)+/ ForeignKey(0, EMPLOYEE.EMP_NO) Examples: /+Code: Nullable!(short)(short(105)), Nullable!(short)(short(85)), Nullable!(short)(short(2))+/+/,
								BUDGET	AS "budget"	/+Type: /+Code: Nullable!(double)+/ Examples: /+Code: Nullable!(double)(1000000.00), Nullable!(double)(2000000.00), Nullable!(double)(1100000.00)+/+/,
								LOCATION	AS "location"	/+Type: /+Code: Nullable!(string)+/ Examples: /+Code: Nullable!(string)("Monterey"), Nullable!(string)("San Francisco"), Nullable!(string)("Burlington, VT")+/+/,
								PHONE_NO	AS "phone_no"	/+Type: /+Code: Nullable!(string)+/ Examples: /+Code: Nullable!(string)("(408) 555-1234"), Nullable!(string)("(415) 555-1234"), Nullable!(string)("(802) 555-1234")+/+/
							FROM DEPARTMENT AS "Department"
						})); 
						(查((位!()),iq{},iq{
							SELECT 	EMP_NO	AS "emp_no"	/+Type: /+Code: short+/ PrimaryKey(0) Examples: /+Code: short(2), short(4), short(5)+/+/,
								FIRST_NAME	AS "first_name"	/+Type: /+Code: string+/ Examples: /+Code: "Robert", "Bruce", "Kim"+/+/,
								LAST_NAME	AS "last_name"	/+Type: /+Code: string+/ Examples: /+Code: "Nelson", "Young", "Lambert"+/+/,
								PHONE_EXT	AS "phone_ext"	/+Type: /+Code: Nullable!(string)+/ Examples: /+Code: Nullable!(string)("250"), Nullable!(string)("233"), Nullable!(string)("22")+/+/,
								HIRE_DATE	AS "hire_date"	/+Type: /+Code: DateTime+/ Examples: /+Code: DateTime(1988, 12, 28, 0, 0, 0), DateTime(1989, 2, 6, 0, 0, 0), DateTime(1989, 4, 5, 0, 0, 0)+/+/,
								DEPT_NO	AS "dept_no"	/+Type: /+Code: string+/ ForeignKey(0, DEPARTMENT.DEPT_NO) Examples: /+Code: "600", "621", "130"+/+/,
								JOB_CODE	AS "job_code"	/+Type: /+Code: string+/ ForeignKey(0, JOB.JOB_CODE) Examples: /+Code: "VP", "Eng", "Mktg"+/+/,
								JOB_GRADE	AS "job_grade"	/+Type: /+Code: short+/ ForeignKey(1, JOB.JOB_GRADE) Examples: /+Code: short(2), short(3), short(4)+/+/,
								JOB_COUNTRY	AS "job_country"	/+Type: /+Code: string+/ ForeignKey(2, JOB.JOB_COUNTRY) Examples: /+Code: "USA", "England", "Canada"+/+/,
								SALARY	AS "salary"	/+Type: /+Code: double+/ Examples: /+Code: 105900.00, 97500.00, 102750.00+/+/,
								FULL_NAME	AS "full_name"	/+Type: /+Code: Nullable!(string)+/ Examples: /+Code: Nullable!(string)("Nelson, Robert"), Nullable!(string)("Young, Bruce"), Nullable!(string)("Lambert, Kim")+/+/
							FROM EMPLOYEE AS "Employee"
						})); 
						(查((位!()),iq{},iq{
							SELECT 	PO_NUMBER	AS "po_number"	/+Type: /+Code: string+/ PrimaryKey(0) Examples: /+Code: "V91E0210", "V92E0340", "V92J1003"+/+/,
								CUST_NO	AS "cust_no"	/+Type: /+Code: int+/ ForeignKey(0, CUSTOMER.CUST_NO) Examples: /+Code: 1004, 1010, 1012+/+/,
								SALES_REP	AS "sales_rep"	/+Type: /+Code: Nullable!(short)+/ ForeignKey(0, EMPLOYEE.EMP_NO) Examples: /+Code: Nullable!(short)(short(11)), Nullable!(short)(short(61)), Nullable!(short)(short(118))+/+/,
								ORDER_STATUS	AS "order_status"	/+Type: /+Code: string+/ Examples: /+Code: "shipped", "open", "waiting"+/+/,
								ORDER_DATE	AS "order_date"	/+Type: /+Code: DateTime+/ Examples: /+Code: DateTime(1991, 3, 4, 0, 0, 0), DateTime(1992, 10, 15, 0, 0, 0), DateTime(1992, 7, 26, 0, 0, 0)+/+/,
								SHIP_DATE	AS "ship_date"	/+Type: /+Code: Nullable!(DateTime)+/ Examples: /+Code: Nullable!(DateTime)(DateTime(1991, 3, 5, 0, 0, 0)), Nullable!(DateTime)(DateTime(1992, 10, 16, 0, 0, 0)), Nullable!(DateTime)(DateTime(1992, 8, 4, 0, 0, 0))+/+/,
								DATE_NEEDED	AS "date_needed"	/+Type: /+Code: Nullable!(DateTime)+/ Examples: /+Code: Nullable!(DateTime).init, Nullable!(DateTime)(DateTime(1992, 10, 17, 0, 0, 0)), Nullable!(DateTime)(DateTime(1992, 9, 15, 0, 0, 0))+/+/,
								PAID	AS "paid"	/+Type: /+Code: Nullable!(string)+/ Examples: /+Code: Nullable!(string)("y"), Nullable!(string)("n")+/+/,
								QTY_ORDERED	AS "qty_ordered"	/+Type: /+Code: int+/ Examples: /+Code: 10, 7, 15+/+/,
								TOTAL_VALUE	AS "total_value"	/+Type: /+Code: double+/ Examples: /+Code: 5000.00, 70000.00, 2985.00+/+/,
								DISCOUNT	AS "discount"	/+Type: /+Code: float+/ Examples: /+Code: 0.1f, 0f, 0.2f+/+/,
								ITEM_TYPE	AS "item_type"	/+Type: /+Code: string+/ Examples: /+Code: "hardware", "software", "other"+/+/,
								AGED	AS "aged"	/+Type: /+Code: Nullable!(double)+/ Examples: /+Code: Nullable!(double)(1.000000000), Nullable!(double)(9.000000000), Nullable!(double)(33.000000000)+/+/
							FROM SALES AS "Sale"
						})); 
						(查((位!()),iq{},iq{
							SELECT 	EMP_NO	AS "emp_no"	/+Type: /+Code: Nullable!(short)+/ Examples: /+Code: Nullable!(short)(short(12)), Nullable!(short)(short(105)), Nullable!(short)(short(85))+/+/,
								FIRST_NAME	AS "first_name"	/+Type: /+Code: Nullable!(string)+/ Examples: /+Code: Nullable!(string)("Terri"), Nullable!(string)("Oliver H."), Nullable!(string)("Mary S.")+/+/,
								LAST_NAME	AS "last_name"	/+Type: /+Code: Nullable!(string)+/ Examples: /+Code: Nullable!(string)("Lee"), Nullable!(string)("Bender"), Nullable!(string)("MacDonald")+/+/,
								PHONE_EXT	AS "phone_ext"	/+Type: /+Code: Nullable!(string)+/ Examples: /+Code: Nullable!(string)("256"), Nullable!(string)("255"), Nullable!(string)("477")+/+/,
								LOCATION	AS "location"	/+Type: /+Code: Nullable!(string)+/ Examples: /+Code: Nullable!(string)("Monterey"), Nullable!(string)("San Francisco"), Nullable!(string)("Burlington, VT")+/+/,
								PHONE_NO	AS "phone_no"	/+Type: /+Code: Nullable!(string)+/ Examples: /+Code: Nullable!(string)("(408) 555-1234"), Nullable!(string)("(415) 555-1234"), Nullable!(string)("(802) 555-1234")+/+/
							FROM PHONE_LIST AS "Phone_list"
						})); 
						(查((位!()),iq{},iq{
							SELECT 	PROJ_ID	AS "proj_id"	/+Type: /+Code: string+/ PrimaryKey(0) Examples: /+Code: "VBASE", "DGPII", "GUIDE"+/+/,
								PROJ_NAME	AS "proj_name"	/+Type: /+Code: string+/ Examples: /+Code: "Video Database", "DigiPizza", "AutoMap"+/+/,
								PROJ_DESC	AS "proj_desc"	/+Type: /+Code: Nullable!(ISC_BLOB)+/ Examples: /+Code: Nullable!(ISC_BLOB)(ISC_BLOB(133:6)), Nullable!(ISC_BLOB)(ISC_BLOB(133:8)), Nullable!(ISC_BLOB)(ISC_BLOB(133:10))+/+/,
								TEAM_LEADER	AS "team_leader"	/+Type: /+Code: Nullable!(short)+/ ForeignKey(0, EMPLOYEE.EMP_NO) Examples: /+Code: Nullable!(short)(short(45)), Nullable!(short)(short(24)), Nullable!(short)(short(20))+/+/,
								PRODUCT	AS "product"	/+Type: /+Code: string+/ Examples: /+Code: "software", "other", "hardware"+/+/
							FROM PROJECT AS "Project"
						})); 
						(查((位!()),iq{},iq{
							SELECT 	EMP_NO	AS "emp_no"	/+Type: /+Code: short+/ PrimaryKey(0) ForeignKey(0, EMPLOYEE.EMP_NO) Examples: /+Code: short(144), short(113), short(24)+/+/,
								PROJ_ID	AS "proj_id"	/+Type: /+Code: string+/ PrimaryKey(1) ForeignKey(0, PROJECT.PROJ_ID) Examples: /+Code: "DGPII", "VBASE", "GUIDE"+/+/
							FROM EMPLOYEE_PROJECT AS "Employee_project"
						})); 
						(查((位!()),iq{},iq{
							SELECT 	FISCAL_YEAR	AS "fiscal_year"	/+Type: /+Code: int+/ PrimaryKey(0) Examples: /+Code: 1994, 1993, 1995+/+/,
								PROJ_ID	AS "proj_id"	/+Type: /+Code: string+/ PrimaryKey(1) ForeignKey(0, PROJECT.PROJ_ID) Examples: /+Code: "GUIDE", "MAPDB", "HWRII"+/+/,
								DEPT_NO	AS "dept_no"	/+Type: /+Code: string+/ PrimaryKey(2) ForeignKey(0, DEPARTMENT.DEPT_NO) Examples: /+Code: "100", "671", "621"+/+/,
								QUART_HEAD_CNT	AS "quart_head_cnt"	/+Type: /+Code: Nullable!(ISC_ARRAY)+/ Examples: /+Code: Nullable!(ISC_ARRAY)(ISC_ARRAY(135:24)), Nullable!(ISC_ARRAY)(ISC_ARRAY(135:26)), Nullable!(ISC_ARRAY)(ISC_ARRAY(135:28))+/+/,
								PROJECTED_BUDGET	AS "projected_budget"	/+Type: /+Code: Nullable!(double)+/ Examples: /+Code: Nullable!(double)(200000.00), Nullable!(double)(450000.00), Nullable!(double)(20000.00)+/+/
							FROM PROJ_DEPT_BUDGET AS "Proj_dept_budget"
						})); 
						(查((位!()),iq{},iq{
							SELECT 	EMP_NO	AS "emp_no"	/+Type: /+Code: short+/ PrimaryKey(0) ForeignKey(0, EMPLOYEE.EMP_NO) Examples: /+Code: short(28), short(2), short(4)+/+/,
								CHANGE_DATE	AS "change_date"	/+Type: /+Code: DateTime+/ PrimaryKey(1) Examples: /+Code: DateTime(1992, 12, 15, 0, 0, 0), DateTime(1993, 9, 8, 0, 0, 0), DateTime(1993, 12, 20, 0, 0, 0)+/+/,
								UPDATER_ID	AS "updater_id"	/+Type: /+Code: string+/ PrimaryKey(2) Examples: /+Code: "admin2", "elaine", "tj"+/+/,
								OLD_SALARY	AS "old_salary"	/+Type: /+Code: double+/ Examples: /+Code: 20000.00, 98000.00, 90000.00+/+/,
								PERCENT_CHANGE	AS "percent_change"	/+Type: /+Code: double+/ Examples: /+Code: 10, 8.061199999999999, 8.333299999999999+/+/,
								NEW_SALARY	AS "new_salary"	/+Type: /+Code: Nullable!(double)+/ Examples: /+Code: Nullable!(double)(22000), Nullable!(double)(105899.976), Nullable!(double)(97499.97)+/+/
							FROM SALARY_HISTORY AS "Salary_history"
						})); 
						(查((位!()),iq{},iq{
							SELECT 	CUST_NO	AS "cust_no"	/+Type: /+Code: int+/ PrimaryKey(0) Examples: /+Code: 1001, 1002, 1003+/+/,
								CUSTOMER	AS "customer"	/+Type: /+Code: string+/ Examples: /+Code: "Signature Design", "Dallas Technologies", "Buttle, Griffith and Co."+/+/,
								CONTACT_FIRST	AS "contact_first"	/+Type: /+Code: Nullable!(string)+/ Examples: /+Code: Nullable!(string)("Dale J."), Nullable!(string)("Glen"), Nullable!(string)("James")+/+/,
								CONTACT_LAST	AS "contact_last"	/+Type: /+Code: Nullable!(string)+/ Examples: /+Code: Nullable!(string)("Little"), Nullable!(string)("Brown"), Nullable!(string)("Buttle")+/+/,
								PHONE_NO	AS "phone_no"	/+Type: /+Code: Nullable!(string)+/ Examples: /+Code: Nullable!(string)("(619) 530-2710"), Nullable!(string)("(214) 960-2233"), Nullable!(string)("(617) 488-1864")+/+/,
								ADDRESS_LINE1	AS "address_line1"	/+Type: /+Code: Nullable!(string)+/ Examples: /+Code: Nullable!(string)("15500 Pacific Heights Blvd."), Nullable!(string)("P. O. Box 47000"), Nullable!(string)("2300 Newbury Street")+/+/,
								ADDRESS_LINE2	AS "address_line2"	/+Type: /+Code: Nullable!(string)+/ Examples: /+Code: Nullable!(string).init, Nullable!(string)("Suite 101"), Nullable!(string)("Suite 150")+/+/,
								CITY	AS "city"	/+Type: /+Code: Nullable!(string)+/ Examples: /+Code: Nullable!(string)("San Diego"), Nullable!(string)("Dallas"), Nullable!(string)("Boston")+/+/,
								STATE_PROVINCE	AS "state_province"	/+Type: /+Code: Nullable!(string)+/ Examples: /+Code: Nullable!(string)("CA"), Nullable!(string)("TX"), Nullable!(string)("MA")+/+/,
								COUNTRY	AS "country"	/+Type: /+Code: Nullable!(string)+/ ForeignKey(0, COUNTRY.COUNTRY) Examples: /+Code: Nullable!(string)("USA"), Nullable!(string)("England"), Nullable!(string)("Hong Kong")+/+/,
								POSTAL_CODE	AS "postal_code"	/+Type: /+Code: Nullable!(string)+/ Examples: /+Code: Nullable!(string)("92121"), Nullable!(string)("75205"), Nullable!(string)("02115")+/+/,
								ON_HOLD	AS "on_hold"	/+Type: /+Code: Nullable!(string)+/ Examples: /+Code: Nullable!(string).init, Nullable!(string)("*")+/+/
							FROM CUSTOMER AS "Customer"
						})); 
						
					}
				}
			}
			
			auto testCase = TestCase(
				schema:
				q{
					Country is an Entity
						...currency String
					
					Job is an Entity
						...title String
						...grade Int
							...country Country
								...min salary  Double
								...max salary  Double
					
					Employee is an Entity
						...first name  String
						...last name  String
						...job key  Job
							...grade key  grade
								...country key  country
						...salary  Double
					
					Employee2 is an Entity
						...job link  Job
				}
				.outdent,
				data:
				q{
					USA is a Country
					Germany is a Country
					
					CEO is a Job
						...grade 4
							...country USA
								...min salary  80000
								...max salary  100000
						...grade 5
							...country USA
								...min salary  140000
								...max salary  190000
							...country Germany
								...min salary  60000
								...max salary  70000
					
					EMP_0 is an Employee
						...first name  Példa
						...last name  Béla
						...job key  CEO...grade key  4...country key  USA
						...salary 90000
					
					EMP_1 is an Employee
						...first name  Teszt
						...last name  Elek
						...job key  CEO...grade key  5...country key  Germany
						...salary 80000
					
				}
				.outdent
			); 
			//auto testCase = TestCase(schema: amdbSchema, data:`"Hello World" is a TestEntity`); 
			
			(testCase.schema ~"\n\n"~ testCase.data).saveTo(`c:\dl\test.txt.amdb`); 
			return testCase; 
		} 
		
		
	}
} 
static if(TREEVIEW_GUI_APP)
{
	string replaceNonLeadingTabsWithDoubleSpaces(string s)
	=> s.splitLines.map!((s){
		const tabs = s.countUntil!`a!='\t'`.max(0); 
		return s[0..tabs]~s[tabs..$].replace("\t", "  "); 
	}).join("\n"); 
	
	struct AMDBNode
	{
		enum showETypeInEntity 	= (常!(bool)(1)),
		showEntitiesInEType	= (常!(bool)(1)), /+Todo: implement this with a custom node!+/
		showTargetEntityInAssociation 	= (常!(bool)(1)); 
		
		AMDB.Explorer assoc; //contains `db` and `idx`
		bool isReferenced; 
		
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
				/+
					auto base = ((assoc.target.isATypeCompositeKey)?(assoc.target):(assoc)); 
					return db.exploreATypes.filter!((a)=>(a.source.idx==base.idx)).any ||
					base.target.isAssociation && !base.target.isATypeCompositeKey; 
				+/
				if(db.exploreATypes.filter!((a)=>(a.source.idx==this.idx)).any) return true; 
				/+
					if(assoc.target.isAssociation)
					{
						if(assoc.target.isATypeCompositeKey)
						{
							if(assoc.target.target.isAssociation)
							return true; 
						}
						else
						{ return true; }
					}
				+/
				if(assoc.isATypeCompositeKey)
				{
					if(assoc.target.target.isAssociation)
					return true; 
				}
				else
				{
					if(assoc.target.isAssociation)
					return true; 
				}
				return false; 
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
					if(assoc.verb.text=="job key")
					{
						((0x8BFE3898B722).檢(assoc.isATypeCompositeKey)); 
						((0x8C393898B722).檢(assoc.target.isATypeCompositeKey)); 
						((0x8C7B3898B722).檢(assoc.dump)); 
						/+
							AI: /+
								User: Please reformat this so I can see the structure:
								/+Code: (2038):assoc((1988):assoc((1979):"Employee", (14):"is a subtype of", (66):"Entity"), (2030):"job key", (1888):assoc((1884):"Job", (14):"is a subtype of", (66):"Entity"))+/
							+/
							/+
								Assistant: /+
									Structured: /+
										Code: (2038):assoc(
											(1988):assoc(
												(1979):"Employee",
												(14):"is a subtype of",
												(66):"Entity"
											),
											(2030):"job key",
											(1888):assoc(
												(1884):"Job",
												(14):"is a subtype of",
												(66):"Entity"
											)
										)
									+/
								+/
								
								/+Note: Usage(prompt_hit: 0, prompt_miss: 205, completion: 101, HUF: 0.03, price: 100%)+/
							+/
						+/
					}
					
					if(assoc.verb.text=="grade key")
					{
						((0x90323898B722).檢(assoc.isATypeCompositeKey)); 
						((0x906D3898B722).檢(assoc.target.isATypeCompositeKey)); 
						((0x90AF3898B722).檢(assoc.dump)); 
						/+
							AI: /+
								User: Please reformat this so I can see the structure:
								/+Code: (2055):assoc((2038):assoc((1988):assoc((1979):"Employee", (14):"is a subtype of", (66):"Entity"), (2030):"job key", (1888):assoc((1884):"Job", (14):"is a subtype of", (66):"Entity")), (2045):"grade key", (1914):assoc((1888):assoc((1884):"Job", (14):"is a subtype of", (66):"Entity"), (1908):"grade", (1):"Int"))+/
							+/
							/+
								Assistant: /+
									Structured: /+
										Code: (2055): assoc(
											(2038): assoc(
												(1988): assoc(
													(1979): "Employee",
													(14): "is a subtype of",
													(66): "Entity"
												),
												(2030): "job key",
												(1888): assoc(
													(1884): "Job",
													(14): "is a subtype of",
													(66): "Entity"
												)
											),
											(2045): "grade key",
											(1914): assoc(
												(1888): assoc(
													(1884): "Job",
													(14): "is a subtype of",
													(66): "Entity"
												),
												(1908): "grade",
												(1): "Int"
											)
										) 
									+/
								+/
								
								/+Note: Usage(prompt_hit: 128, prompt_miss: 267, completion: 193, HUF: 0.04, price: 100%)+/
							+/
						+/
					}
					
					if(assoc.verb.text=="country key")
					{
						((0x96453898B722).檢(assoc.isATypeCompositeKey)); 
						((0x96803898B722).檢(assoc.target.isATypeCompositeKey)); 
						((0x96C23898B722).檢(assoc.dump)); 
						/+
							AI: /+
								User: Please reformat this so I can see the structure:
								/+Code: (2074):assoc((2055):assoc((2038):assoc((1988):assoc((1979):"Employee", (14):"is a subtype of", (66):"Entity"), (2030):"job key", (1888):assoc((1884):"Job", (14):"is a subtype of", (66):"Entity")), (2045):"grade key", (1914):assoc((1888):assoc((1884):"Job", (14):"is a subtype of", (66):"Entity"), (1908):"grade", (1):"Int")), (2062):"country key", (1929):assoc((1914):assoc((1888):assoc((1884):"Job", (14):"is a subtype of", (66):"Entity"), (1908):"grade", (1):"Int"), (1921):"country", (1861):assoc((1853):"Country", (14):"is a subtype of", (66):"Entity")))+/
							+/
							/+
								Assistant: /+
									Structured: /+
										Code: (2074):assoc(
											(2055):assoc(
												(2038):assoc(
													(1988):assoc(
														(1979):"Employee",
														(14):"is a subtype of",
														(66):"Entity"
													),
													(2030):"job key",
													(1888):assoc(
														(1884):"Job",
														(14):"is a subtype of",
														(66):"Entity"
													)
												),
												(2045):"grade key",
												(1914):assoc(
													(1888):assoc(
														(1884):"Job",
														(14):"is a subtype of",
														(66):"Entity"
													),
													(1908):"grade",
													(1):"Int"
												)
											),
											(2062):"country key",
											(1929):assoc(
												(1914):assoc(
													(1888):assoc(
														(1884):"Job",
														(14):"is a subtype of",
														(66):"Entity"
													),
													(1908):"grade",
													(1):"Int"
												),
												(1921):"country",
												(1861):assoc(
													(1853):"Country",
													(14):"is a subtype of",
													(66):"Entity"
												)
											)
										)
									+/
								+/
								
								/+Note: Usage(prompt_hit: 128, prompt_miss: 371, completion: 344, HUF: 0.07, price: 100%)+/
							+/
						+/
					}
					
					/+
						auto base = ((assoc.target.isATypeCompositeKey)?(assoc.target):(assoc)); 
						subNodes = sortByIdx(db.exploreATypes.filter!((a)=>(a.source.idx==base.idx))); 
						if(base.target.isAssociation && !base.target.isATypeCompositeKey)
						subNodes ~= AMDBNode(base.target); 
					+/
					
					subNodes = sortByIdx(db.exploreATypes.filter!((a)=>(a.source.idx==this.idx))); 
					/+
						if(assoc.target.isAssociation)
						{
							if(assoc.target.isATypeCompositeKey)
							{
								if(assoc.target.target.isAssociation)
								subNodes ~= AMDBNode(assoc.target.target); 
							}
							else
							{ subNodes ~= AMDBNode(assoc.target); }
						}
					+/
					
					if(assoc.isATypeCompositeKey)
					{
						if(assoc.target.target.isAssociation)
						subNodes ~= AMDBNode(assoc.target.target, isReferenced: true); 
					}
					else
					{
						if(assoc.target.isAssociation)
						subNodes ~= AMDBNode(assoc.target, isReferenced: true); 
					}
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
					subNodes = 	sortByIdx(db.findAssociationsBySource(idx).map!((idx)=>(db.explore(idx))))
						~((showETypeInEntity)?([AMDBNode(assoc.target, isReferenced: true)]):([])); 
				}
				else if(isAttribute)
				{
					subNodes = 	sortByIdx(db.findAssociationsBySource(idx).map!((idx)=>(db.explore(idx))))
						~((
						showTargetEntityInAssociation &&
						assoc.target.isEntity
					)?([AMDBNode(assoc.target, isReferenced: true)]):([])); 
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
				if(isReferenced) Text("👉"); 
				if(isRoot)	{ Icon(`brick`, -60); Text("Types"); }
				else if(isAType)	{
					if(assoc.isATypeCompositeKey)
					{
						Text("🔑"); 
						Icon(`right_down_arrow`, assoc.target.target.isDType ? -120 : -60); 
						Text(assoc.verb.text, ", ", assoc.target.target.sourceOrThis.text); 
					}
					else
					{
						Icon(`right_down_arrow`, assoc.target.isDType ? -120 : -60); 
						Text(assoc.verb.text, ", ", assoc.target.sourceOrThis.text); 
					}
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
					/+if(Btn("Dump")) { clipboard.text = assoc.dump; beep; }+/
				}
				else if(isAttribute)	{
					Icon(`right_down_arrow`, 30); 
					Text(assoc.verb.verb, ", ", assoc.target.sourceOrThis); 
					/+if(Btn("Dump")) { clipboard.text = assoc.dump; beep; }+/
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
					[q{(常!(bool)(1))},q{cars}],
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
			if((常!(bool)(0))) db.streamBytes.saveTo(File(`c:\dl\test.raw.amdb`)); 
			
			foreach(batch; 0..batches)
			{
				db.data(cases.retro.map!((a)=>(a.data)).join("\n").replaceNonLeadingTabsWithDoubleSpaces/+Todo: implement nonleading tab handling in sentence parser+/); 
				if((常!(bool)(0))) db.streamBytes.saveTo(File(i`c:\dl\test_data_$(batch).amdb`.text)); 
			}
			if((常!(bool)(0))) db.streamDump.print; 
			if((常!(bool)(1))) db.streamBytes.saveTo(File(`c:\dl\test.raw.amdb`)); 
			
			foreach(panelIdx; 0..NumPanels)
			{
				schemaTreeView[panelIdx] 	= new AMDBSchemaTreeView(db),
				dataTreeView[panelIdx] 	= new AMDBDataTreeView(db, AMDB.Idx[].init); 
			}
		} 
		override void onUpdate()
		{
			showFPS = (互!((bool),(0),(0xB7EF3898B722))); 
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
}
/+
	Assistant: Plan: FBDB → AMDB Workflow
	
	  Phase 1 — Input Spec
	
	  1. Define a DLang spec structure that describes:
						 - Connection info (db handle or DSN)
						 - A list of sources (tables/views/queries)
						 - Optional overrides:
										 - Entity name override (uppercase first letter)
										 - Field name override (lowercase, spaces allowed)
	      - PK/FK rules:
										 - Auto‑detect for tables
										 - Manual for views/queries
	  2.	Create a loader function per source, or a single registry function that returns all sources as an array.
		Keep it static so it’s compile‑time friendly.
	
	  ———
	
		 Phase 2 — Schema Extraction
		 3. Connect + introspect
	
	  - For each source:
						 - Get field list (from XSQLDA)
						 - For tables: query PK/FK metadata (RDB$...)
						 - For views/queries: use provided manual PK/FK rules
	
	  4. Normalize names
						 - Entity names → Uppercase first char
						 - Field names → lowercase first char
						 - Apply optional custom overrides
	
	  ———
	
		 Phase 3 — AMDB Schema Creation
		 5. Create all entities first
	
		 - No fields yet
		 - This guarantees FK targets exist
	
	  6. Create all fields
						 - Simple scalar fields
						 - FK fields as references to entities (already created)
	  7. Lock + serialize schema
						 - Save AMDB schema
						 - Save FBDB → AMDB mapping
						 - These become stable artifacts for future runs
	
	  ———
	
		 Phase 4 — Data Load
		 8. Row fetch for each source
	
		 - Use query order from input list
		 - For each row:
						 - Ensure entity instance exists
						 - Create associations (fields) separately
	
	  9. Deferred association queue
						 - If association fails due to missing target entity, enqueue
						 - After first pass, retry queue until stable or error
	
	  ———
	
		 Phase 5 — Validate + Output
		 10. Consistency checks
		 - Check unresolved FK queue
		 - Check missing PKs
		 - Check field type mismatches
	
	  11.	Write AMDB output
		- Schema + data in AMDB byte stream
		- Human‑readable text export (for debugging)
	
	  ———
	
		 Phase 6 — First UI integration
		 12. Load AMDB in tree view
		 - Use your existing viewer
		 - Begin with text interaction only
	
	  ———
+/
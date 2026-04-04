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
	
	/+
		auto northwind_mssql()
		{
			/+Link: https://github.com/microsoft/sql-server-samples/blob/master/samples/databases/northwind-pubs/instnwnd.sql+/
			import het.arsd.mssql; 
			auto db = new MsSql
			(
				(
					"NxsCE+0vJPA850XlbcM+C/cPCEYZPwT9BBc77DY2HhLuLuog8SksDgn9CD3JlbhKt1WtXqxf"~
					"/CwSYcZsvWWccJJ5sXrPUbClYrVLv3K6UrdJw06y-OczKxH6IwaBgUV7SPfMxIF+yP5Fus"
				)
				.combobulate ~ ";Database=northwind"
			); 
			
			/+
			Connect from commandline:
			/+Console: sqlcmd -S "(localdb)\MSSQLLocalDB"+/
		+/
			
			TestCase res; 
			void schema(string s) { res.schema~="\n"~s.outdent~"\n"; } 
			void data(string s) { res.data~="\n"~s.outdent~"\n"; } 
			
			version(/+$DIDE_REGION Category+/all)
			{
				schema(
					q{
						Category is an Entity
							... id	Int /+IDENTITY(1,1)+/
						//	... name	String
							... description	String
						/+Todo: 	... picture	Bitmap  - truncation bug. No mssql binary support yet.+/
					}
				); 
				foreach(r; db.query(q{SELECT CategoryID, CategoryName, Description FROM Categories}))
				{
					data(
						iq{
							$(r[1].quoted) is a Category
								... id $(r[0]) 
								... description $(r[2].quoted)
						}.text
					); 
				}
			}
			version(/+$DIDE_REGION Customer+/all)
			{
				schema
				(
					q{
						Customer is an Entity
							... company name	String
							... contact name	String
							... contact title	String
							... address	String
							... city	String
							... region	String
							... postal code	String
							... country	String
							... phone	String
							... fax	String
					}
				); foreach(
					r; db.query
					(
						q{
							SELECT 
							CustomerID, 
							CompanyName, 
							ContactName, 
							ContactTitle, 
							Address, 
							City, 
							Region, 
							PostalCode, 
							Country, 
							Phone, 
							Fax 
							FROM Customers
						}
					)
				) {
					data
					(
						iq{
							$(r[0].quoted) is a Customer
								... company name	$(r[1].quoted)
								... contact name	$(r[2].quoted)
								... contact title	$(r[3].quoted)
								... address	$(r[4].quoted)
								... region	$(r[5].quoted)
								... postal code	$(r[6].quoted)
								... country	$(r[7].quoted)
								... phone	$(r[8].quoted)
								... fax	$(r[9].quoted)
						}.text
					); 
				}
				
			}
			
			version(/+$DIDE_REGION Employee+/all)
			{
				schema
				(
					q{
						Employee is an Entity
							... id	Int
							... last name	String
							... first name	String
							... title	String
							... title of courtesy	String
							... birth date	DateTime
							... hire date	DateTime
							... address	String
							... city	String
							... region	String
							... postal code	String
							... country	String
							... home phone	String
							... extension	String
						//	... photo	Binary
							... notes	String
							... reports to	Employee
							... photo path	String
					}
				); foreach(
					r; db.query
					(
						q{
							SELECT
							EmployeeID,
							LastName,
							FirstName,
							Title,
							TitleOfCourtesy,
							BirthDate,
							HireDate,
							Address,
							City,
							Region,
							PostalCode,
							Country,
							HomePhone,
							Extension,
							/*Photo,*/
							Notes,
							PhotoPath
							FROM Employees
						}
					)
				) {
					data
					(
						iq{
							$("EM_"~r[0].text) is an Employee
								... id	$(r[0])
								... last name	$(r[1].quoted)
								... first name	$(r[2].quoted)
								... title	$(r[3].quoted)
								... title of courtesy	$(r[4].quoted)
								... birth date	$(r[5].quoted)
								... hire date	$(r[6].quoted)
								... address	$(r[7].quoted)
								... city	$(r[8].quoted)
								... region	$(r[9].quoted)
								... postal code	$(r[10].quoted)
								... country	$(r[11].quoted)
								... home phone	$(r[12].quoted)
								... extension	$(r[13].quoted)
								... notes	$(r[14].quoted)
								... photo path	$(r[15].quoted)
						}.text
					); 
				}
				foreach(r; db.query(q{SELECT EmployeeID, ReportsTo from Employees}))
				if(!r[1].isNull) data(iq{$("EM_"~r[0]) is an Employee ... reports to  $("EM_"~r[1])}.text); 
			}
			
			
			/+
			res.schema = 
			q{
				/+Associative Model Of Data schemas for MSSQL Northwind database+/
				
				
				/+
				CustomerCustomerDemo is an Associative Entity
					... customer	Customer
					... customer type	CustomerDemographic
				CustomerDemographic is an Entity
					... customer type id	String
					... customer description	String
				
				
				EmployeeTerritory is an Associative Entity
					... employee	Employee
					... territory	Territory
				OrderDetail is an Entity
					... order	Order
					... product	Product
					... unit price	Decimal /+...default(0)+/
					... quantity	SmallInt /+...default(1)+/
					... discount	Float /+...default(0)+/ /+0..1 range+/
				Order is an Entity
					... order id	Int /+IDENTITY(1,1)+/
					... customer	Customer
					... employee	Employee
					... order date	DateTime
					... required date	DateTime
					... shipped date	DateTime
					... ship via	Shipper
					... freight	Decimal /+...default(0)+/
					... ship name	String
					... ship address	String
					... ship city	String
					... ship region	String
					... ship postal code	String
					... ship country	String
				Product is an Entity
					... product id	Int /+IDENTITY(1,1)+/
					... product name	String
					... supplier	Supplier
					... category	Category
					... quantity per unit	String
					... unit price	Decimal /+...default(0)+/
					... units in stock	SmallInt /+...default(0)+/
					... units on order	SmallInt /+...default(0)+/
					... reorder level	SmallInt /+...default(0)+/
					... discontinued	Bool /+...default(false)+/
				Region is an Entity
					... region id	Int /+IDENTITY(1,1)+/
					... region description	String
				Shipper is an Entity
					... shipper id	Int /+IDENTITY(1,1)+/
					... company name	String
					... phone	String
				Supplier is an Entity
					... supplier id	Int /+IDENTITY(1,1)+/
					... company name	String
					... contact name	String
					... contact title	String
					... address	String
					... city	String
					... region	String
					... postal code	String
					... country	String
					... phone	String
					... fax	String
					... home page	String
				Territory is an Entity
					... territory id	String
					... territory description	String
					... region	Region
			+/
			}
			.outdent; 
		+/
			
			
			return res; 
		}; 
	+/
	
	
	/+
		MySql root: j`qEL[0OrL<zc8@p
		het: E9)[Y.O,n18#a$3b
		
		# Extract to C:\mysql57
		cd C:\mysql57\bin
		mysqld --initialize-insecure --console
		mysqld --install MySQL57
		net start MySQL57
		mysql -u root -p
		# Press Enter for no password, then:
		ALTER USER 'root'@'localhost' IDENTIFIED BY 'newpassword';
		
		ALTER USER 'root'@'localhost' IDENTIFIED BY 'j`qEL[0OrL<zc8@p';
	+/
	
	
	version(/+$DIDE_REGION firebird+/all)
	{
		auto firebird_test()
		{
			import firebird; 
			
			test_FbDatabase; 
			
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
/+
	AI: /+
		User: I've dumped the table column definitions from an MSSQL database with this DLang program:
		/+
			Code: foreach(table; tableNames)
			{
				res~="Table: "~table~" -----------------"; 
				res~="columns:"; 
				foreach(
					row; db.query
					(
						i`SELECT COLUMN_NAME,
		DATA_TYPE,
		IS_NULLABLE,
		CHARACTER_MAXIMUM_LENGTH,
		NUMERIC_PRECISION,
		NUMERIC_SCALE,
		COLUMN_DEFAULT,
		ORDINAL_POSITION
	FROM INFORMATION_SCHEMA.COLUMNS
	WHERE TABLE_NAME = '$(table)'
	ORDER BY ORDINAL_POSITION;`.text
					)
				)
				{ res ~= row.text.safeUTF8; }
				res~="data:"; 
				foreach(row; db.query(i`SELECT   TOP 10 * FROM [$(table)]`.text))
				{ res ~= row.text.safeUTF8; }
			}
		+/
		
		This is the generated dump:
		/+
			Table: Categories -----------------
			columns:
			[CategoryID, int, NO, , 10, 0, , 1]
			[CategoryName, nvarchar, NO, 15, , , , 2]
			[Description, ntext, YES, 1073741823, , , , 3]
			[Picture, image, YES, 2147483647, , , , 4]
			data:
			Table: CustomerCustomerDemo -----------------
			columns:
			[CustomerID, nchar, NO, 5, , , , 1]
			[CustomerTypeID, nchar, NO, 10, , , , 2]
			data:
			Table: CustomerDemographics -----------------
			columns:
			[CustomerTypeID, nchar, NO, 10, , , , 1]
			[CustomerDesc, ntext, YES, 1073741823, , , , 2]
			data:
			Table: Customers -----------------
			columns:
			[CustomerID, nchar, NO, 5, , , , 1]
			[CompanyName, nvarchar, NO, 40, , , , 2]
			[ContactName, nvarchar, YES, 30, , , , 3]
			[ContactTitle, nvarchar, YES, 30, , , , 4]
			[Address, nvarchar, YES, 60, , , , 5]
			[City, nvarchar, YES, 15, , , , 6]
			[Region, nvarchar, YES, 15, , , , 7]
			[PostalCode, nvarchar, YES, 10, , , , 8]
			[Country, nvarchar, YES, 15, , , , 9]
			[Phone, nvarchar, YES, 24, , , , 10]
			[Fax, nvarchar, YES, 24, , , , 11]
			data:
			[ALFKI, Alfreds Futterkiste, Maria Anders, Sales Representative, Obere Str. 57, Berlin, , 12209, Germany, 030-0074321, 030-0076545]
			[ANATR, Ana Trujillo Emparedados y helados, Ana Trujillo, Owner, Avda. de la Constituci� 2222, M�ico D.F., , 05021, Mexico, (5) 555-4729, (5) 555-3745]
			[ANTON, Antonio Moreno Taquer�, Antonio Moreno, Owner, Mataderos  2312, M�ico D.F., , 05023, Mexico, (5) 555-3932, ]
			[AROUT, Around the Horn, Thomas Hardy, Sales Representative, 120 Hanover Sq., London, , WA1 1DP, UK, (171) 555-7788, (171) 555-6750]
			[BERGS, Berglunds snabbk�, Christina Berglund, Order Administrator, Berguvsv�en  8, Lule� , S-958 22, Sweden, 0921-12 34 65, 0921-12 34 67]
			[BLAUS, Blauer See Delikatessen, Hanna Moos, Sales Representative, Forsterstr. 57, Mannheim, , 68306, Germany, 0621-08460, 0621-08924]
			[BLONP, Blondesddsl p�e et fils, Fr��ique Citeaux, Marketing Manager, 24, place Kl�er, Strasbourg, , 67000, France, 88.60.15.31, 88.60.15.32]
			[BOLID, B�ido Comidas preparadas, Mart� Sommer, Owner, C/ Araquil, 67, Madrid, , 28023, Spain, (91) 555 22 82, (91) 555 91 99]
			[BONAP, Bon app', Laurence Lebihan, Owner, 12, rue des Bouchers, Marseille, , 13008, France, 91.24.45.40, 91.24.45.41]
			[BOTTM, Bottom-Dollar Markets, Elizabeth Lincoln, Accounting Manager, 23 Tsawassen Blvd., Tsawassen, BC, T2F 8M4, Canada, (604) 555-4729, (604) 555-3745]
			Table: Employees -----------------
			columns:
			[EmployeeID, int, NO, , 10, 0, , 1]
			[LastName, nvarchar, NO, 20, , , , 2]
			[FirstName, nvarchar, NO, 10, , , , 3]
			[Title, nvarchar, YES, 30, , , , 4]
			[TitleOfCourtesy, nvarchar, YES, 25, , , , 5]
			[BirthDate, datetime, YES, , , , , 6]
			[HireDate, datetime, YES, , , , , 7]
			[Address, nvarchar, YES, 60, , , , 8]
			[City, nvarchar, YES, 15, , , , 9]
			[Region, nvarchar, YES, 15, , , , 10]
			[PostalCode, nvarchar, YES, 10, , , , 11]
			[Country, nvarchar, YES, 15, , , , 12]
			[HomePhone, nvarchar, YES, 24, , , , 13]
			[Extension, nvarchar, YES, 4, , , , 14]
			[Photo, image, YES, 2147483647, , , , 15]
			[Notes, ntext, YES, 1073741823, , , , 16]
			[ReportsTo, int, YES, , 10, 0, , 17]
			[PhotoPath, nvarchar, YES, 255, , , , 18]
			data:
			Table: EmployeeTerritories -----------------
			columns:
			[EmployeeID, int, NO, , 10, 0, , 1]
			[TerritoryID, nvarchar, NO, 20, , , , 2]
			data:
			[1, 06897]
			[1, 19713]
			[2, 01581]
			[2, 01730]
			[2, 01833]
			[2, 02116]
			[2, 02139]
			[2, 02184]
			[2, 40222]
			[3, 30346]
			Table: Order Details -----------------
			columns:
			[OrderID, int, NO, , 10, 0, , 1]
			[ProductID, int, NO, , 10, 0, , 2]
			[UnitPrice, money, NO, , 19, 4, ((0)), 3]
			[Quantity, smallint, NO, , 5, 0, ((1)), 4]
			[Discount, real, NO, , 24, , ((0)), 5]
			data:
			[10248, 11, 14.0000, 12, 0.0]
			[10248, 42, 9.8000, 10, 0.0]
			[10248, 72, 34.8000, 5, 0.0]
			[10249, 14, 18.6000, 9, 0.0]
			[10249, 51, 42.4000, 40, 0.0]
			[10250, 41, 7.7000, 10, 0.0]
			[10250, 51, 42.4000, 35, 0.15000001]
			[10250, 65, 16.8000, 15, 0.15000001]
			[10251, 22, 16.8000, 6, 5.0000001E-2]
			[10251, 57, 15.6000, 15, 5.0000001E-2]
			Table: Orders -----------------
			columns:
			[OrderID, int, NO, , 10, 0, , 1]
			[CustomerID, nchar, YES, 5, , , , 2]
			[EmployeeID, int, YES, , 10, 0, , 3]
			[OrderDate, datetime, YES, , , , , 4]
			[RequiredDate, datetime, YES, , , , , 5]
			[ShippedDate, datetime, YES, , , , , 6]
			[ShipVia, int, YES, , 10, 0, , 7]
			[Freight, money, YES, , 19, 4, ((0)), 8]
			[ShipName, nvarchar, YES, 40, , , , 9]
			[ShipAddress, nvarchar, YES, 60, , , , 10]
			[ShipCity, nvarchar, YES, 15, , , , 11]
			[ShipRegion, nvarchar, YES, 15, , , , 12]
			[ShipPostalCode, nvarchar, YES, 10, , , , 13]
			[ShipCountry, nvarchar, YES, 15, , , , 14]
			data:
			[10248, VINET, 5, 1996-07-04 00:00:00.000, 1996-08-01 00:00:00.000, 1996-07-16 00:00:00.000, 3, 32.3800, Vins et alcools Chevalier, 59 rue de l'Abbaye, Reims, , 51100, France]
			[10249, TOMSP, 6, 1996-07-05 00:00:00.000, 1996-08-16 00:00:00.000, 1996-07-10 00:00:00.000, 1, 11.6100, Toms Spezialit�en, Luisenstr. 48, M�ster, , 44087, Germany]
			[10250, HANAR, 4, 1996-07-08 00:00:00.000, 1996-08-05 00:00:00.000, 1996-07-12 00:00:00.000, 2, 65.8300, Hanari Carnes, Rua do Pa�, 67, Rio de Janeiro, RJ, 05454-876, Brazil]
			[10251, VICTE, 3, 1996-07-08 00:00:00.000, 1996-08-05 00:00:00.000, 1996-07-15 00:00:00.000, 1, 41.3400, Victuailles en stock, 2, rue du Commerce, Lyon, , 69004, France]
			[10252, SUPRD, 4, 1996-07-09 00:00:00.000, 1996-08-06 00:00:00.000, 1996-07-11 00:00:00.000, 2, 51.3000, Supr�es d�ices, Boulevard Tirou, 255, Charleroi, , B-6000, Belgium]
			[10253, HANAR, 3, 1996-07-10 00:00:00.000, 1996-07-24 00:00:00.000, 1996-07-16 00:00:00.000, 2, 58.1700, Hanari Carnes, Rua do Pa�, 67, Rio de Janeiro, RJ, 05454-876, Brazil]
			[10254, CHOPS, 5, 1996-07-11 00:00:00.000, 1996-08-08 00:00:00.000, 1996-07-23 00:00:00.000, 2, 22.9800, Chop-suey Chinese, Hauptstr. 31, Bern, , 3012, Switzerland]
			[10255, RICSU, 9, 1996-07-12 00:00:00.000, 1996-08-09 00:00:00.000, 1996-07-15 00:00:00.000, 3, 148.3300, Richter Supermarkt, Starenweg 5, Gen�e, , 1204, Switzerland]
			[10256, WELLI, 3, 1996-07-15 00:00:00.000, 1996-08-12 00:00:00.000, 1996-07-17 00:00:00.000, 2, 13.9700, Wellington Importadora, Rua do Mercado, 12, Resende, SP, 08737-363, Brazil]
			[10257, HILAA, 4, 1996-07-16 00:00:00.000, 1996-08-13 00:00:00.000, 1996-07-22 00:00:00.000, 3, 81.9100, HILARION-Abastos, Carrera 22 con Ave. Carlos Soublette #8-35, San Crist�al, T�hira, 5022, Venezuela]
			Table: Products -----------------
			columns:
			[ProductID, int, NO, , 10, 0, , 1]
			[ProductName, nvarchar, NO, 40, , , , 2]
			[SupplierID, int, YES, , 10, 0, , 3]
			[CategoryID, int, YES, , 10, 0, , 4]
			[QuantityPerUnit, nvarchar, YES, 20, , , , 5]
			[UnitPrice, money, YES, , 19, 4, ((0)), 6]
			[UnitsInStock, smallint, YES, , 5, 0, ((0)), 7]
			[UnitsOnOrder, smallint, YES, , 5, 0, ((0)), 8]
			[ReorderLevel, smallint, YES, , 5, 0, ((0)), 9]
			[Discontinued, bit, NO, , , , ((0)), 10]
			data:
			[1, Chai, 1, 1, 10 boxes x 20 bags, 18.0000, 39, 0, 10, 0]
			[2, Chang, 1, 1, 24 - 12 oz bottles, 19.0000, 17, 40, 25, 0]
			[3, Aniseed Syrup, 1, 2, 12 - 550 ml bottles, 10.0000, 13, 70, 25, 0]
			[4, Chef Anton's Cajun Seasoning, 2, 2, 48 - 6 oz jars, 22.0000, 53, 0, 0, 0]
			[5, Chef Anton's Gumbo Mix, 2, 2, 36 boxes, 21.3500, 0, 0, 0, 1]
			[6, Grandma's Boysenberry Spread, 3, 2, 12 - 8 oz jars, 25.0000, 120, 0, 25, 0]
			[7, Uncle Bob's Organic Dried Pears, 3, 7, 12 - 1 lb pkgs., 30.0000, 15, 0, 10, 0]
			[8, Northwoods Cranberry Sauce, 3, 2, 12 - 12 oz jars, 40.0000, 6, 0, 0, 0]
			[9, Mishi Kobe Niku, 4, 6, 18 - 500 g pkgs., 97.0000, 29, 0, 0, 1]
			[10, Ikura, 4, 8, 12 - 200 ml jars, 31.0000, 31, 0, 0, 0]
			Table: Region -----------------
			columns:
			[RegionID, int, NO, , 10, 0, , 1]
			[RegionDescription, nchar, NO, 50, , , , 2]
			data:
			[1, Eastern																								                  ]
			[2, Western																								                  ]
			[3, Northern																								                  ]
			[4, Southern																								                  ]
			Table: Shippers -----------------
			columns:
			[ShipperID, int, NO, , 10, 0, , 1]
			[CompanyName, nvarchar, NO, 40, , , , 2]
			[Phone, nvarchar, YES, 24, , , , 3]
			data:
			[1, Speedy Express, (503) 555-9831]
			[2, United Package, (503) 555-3199]
			[3, Federal Shipping, (503) 555-9931]
			Table: Suppliers -----------------
			columns:
			[SupplierID, int, NO, , 10, 0, , 1]
			[CompanyName, nvarchar, NO, 40, , , , 2]
			[ContactName, nvarchar, YES, 30, , , , 3]
			[ContactTitle, nvarchar, YES, 30, , , , 4]
			[Address, nvarchar, YES, 60, , , , 5]
			[City, nvarchar, YES, 15, , , , 6]
			[Region, nvarchar, YES, 15, , , , 7]
			[PostalCode, nvarchar, YES, 10, , , , 8]
			[Country, nvarchar, YES, 15, , , , 9]
			[Phone, nvarchar, YES, 24, , , , 10]
			[Fax, nvarchar, YES, 24, , , , 11]
			[HomePage, ntext, YES, 1073741823, , , , 12]
			data:
			[1, Exotic Liquids, Charlotte Cooper, Purchasing Manager, 49 Gilbert St., London, , EC1 4SD, UK, (171) 555-2222, , ]
			[2, New Orleans Cajun Delights, Shelley Burke, Order Administrator, P.O. Box 78934, New Orleans, LA, 70117, USA, (100) 555-4822, , #CAJUN.HTM#]
			[3, Grandma Kelly's Homestead, Regina Murphy, Sales Representative, 707 Oxford Rd., Ann Arbor, MI, 48104, USA, (313) 555-5735, (313) 555-3349, ]
			[4, Tokyo Traders, Yoshi Nagase, Marketing Manager, 9-8 Sekimai Musashino-shi, Tokyo, , 100, Japan, (03) 3555-5011, , ]
			[5, Cooperativa de Quesos 'Las Cabras', Antonio del Valle Saavedra, Export Administrator, Calle del Rosal 4, Oviedo, Asturias, 33007, Spain, (98) 598 76 54, , ]
			[6, Mayumi's, Mayumi Ohno, Marketing Representative, 92 Setsuko Chuo-ku, Osaka, , 545, Japan, (06) 431-7877, , Mayumi's (on the World Wide Web)#http://www.microsoft.com/accessdev/sampleapps/mayumi.htm#]
			[7, Pavlova, Ltd., Ian Devling, Marketing Manager, 74 Rose St. Moonie Ponds, Melbourne, Victoria, 3058, Australia, (03) 444-2343, (03) 444-6588, ]
			[8, Specialty Biscuits, Ltd., Peter Wilson, Sales Representative, 29 King's Way, Manchester, , M14 GSD, UK, (161) 555-4448, , ]
			[9, PB Kn�kebr� AB, Lars Peterson, Sales Agent, Kaloadagatan 13, G�eborg, , S-345 67, Sweden, 031-987 65 43, 031-987 65 91, ]
			[10, Refrescos Americanas LTDA, Carlos Diaz, Marketing Manager, Av. das Americanas 12.890, Sao Paulo, , 5442, Brazil, (11) 555 4640, , ]
			Table: Territories -----------------
			columns:
			[TerritoryID, nvarchar, NO, 20, , , , 1]
			[TerritoryDescription, nchar, NO, 50, , , , 2]
			[RegionID, int, NO, , 10, 0, , 3]
			data:
			[01581, Westboro	                                       , 1]
			[01730, Bedford	                                       ,	1]
			[01833, Georgetow		, 1]
			[02116, Boston	                                       , 1]
			[02139, Cambridge																								                , 1]
			[02184, Braintree																								                , 1]
			[02903, Providence	                                       , 1]
			[03049, Hollis	                                       , 3]
			[03801, Portsmouth	                                       , 3]
			[06897, Wilton	                                       , 1]
		+/
		
		I ask you to generate Associative Model Of Data schemas for these mssql tables.
		
		Here is an example of an Associative Model Of Data schema (this is another database):
		/+
			Code: Employee is an Entity
				... employee id	Int /+IDENTITY(1,1)+/
				... last name	String
				... first name	String
				... title	String
				... title of courtesy 	String
				... birth date	Date
				... hire date	Date
				... address	String
				... city	String
				... region	String
				... postal code	String
				... country	String
				... home phone	String
				... extension	String
				... photo	Bitmap
				... notes	String
				... reports to	Employee
				... photo path	String
			
			Category is an Entity
				... category id	Int /+IDENTITY(1,1)+/
				... category name 	String
				... description	String
				... picture	Bitmap
			
			Customer is an Entity
				... customer id	String
				... company name 	String
				... contact name	String
				... contact title	String
				... address	String
				... city	String
				... region	String
				... postal code	String
				... country	String
				... phone	String
				... fax	String
			
			Shipper is an Entity
				... shipper id	Int /+IDENTITY(1,1)+/
				... company name	String
				... phone	String
			
			Supplier is an Entity
				... supplier id	Int /+IDENTITY(1,1)+/
				... company name 	String
				... contact name	String/+... default""+/
				... contact title	String
				... address	String
				... city	String
				... region	String
				... postal code	String
				... country	String
				... phone	String
				... fax	String
				... home page	String
			
			Order is an Entity
				... order id	Int /+IDENTITY(1,1)+/
				... customer	Customer
				... employee	Employee
				... order date	Date
				... required date	Date
				... shipped date	Date
				... ship via	Shipper
				... freight	Decimal /+...default(0)+/
				... ship name	String
				... ship address	String
				... ship city	String
				... ship region	String
				... ship postal code 	String
				... ship country	String
			
			Product is an Entity
				... product id	Int /+IDENTITY(1,1)+/
				... product name	String
				... supplier	Supplier
				... category	Category
				... quantity per unit 	String
				... unit price	Money 	/+...default(0)+/
				... units in stock	Int 	/+...default(0)+/
				... units on order	Int 	/+...default(0)+/
				... reorder level	Int 	/+...default(0)+/
				... discontinued	Bool 	/+...default(false)+/
			
			OrderDetail is an Entity
				... order	Order
				... product	Product
				... unit price 	Money 	/+...default(0)+/
				... quantity	Int	/+...default(1)+/
				... discount	Float	/+...default(0)+//+0..1 range+/
		+/
		
		So please generate the schemas!
	+/
	/+
		Assistant: /+
			Structured: /+Associative Model Of Data schemas for MSSQL Northwind database+/
			
			Category is an Entity
				... category id	Int /+IDENTITY(1,1)+/
				... category name	String
				... description	String
				... picture	Binary
			CustomerCustomerDemo is an Associative Entity
				... customer	Customer
				... customer type	CustomerDemographic
			CustomerDemographic is an Entity
				... customer type id	String
				... customer description	String
			Customer is an Entity
				... customer id	String
				... company name	String
				... contact name	String
				... contact title	String
				... address	String
				... city	String
				... region	String
				... postal code	String
				... country	String
				... phone	String
				... fax	String
			Employee is an Entity
				... employee id	Int /+IDENTITY(1,1)+/
				... last name	String
				... first name	String
				... title	String
				... title of courtesy	String
				... birth date	DateTime
				... hire date	DateTime
				... address	String
				... city	String
				... region	String
				... postal code	String
				... country	String
				... home phone	String
				... extension	String
				... photo	Binary
				... notes	String
				... reports to	Employee
				... photo path	String
			EmployeeTerritory is an Associative Entity
				... employee	Employee
				... territory	Territory
			OrderDetail is an Entity
				... order	Order
				... product	Product
				... unit price	Decimal /+...default(0)+/
				... quantity	SmallInt /+...default(1)+/
				... discount	Float /+...default(0)+/ /+0..1 range+/
			Order is an Entity
				... order id	Int /+IDENTITY(1,1)+/
				... customer	Customer
				... employee	Employee
				... order date	DateTime
				... required date	DateTime
				... shipped date	DateTime
				... ship via	Shipper
				... freight	Decimal /+...default(0)+/
				... ship name	String
				... ship address	String
				... ship city	String
				... ship region	String
				... ship postal code	String
				... ship country	String
			Product is an Entity
				... product id	Int /+IDENTITY(1,1)+/
				... product name	String
				... supplier	Supplier
				... category	Category
				... quantity per unit	String
				... unit price	Decimal /+...default(0)+/
				... units in stock	SmallInt /+...default(0)+/
				... units on order	SmallInt /+...default(0)+/
				... reorder level	SmallInt /+...default(0)+/
				... discontinued	Bool /+...default(false)+/
			Region is an Entity
				... region id	Int /+IDENTITY(1,1)+/
				... region description	String
			Shipper is an Entity
				... shipper id	Int /+IDENTITY(1,1)+/
				... company name	String
				... phone	String
			Supplier is an Entity
				... supplier id	Int /+IDENTITY(1,1)+/
				... company name	String
				... contact name	String
				... contact title	String
				... address	String
				... city	String
				... region	String
				... postal code	String
				... country	String
				... phone	String
				... fax	String
				... home page	String
			Territory is an Entity
				... territory id	String
				... territory description	String
				... region	Region
		+/
		
		/+Note: Usage(prompt_hit: 64, prompt_miss: 6846, completion: 913, HUF: 1.08, price: 100%)+/
	+/
+/



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
				[q{(常!(bool)(0))},q{types}],
				[q{(常!(bool)(0))},q{cars}],
				[q{(常!(bool)(0))},q{animals}],
				[q{(常!(bool)(0))},q{leds}],
				[q{(常!(bool)(0))},q{factory}],
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
		showFPS = (互!((bool),(0),(0xC01953604E42))); 
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
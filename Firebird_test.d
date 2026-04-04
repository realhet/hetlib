//@exe
//@debug
//@/release

import het, het.firebird; 

void main()
{
	console(
		{
			//test_FbDatabase; 
			
			static if(1)
			{
				auto db = new FbDatabase(File(appPath, "EXAMPLE.FDB").fullName, "SYSDBA", "masterkey", create: true); 
				scope(exit) db.free; 
				
				enum FbFuncts_LOG_enabled = true; 
				
				void dumpRow(Row)(Row row)
				{ static if(FbFuncts.LOG_enabled) row.dataBuf.hexDump.print; } 
				void dumpTable(Table)(Table resultSet)
				{ static if(FbFuncts.LOG_enabled) foreach(row; resultSet) dumpRow(row); } 
				auto _間=init間; 
				static if((常!(bool)(1)))
				version(/+$DIDE_REGION Input binding tests+/all)
				{
					with(db.transaction)
					{
						foreach(i; 0..1)
						{
							execute(iq{SELECT $(1)+$(2) FROM RDB$DATABASE}).each!((r){ dumpRow(r); }); 
							(查((位!()),iq{},iq{SELECT $(1)+$(2) FROM RDB$DATABASE})).each!((r){ dumpRow(r); }); 
							dumpTable (查((位!()),iq{},iq{SELECT $(1)+$(4) FROM RDB$DATABASE})); 
							dumpTable (查 ((位!()),iq{},iq{
								SELECT 
									$(Nullable!int.init),	$(nullable(true)), 
									$(nullable(ubyte(1)))	,$(nullable(byte(-128))),
									$(short(32767)), 	$(ushort(65535)), 
									$(-12345), 	$(4000000000U), 
									$(-1234567890123), 
									$(1.25f), $(π),
									$("Hello Wörld!".Varchar!30), $(`Default 80 char string`)
								FROM RDB$DATABASE
							})); 
						}
					}
				}
				((0x5B01EF13BA2).檢((update間(_間)))); 
				static if((常!(bool)(1)))
				{
					version(/+$DIDE_REGION DateTime+/all)
					{
						with(db.transaction)
						{
							auto q(string style)()
							=> (查 ((位!()),iq{},iq{
								SELECT 
									CURRENT_TIMESTAMP AS "dateTime",
									CAST(CURRENT_TIMESTAMP AS DATE) AS "date",
									CAST(CURRENT_TIMESTAMP AS TIME) AS "time",
									CAST(`2026-03-25 12:34:56.1234` AS TIMESTAMP) AS "dateTime2",
									$(now) AS "dateTimeNow",
									$(now.date) AS "dateNow",
									$(now.time) AS "timeNow"
								FROM RDB$DATABASE
							}))
							.formatTable!style; 
							((0x8411EF13BA2).檢 (q!"json")); 
							((0x86C1EF13BA2).檢 (q!"txt")); 
							((0x8961EF13BA2).檢 (q!"struct")); 
							{
								struct Struct
								{
									DateTime	dateTime; 
									DateTime	date; 
									Time	time; 
									DateTime	dateTime2; 
								} 
								auto rows = [
									Struct(
										dateTime: DateTime(2026, 3, 25, 17, 25, 53.439),
										date: DateTime(2026, 3, 25),
										time: toTime(17, 25, 53.439),
										dateTime2: DateTime(2026, 3, 25, 12, 34, 56.1234)
									)
								]; 
								((0xA751EF13BA2).檢(rows[0].text)); 
								((0xAA41EF13BA2).檢(DateTime(2026, 3, 25, 12, 34, 56.1234).time.value(second).format!"%.4f")); 
							}
						}
					}
				}
				((0xB2D1EF13BA2).檢((update間(_間)))); 
				static if((常!(bool)(1)))
				{
					version(/+$DIDE_REGION Create test table, Insert test data+/all)
					{
						if((常!(bool)(1)))
						{
							ignoreExceptions
							(
								{
									/+Important: Must free all statement/transaction handles around metadata modifications!+/
									db.clearStatementCache; 
									with(db.transaction(modify: true)) (查((位!()),iq{},iq{DROP TABLE test_employees})); 
									db.clearStatementCache; 
								}
							); 
						}
						
						if((常!(bool)(1)))
						{
							with(db.transaction(modify: true))
							(查((位!()),iq{},iq{
								CREATE TABLE test_employees
								(
									emp_id 	INTEGER 	PRIMARY KEY,
									first_name 	VARCHAR(50) 	NOT NULL,
									last_name 	VARCHAR(50) 	NOT NULL,
									department 	VARCHAR(50) 	NOT NULL,
									hire_date 	DATE 	NOT NULL,
									salary 	DECIMAL(10,2) 	NOT NULL,
									null_int	INT
								)
							})); 
						}
						
						if((常!(bool)(1)))
						{
							with(db.transaction(modify: true))
							{
								(查((位!()),iq{},iq{
									INSERT INTO test_employees (emp_id, first_name, last_name, department, hire_date, salary)
									VALUES (1, `John`, `Smith`, `IT`, `2023-01-15`, 65000.00)
								})); 
								(查((位!()),iq{},iq{
									INSERT INTO test_employees (emp_id, first_name, last_name, department, hire_date, salary)
									VALUES (2, `Maria`, `Garcia`, `HR`, `2023-03-20`, 55000.00)
								})); 
								(查((位!()),iq{},iq{
									INSERT INTO test_employees (emp_id, first_name, last_name, department, hire_date, salary)
									VALUES (3, `David`, `Johnson`, `IT`, `2023-02-10`, 72000.00)
								})); 
								(查((位!()),iq{},iq{
									INSERT INTO test_employees (emp_id, first_name, last_name, department, hire_date, salary)
									VALUES (4, `Sarah`, `Williams`, `Finance`, `2023-04-05`, 58000.00)
								})); 
								(查((位!()),iq{},iq{
									INSERT INTO test_employees (emp_id, first_name, last_name, department, hire_date, salary)
									VALUES (5, `Michael`, `Brown`, `IT`, `2023-01-30`, 69000.00)
								})); 
								(查((位!()),iq{},iq{UPDATE test_employees SET null_int = 1234 WHERE emp_id IN (2, 3)})); 
							}
						}
						
						if((常!(bool)(1)))
						{
							try { with(db.transaction) { (查((位!()),iq{},iq{SELECT * FROM test_employees})); }}
							catch(Exception e) ((0x14ED1EF13BA2).檢(e.simpleMsg)); 
						}
					}
				}
				((0x15301EF13BA2).檢((update間(_間)))); 
				static if((常!(bool)(1)))
				{
					version(/+$DIDE_REGION Select speed tests+/all)
					{
						static void verifyDataHash(R)
							(R resultSet)
						{
							size_t h=123; 
							foreach(row; resultSet)
							h = h.mix64(row.dataBuf.hashOf); 
							static size_t h0; 
							if(!h0) h0 = h; 
							enforce(h==h0); 
						} 
						
						
						if((常!(bool)(1)))
						with(db.transaction)
						foreach(i; 0..10_000)
						{
							size_t h=123; 
							foreach(
								row; (查 ((位!()),iq{},iq{
									SELECT * FROM test_employees
									ORDER BY emp_id
								}))
							)
							{ h = h.mix64(row.dataBuf.hashOf); }
							static size_t h0; if(!h0) h0 = h; 
							enforce(h==h0); 
						}
						((0x18521EF13BA2).檢((update間(_間)))); 
						if((常!(bool)(1)))
						with(db.transaction)
						foreach(i; 0..10_000)
						{
							verifyDataHash
							(查 ((位!()),iq{},iq{
								SELECT * FROM test_employees
								ORDER BY emp_id
							})); 
						}
						((0x196F1EF13BA2).檢((update間(_間)))); 
						if((常!(bool)(1)))
						foreach(i; 0..1000)
						with(db.transaction)
						{
							size_t h=123; 
							foreach(
								row; (查 ((位!()),iq{},iq{
									SELECT * FROM test_employees
									ORDER BY emp_id
								}))
							)
							{ h = h.mix64(row.dataBuf.hashOf); }
							static size_t h0; if(!h0) h0 = h; 
							enforce(h==h0); 
						}
						((0x1B1E1EF13BA2).檢((update間(_間)))); 
						if((常!(bool)(1)))
						foreach(i; 0..1000)
						with(db.transaction)
						{
							verifyDataHash
							(查 ((位!()),iq{},iq{
								SELECT * FROM test_employees
								ORDER BY emp_id
							})); 
						}
						((0x1C391EF13BA2).檢((update間(_間)))); 
						
						if((常!(bool)(1)))
						foreach(i; 0..100)
						with(db.transaction)
						foreach(j; 0..100)
						{
							size_t h=123; 
							foreach(
								row; (查 ((位!()),iq{},iq{
									SELECT * FROM test_employees
									ORDER BY emp_id
								}))
							)
							{ h = h.mix64(row.dataBuf.hashOf); }
							static size_t h0; if(!h0) h0 = h; 
							enforce(h==h0); 
						}
						((0x1E091EF13BA2).檢((update間(_間)))); 
						if((常!(bool)(1)))
						foreach(i; 0..100)
						with(db.transaction)
						foreach(j; 0..100)
						{
							verifyDataHash
							(查 ((位!()),iq{},iq{
								SELECT * FROM test_employees
								ORDER BY emp_id
							})); 
						}
						((0x1F3D1EF13BA2).檢((update間(_間)))); 
					}
				}
				((0x1F7D1EF13BA2).檢((update間(_間)))); 
				static if((常!(bool)(1)))
				{
					version(/+$DIDE_REGION Create/Insert/Select/Drop test+/all)
					{
						foreach(i; 0..100)
						{
							if((常!(bool)(1)))
							{
								with(db.transaction(modify: true))
								(查((位!()),iq{},iq{
									CREATE TABLE test_employees2
									(
										emp_id 	INTEGER 	PRIMARY KEY,
										first_name 	VARCHAR(50) 	NOT NULL,
										last_name 	VARCHAR(50) 	NOT NULL,
										department 	VARCHAR(50) 	NOT NULL,
										hire_date 	DATE 	NOT NULL,
										salary 	DECIMAL(10,2) 	NOT NULL
									)
								})); 
							}
							
							if((常!(bool)(1)))
							{
								with(db.transaction(modify: true))
								{
									(查((位!()),iq{},iq{
										INSERT INTO test_employees2 (emp_id, first_name, last_name, department, hire_date, salary)
										VALUES (1, `John`, `Smith`, `IT`, `2023-01-15`, 65000.00)
									})); 
									(查((位!()),iq{},iq{
										INSERT INTO test_employees2 (emp_id, first_name, last_name, department, hire_date, salary)
										VALUES (2, `Maria`, `Garcia`, `HR`, `2023-03-20`, 55000.00)
									})); 
									(查((位!()),iq{},iq{
										INSERT INTO test_employees2 (emp_id, first_name, last_name, department, hire_date, salary)
										VALUES (3, `David`, `Johnson`, `IT`, `2023-02-10`, 72000.00)
									})); 
									(查((位!()),iq{},iq{
										INSERT INTO test_employees2 (emp_id, first_name, last_name, department, hire_date, salary)
										VALUES (4, `Sarah`, `Williams`, `Finance`, `2023-04-05`, 58000.00)
									})); 
									(查((位!()),iq{},iq{
										INSERT INTO test_employees2 (emp_id, first_name, last_name, department, hire_date, salary)
										VALUES (5, `Michael`, `Brown`, `IT`, `2023-01-30`, 69000.00)
									})); 
								}
							}
							if((常!(bool)(1)))
							{
								with(db.transaction)
								{
									(查((位!()),iq{},iq{SELECT * FROM test_employees2})); 
									dumpTable
									(查 ((位!()),iq{},iq{
										SELECT 
											department,
											COUNT(*) AS employee_count,
											AVG(salary) AS avg_salary,
											MIN(salary) AS min_salary,
											MAX(salary) AS max_salary
										FROM test_employees2
										GROUP BY department
										ORDER BY department
									})); dumpTable
									(查 ((位!()),iq{},iq{
										SELECT 
											emp_id,
											first_name AS "First name",
											last_name,
											department,
											hire_date,
											salary
										FROM test_employees2
										ORDER BY emp_id
									})); 
								}
							}
							
							if((常!(bool)(1)))
							{
								/+Important: Must free all statement/transaction handles around metadata modifications!+/
								db.clearStatementCache; 
								with(db.transaction(modify: true)) { (查((位!()),iq{},iq{DROP TABLE test_employees2})); }
								db.clearStatementCache; 
							}
							
							if((常!(bool)(1)))
							{
								try { with(db.transaction) { (查((位!()),iq{},iq{SELECT * FROM test_employees2})); }}
								catch(Exception e) ((0x2C041EF13BA2).檢(e.simpleMsg)); 
							}
						}
					}
				}
				((0x2C511EF13BA2).檢((update間(_間)))); 
				static if((常!(bool)(1)))
				version(/+$DIDE_REGION formatTable tests+/all)
				{
					with(db.transaction)
					{
						version(/+$DIDE_REGION+/all) {
							((0x2D2A1EF13BA2).檢(
								(查 ((位!()),iq{},iq{
									SELECT 
										$(Nullable!int.init),
										$(nullable(true)),
										$(nullable(ubyte(1))),
										$(nullable(byte(-128))),
										$(short(32767)) 	as "i16",
										$(ushort(65535)) 	as "u16",
										$(-12345) 	as "i32",
										$(4000000000U) 	as "u32",
										$(-1234567890123) 	as "i64",
										$(1.25f) /*CCmt*/	as "float",
										$(π) /+DCmt+/	as "double",
										$("Hello Wörld!".Varchar!30), 
										$(`Default 80 char`) || `'str'`
									FROM RDB$DATABASE //lineComment
								}))
								.formatTable!"struct"
							)); 
							
							((0x2FCE1EF13BA2).檢(
								(查 ((位!()),iq{},iq{
									SELECT 
										$(`NUMERIC tests`),
										CAST(1.23456 AS NUMERIC(8, 0)),
										CAST(1.23456 AS NUMERIC(8, 1)),
										CAST(1.23456 AS NUMERIC(8, 2)),
										CAST(1.23456 AS NUMERIC(8, 3)),
										$(`FLOAT tests`),
										CAST(1.2345678e-7 AS FLOAT),
										CAST(1.2345678e-6 AS FLOAT),
										CAST(1.2345678e-5 AS FLOAT),
										CAST(1.2345678e-4 AS FLOAT),
										CAST(1.2345678e-3 AS FLOAT),
										CAST(1.2345678e-2 AS FLOAT),
										CAST(1.2345678e-1 AS FLOAT),
										CAST(1.2345678 AS FLOAT),
										CAST(1.2345678e1 AS FLOAT),
										CAST(1.2345678e2 AS FLOAT),
										CAST(1.2345678e3 AS FLOAT),
										CAST(1.2345678e4 AS FLOAT),
										CAST(1.2345678e5 AS FLOAT),
										CAST(1.2345678e6 AS FLOAT),
										CAST(1.2345678e7 AS FLOAT),
										$(`DOUBLE tests`),
										CAST(1.23456789012345678e-7 AS DOUBLE PRECISION),
										CAST(1.23456789012345678e-6 AS DOUBLE PRECISION),
										CAST(1.23456789012345678e-5 AS DOUBLE PRECISION),
										CAST(1.23456789012345678e-4 AS DOUBLE PRECISION),
										CAST(1.23456789012345678e-3 AS DOUBLE PRECISION),
										CAST(1.23456789012345678e-2 AS DOUBLE PRECISION),
										CAST(1.23456789012345678e-1 AS DOUBLE PRECISION),
										CAST(1.23456789012345678 AS DOUBLE PRECISION),
										CAST(1.23456789012345678e1 AS DOUBLE PRECISION),
										CAST(1.23456789012345678e2 AS DOUBLE PRECISION),
										CAST(1.23456789012345678e3 AS DOUBLE PRECISION),
										CAST(1.23456789012345678e4 AS DOUBLE PRECISION),
										CAST(1.23456789012345678e5 AS DOUBLE PRECISION),
										CAST(1.23456789012345678e6 AS DOUBLE PRECISION),
										CAST(1.23456789012345678e7 AS DOUBLE PRECISION)
									FROM RDB$DATABASE
								}))
								.formatTable!"json"
							)); 
						}
						version(/+$DIDE_REGION+/all) {
							static foreach(style; EnumMemberNames!TableStyle)
							{ print!style; (查((位!()),iq{},iq{SELECT e.*, e.null_int+1000 FROM test_employees e; })).formatTable!(style.text).print; print; }
						}
					}
				}
				((0x385A1EF13BA2).檢((update間(_間)))); 
				static if((常!(bool)(1)))
				{
					version(/+$DIDE_REGION 3 ways to do a query+/all)
					{
						with(db.transaction)
						{
							db.clearStatementCache; 
							string[] tables; 
							void verify() {
								static size_t firstHash; const h = tables.hashOf; 
								if(!firstHash) firstHash = h; enforce(h==firstHash); 
							} 
							foreach(i; 0..3)
							{
								if((常!(bool)(1))) {
									tables = []; foreach(
										row; (查((位!()),iq{},iq{
											SELECT rdb$relation_name /+1+/
												FROM rdb$relations
												ORDER BY rdb$relation_name
										}))
									)
									tables ~= row[0].text; 
								}verify; 
								if((常!(bool)(1))) {
									tables = []; mixin(求each(q{row},q{
										(查((位!()),iq{},iq{
											SELECT rdb$relation_name /+2+/
												FROM rdb$relations
												ORDER BY rdb$relation_name
										}))
									},q{tables ~= row[0].text})); 
								}verify; 
								if((常!(bool)(1))) {
									tables = (查((位!()),iq{},iq{
										SELECT rdb$relation_name /+3+/
											FROM rdb$relations
											ORDER BY rdb$relation_name
									})).toArray!string; 
									print(tables); 
								}verify; 
							}
							enforce(db.statementCache.length==3 /+The 3 query texts are different because of indenting.+/); 
						}
					}
				}
				((0x3DFA1EF13BA2).檢((update間(_間)))); 
				static if((常!(bool)(1)))
				{
					version(/+$DIDE_REGION toStringArray() test+/all)
					{
						with(db.transaction)
						{
							auto query() 
							=> (查 ((位!()),iq{},iq{
								SELECT
									emp_id AS "alias",
									first_name,
									last_name,
									department,
									hire_date,
									salary,
									null_int
								FROM test_employees
							})); 
							((0x3FC61EF13BA2).檢 (query.formatTable!"struct")); 
							
							
							struct Employee
							{
								int alias_; 
								string first_name; 
								string last_name; 
								string department; 
								Date hire_date; 
								double salary; 
								Nullable!int null_int; 
							} 
							
							
							((0x41161EF13BA2).檢 (query.toArray!Employee.toJson)); 
						}
					}
				}
				((0x416C1EF13BA2).檢((update間(_間)))); 
				if((常!(bool)(0))) { console.hide; }if((常!(bool)(0))) { application.exit; }
			}
		}
	); 
} 
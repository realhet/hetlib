module het.firebird2; 

import std; 

version(/+$DIDE_REGION+/all) {
	public class FbDatabase
	{
		Transaction startTransaction()
		{ return new Transaction; } 
		
		private static void freeTransaction(ref Transaction tr)
		{
			if(tr) {
				scope(exit) tr.destroy; 
				/+cleanup goes here+/
			}
		} 
		
		static struct ScopedTransaction
		{
			private Transaction transaction_; 
			@property Transaction transaction() => transaction_; 
			//alias this = transaction_; 
			
			auto executeTransaction() => transaction_.executeTransaction; 
			
			@disable this(this); 
			this(Transaction transaction)
			{ transaction_ = transaction; } 
			
			~this()
			{ freeTransaction(transaction_); } 
		} 
		
		scope transaction()
		=> ScopedTransaction(startTransaction); 
		
		static class Transaction
		{
			auto executeTransaction()
			{ return "It works"; } 
		} 
	} 
}

version(/+$DIDE_REGION+/all) {
	void test_FbDatabase()
	{
		auto db = new FbDatabase; 
		with(db.transaction)
		{
			executeTransaction.writeln; 
			/+foreach(row; executeTransaction) writeln(row); +/
		}
	} 
}
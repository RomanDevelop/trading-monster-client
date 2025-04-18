import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class SignalDatabase {
  static Database? _database;

  // Get the database instance
  static Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB();
    return _database!;
  }

  // Initialize the database
  static Future<Database> _initDB() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'signal_database.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  // Create tables
  static Future<void> _createDB(Database db, int version) async {
    // Signals table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS signals (
        id TEXT PRIMARY KEY,
        ticker TEXT NOT NULL,
        signal_type TEXT NOT NULL,
        message TEXT NOT NULL,
        open_price REAL NOT NULL,
        close_price REAL NOT NULL,
        change_percent REAL NOT NULL,
        eps_growth REAL NOT NULL,
        timestamp TEXT NOT NULL,
        status TEXT NOT NULL
      )
    ''');

    // Portfolio table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS portfolio (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        ticker TEXT NOT NULL,
        signal_type TEXT NOT NULL,
        price REAL NOT NULL,
        quantity REAL NOT NULL,
        balance_left REAL NOT NULL,
        timestamp TEXT NOT NULL
      )
    ''');

    // Set initial balance
    await db.insert('portfolio', {
      'ticker': 'BALANCE',
      'signal_type': 'balance',
      'price': 0.0,
      'quantity': 0.0,
      'balance_left': 1000.0,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  // Insert a signal
  static Future<void> insertSignal(Map<String, dynamic> signal) async {
    final db = await database;
    await db.insert(
      'signals',
      signal,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // Get all signals
  static Future<List<Map<String, dynamic>>> getAllSignals() async {
    final db = await database;
    return await db.query(
      'signals',
      orderBy: 'timestamp DESC',
    );
  }

  // Get signals by ticker
  static Future<List<Map<String, dynamic>>> getSignalsByTicker(
      String ticker) async {
    final db = await database;
    return await db.query(
      'signals',
      where: 'ticker = ?',
      whereArgs: [ticker],
      orderBy: 'timestamp DESC',
    );
  }

  // Update signal status
  static Future<void> updateSignalStatus(String id, String status) async {
    final db = await database;
    await db.update(
      'signals',
      {'status': status},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Insert portfolio entry
  static Future<void> insertPortfolio({
    required String ticker,
    required String signalType,
    required double price,
    required double quantity,
    required double balanceLeft,
  }) async {
    final db = await database;

    // Get current balance
    final balanceResult = await db.query(
      'portfolio',
      columns: ['balance_left'],
      orderBy: 'id DESC',
      limit: 1,
    );

    double currentBalance = 1000.0; // Default balance
    if (balanceResult.isNotEmpty) {
      currentBalance = balanceResult.first['balance_left'] as double;
    }

    // Calculate position value
    final double positionValue = quantity * price;

    // Subtract position value from balance
    final double balanceLeft = currentBalance - positionValue;

    // Add entry with updated balance
    await db.insert('portfolio', {
      'ticker': ticker,
      'signal_type': signalType,
      'price': price,
      'quantity': quantity,
      'balance_left': balanceLeft,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  // Close position by ticker
  static Future<void> closePositionByTicker(
      String ticker, double closePrice) async {
    final db = await database;

    // Get active position
    final position = await getActivePosition(ticker);
    if (position == null) {
      return; // No active position
    }

    // Get position data
    final double quantity = position['quantity'] as double;
    final double entryPrice = position['price'] as double;
    final String signalType = position['signal_type'] as String;

    // Get record ID
    final int id = position['id'] as int;

    // Get current balance
    final double currentBalance = await getCurrentBalance();

    // Closing amount
    final double closingAmount = quantity * closePrice;

    // Calculate P&L
    double pnl = 0.0;
    double updatedBalance = 0.0;

    if (signalType.toLowerCase() == 'long') {
      // For LONG: P&L = (Close price - Entry price) * Quantity
      pnl = (closePrice - entryPrice) * quantity;

      // For LONG positions, add the closing amount to the balance
      // which already includes both the initial investment and P&L
      updatedBalance = currentBalance + closingAmount;

      print(
          "LONG position closed: Balance $currentBalance + Closing $closingAmount = $updatedBalance");
    } else {
      // For SHORT: P&L = (Entry price - Close price) * Quantity
      pnl = (entryPrice - closePrice) * quantity;

      // For SHORT positions we don't subtract money from balance at opening,
      // so we just add the profit
      updatedBalance = currentBalance + pnl;

      print(
          "SHORT position closed: Balance $currentBalance + P&L $pnl = $updatedBalance");
    }

    print(
        "Position closed: Ticker=$ticker, Entry=$entryPrice, Close=$closePrice, P&L=$pnl");

    // Delete position record
    await db.delete(
      'portfolio',
      where: 'id = ?',
      whereArgs: [id],
    );

    // Add new record with updated balance
    await db.insert('portfolio', {
      'ticker': 'BALANCE',
      'signal_type': 'balance',
      'price': 0.0,
      'quantity': 0.0,
      'balance_left': updatedBalance,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  // Get current balance
  static Future<double> getCurrentBalance() async {
    final db = await database;
    final result = await db.query(
      'portfolio',
      columns: ['balance_left', 'timestamp', 'ticker', 'signal_type'],
      orderBy: 'timestamp DESC',
      limit: 1,
    );

    if (result.isEmpty) {
      print("No balance record found, returning default balance 1000.0");
      return 1000.0; // Initial balance
    }

    final balanceRecord = result.first;
    final double balance = balanceRecord['balance_left'] as double;
    final String ticker = balanceRecord['ticker'] as String;
    final String type = balanceRecord['signal_type'] as String;
    final String timestamp = balanceRecord['timestamp'] as String;

    print(
        "Current balance: $balance (from record: ticker=$ticker, type=$type, time=$timestamp)");

    return balance;
  }

  // Get active positions excluding balance records
  static Future<List<Map<String, dynamic>>> getActivePositions() async {
    final db = await database;
    // Get only records where ticker is NOT "BALANCE" and type is NOT "balance"
    return await db.query('portfolio',
        where: 'ticker != ? AND signal_type != ?',
        whereArgs: ['BALANCE', 'balance'],
        orderBy: 'timestamp DESC');
  }

  // Get active position for specific ticker
  static Future<Map<String, dynamic>?> getActivePosition(String ticker) async {
    final db = await database;
    final List<Map<String, dynamic>> result = await db.query(
      'portfolio',
      where: 'ticker = ?',
      whereArgs: [ticker],
      limit: 1,
    );

    if (result.isEmpty) {
      return null;
    }

    return result.first;
  }

  // Calculate profit and loss (P&L)
  static double calculatePnL(
      Map<String, dynamic> position, double currentPrice) {
    final double entryPrice = position['price'] as double;
    final double quantity = position['quantity'] as double;
    final String signalType = position['signal_type'] as String;

    if (signalType.toLowerCase() == 'long') {
      // For LONG: P&L = (Current price - Entry price) * Quantity
      return (currentPrice - entryPrice) * quantity;
    } else {
      // For SHORT: P&L = (Entry price - Current price) * Quantity
      return (entryPrice - currentPrice) * quantity;
    }
  }

  // Calculate P&L percentage
  static double calculatePnLPercent(
      Map<String, dynamic> position, double currentPrice) {
    final double entryPrice = position['price'] as double;
    final double pnl = calculatePnL(position, currentPrice);
    final double investment = entryPrice * (position['quantity'] as double);

    if (investment == 0) return 0.0;
    return (pnl / investment) * 100;
  }

  // Clear portfolio and reset balance
  static Future<void> clearPortfolio() async {
    final db = await database;

    // Delete all portfolio entries
    await db.delete('portfolio');

    // Reset balance to initial 1000.0
    await db.insert('portfolio', {
      'ticker': 'BALANCE',
      'signal_type': 'balance',
      'price': 0.0,
      'quantity': 0.0,
      'balance_left': 1000.0,
      'timestamp': DateTime.now().toIso8601String(),
    });

    print("Portfolio cleared and balance reset to 1000.0");
  }
}

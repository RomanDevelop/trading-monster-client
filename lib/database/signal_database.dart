import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/signal_model.dart';

class SignalDatabase {
  static Database? _db;

  static Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDB('signals.db');
    return _db!;
  }

  static Future<Database> _initDB(String file) async {
    final path = join(await getDatabasesPath(), file);
    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  static Future _createDB(Database db, int version) async {
    // Таблица сигналов
    await db.execute('''
      CREATE TABLE signals (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        ticker TEXT,
        signal TEXT,
        message TEXT,
        open REAL,
        close REAL,
        change_percent REAL,
        eps_growth REAL,
        timestamp DATETIME DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    // Таблица сделок (портфолио)
    await db.execute('''
      CREATE TABLE portfolio (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        ticker TEXT,
        signal_type TEXT,         -- long / short
        price REAL,
        quantity REAL,
        balance_left REAL,
        timestamp DATETIME DEFAULT CURRENT_TIMESTAMP
      )
    ''');
  }

  // 💾 Сохранить сигнал
  static Future<void> insertSignal(SignalModel model) async {
    final db = await database;
    await db.insert('signals', {
      'ticker': model.ticker,
      'signal': model.signal,
      'message': model.message,
      'open': model.open,
      'close': model.close,
      'change_percent': model.changePercent,
      'eps_growth': model.epsGrowth,
    });
  }

  // 💾 Сохранить сделку
  static Future<void> insertPortfolio({
    required String ticker,
    required String signalType, // long / short
    required double price,
    required double quantity,
    required double balanceLeft,
  }) async {
    final db = await database;

    // Получаем текущий баланс
    final currentBalance = await getCurrentBalance();

    // Рассчитываем стоимость позиции
    final double positionValue = price * quantity;

    // Вычисляем новый баланс в зависимости от типа позиции
    double newBalanceLeft;

    if (signalType.toLowerCase() == 'long') {
      // Для long позиций вычитаем стоимость из баланса
      newBalanceLeft = currentBalance - positionValue;
      print(
          "LONG position opened: Balance $currentBalance - Position $positionValue = $newBalanceLeft");
    } else {
      // Для short позиций баланс не уменьшается
      newBalanceLeft = currentBalance;
      print("SHORT position opened: Balance remains $currentBalance");
    }

    print(
        "Position opened: Ticker=$ticker, Type=$signalType, Price=$price, Quantity=$quantity");

    await db.insert('portfolio', {
      'ticker': ticker,
      'signal_type': signalType,
      'price': price,
      'quantity': quantity,
      'balance_left': newBalanceLeft,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  // 📥 Получить историю сигналов
  static Future<List<SignalModel>> getAllSignals() async {
    final db = await database;
    final result = await db.query('signals', orderBy: 'timestamp DESC');
    return result.map((e) => SignalModel.fromJson(e)).toList();
  }

  // 📥 Получить сделки
  static Future<List<Map<String, dynamic>>> getPortfolioHistory() async {
    final db = await database;
    // Получаем записи, где тикер не равен "BALANCE"
    return await db.query('portfolio',
        where: 'ticker != ?',
        whereArgs: ['BALANCE'],
        orderBy: 'timestamp DESC');
  }

  // 📥 Получить все записи портфолио (включая записи баланса)
  static Future<List<Map<String, dynamic>>> getAllPortfolioRecords() async {
    final db = await database;
    return await db.query('portfolio', orderBy: 'timestamp DESC');
  }

  // 🔍 Проверка существования активной сделки по тикеру
  static Future<bool> hasActivePosition(String ticker) async {
    final db = await database;
    final result = await db.query(
      'portfolio',
      where: 'ticker = ?',
      whereArgs: [ticker],
      limit: 1,
    );
    return result.isNotEmpty;
  }

  // 📈 Получить активную позицию по тикеру
  static Future<Map<String, dynamic>?> getActivePosition(String ticker) async {
    final db = await database;
    final result = await db.query(
      'portfolio',
      where: 'ticker = ? AND signal_type != ?',
      whereArgs: [ticker, 'balance'],
      limit: 1,
    );

    if (result.isEmpty) {
      return null;
    }

    return result.first;
  }

  // 💰 Расчет прибыли/убытка по позиции
  static double calculatePnL(
      Map<String, dynamic> position, double currentPrice) {
    final String signalType = position['signal_type'] as String;
    final double entryPrice = position['price'] as double;
    final double quantity = position['quantity'] as double;

    if (signalType.toLowerCase() == 'long') {
      // Для long: (текущая_цена - цена_входа) * количество
      return (currentPrice - entryPrice) * quantity;
    } else if (signalType.toLowerCase() == 'short') {
      // Для short: (цена_входа - текущая_цена) * количество
      return (entryPrice - currentPrice) * quantity;
    }

    return 0.0;
  }

  // 📊 Расчет процента прибыли/убытка
  static double calculatePnLPercent(
      Map<String, dynamic> position, double currentPrice) {
    final String signalType = position['signal_type'] as String;
    final double entryPrice = position['price'] as double;

    if (signalType.toLowerCase() == 'long') {
      // Для long: (текущая_цена - цена_входа) / цена_входа * 100
      return (currentPrice - entryPrice) / entryPrice * 100;
    } else if (signalType.toLowerCase() == 'short') {
      // Для short: (цена_входа - текущая_цена) / цена_входа * 100
      return (entryPrice - currentPrice) / entryPrice * 100;
    }

    return 0.0;
  }

  // 🧹 Очистить сигналы
  static Future<void> clear() async {
    final db = await database;
    await db.delete('signals');
  }

  // 🧹 Очистить портфолио
  static Future<void> clearPortfolio() async {
    final db = await database;
    await db.delete('portfolio');
  }

  // 📝 Добавить запись в портфолио
  static Future<void> addPortfolioEntry(Map<String, dynamic> entry) async {
    final db = await database;

    // Получаем текущий баланс
    final balanceResult = await db.query(
      'portfolio',
      columns: ['balance_left'],
      orderBy: 'id DESC',
      limit: 1,
    );

    double currentBalance = 1000.0; // Баланс по умолчанию
    if (balanceResult.isNotEmpty) {
      currentBalance = balanceResult.first['balance_left'] as double;
    }

    // Рассчитываем стоимость позиции
    final double quantity = entry['quantity'] as double;
    final double price = entry['price'] as double;
    final double positionValue = quantity * price;

    // Вычитаем стоимость из баланса
    final double balanceLeft = currentBalance - positionValue;

    // Добавляем запись с обновленным балансом
    await db.insert('portfolio', {
      'ticker': entry['ticker'],
      'signal_type': entry['signal_type'],
      'price': price,
      'quantity': quantity,
      'balance_left': balanceLeft,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  // 🚫 Закрыть позицию по тикеру
  static Future<void> closePositionByTicker(
      String ticker, double closePrice) async {
    final db = await database;

    // Получаем активную позицию
    final position = await getActivePosition(ticker);
    if (position == null) {
      return; // Нет активной позиции
    }

    // Получаем данные позиции
    final double quantity = position['quantity'] as double;
    final double entryPrice = position['price'] as double;
    final String signalType = position['signal_type'] as String;

    // Получаем ID записи
    final int id = position['id'] as int;

    // Получаем текущий баланс
    final double currentBalance = await getCurrentBalance();

    // Сумма, вложенная в позицию
    final double investedAmount = quantity * entryPrice;

    // Сумма при закрытии позиции
    final double closingAmount = quantity * closePrice;

    // Расчет P&L
    double pnl = 0.0;
    double updatedBalance = 0.0;

    if (signalType.toLowerCase() == 'long') {
      // Для LONG: P&L = (Цена закрытия - Цена входа) * Количество
      pnl = (closePrice - entryPrice) * quantity;

      // ВАЖНО: Добавляем к балансу сумму закрытия
      // (возвращаем инвестиции + добавляем P&L)
      updatedBalance = currentBalance + closingAmount;

      print(
          "LONG position closed: Balance $currentBalance + Closing $closingAmount = $updatedBalance");
    } else {
      // Для SHORT: P&L = (Цена входа - Цена закрытия) * Количество
      pnl = (entryPrice - closePrice) * quantity;

      // Для SHORT позиций мы не вычитали деньги из баланса при открытии,
      // поэтому просто добавляем прибыль
      updatedBalance = currentBalance + pnl;

      print(
          "SHORT position closed: Balance $currentBalance + P&L $pnl = $updatedBalance");
    }

    print(
        "Position closed: Ticker=$ticker, Entry=$entryPrice, Close=$closePrice, P&L=$pnl");

    // Удаляем запись позиции
    await db.delete(
      'portfolio',
      where: 'id = ?',
      whereArgs: [id],
    );

    // Добавляем новую запись с обновленным балансом
    await db.insert('portfolio', {
      'ticker': 'BALANCE',
      'signal_type': 'balance',
      'price': 0.0,
      'quantity': 0.0,
      'balance_left': updatedBalance,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  // 💰 Получить текущий баланс
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
      return 1000.0; // Начальный баланс
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

  // 📥 Получить активные позиции без учета записей баланса
  static Future<List<Map<String, dynamic>>> getActivePositions() async {
    final db = await database;
    // Получаем только записи, где тикер НЕ равен "BALANCE" и тип НЕ равен "balance"
    return await db.query('portfolio',
        where: 'ticker != ? AND signal_type != ?',
        whereArgs: ['BALANCE', 'balance'],
        orderBy: 'timestamp DESC');
  }
}

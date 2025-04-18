import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../models/signal_model.dart';
import '../services/notification_service.dart';

// Класс для хранения информации о тикере и модели анализа
class WatchlistItem {
  final String ticker;
  final String modelType;

  WatchlistItem({required this.ticker, required this.modelType});

  factory WatchlistItem.fromJson(Map<String, dynamic> json) {
    return WatchlistItem(
      ticker: json['ticker'] as String,
      modelType: json['model_type'] as String? ?? 'RSI_MODEL',
    );
  }
}

// Класс для хранения информации о близости сигнала
class SignalProximityItem {
  final String ticker;
  final int proximityValue; // значение от 0 до 100
  final String description;

  SignalProximityItem({
    required this.ticker,
    required this.proximityValue,
    required this.description,
  });

  factory SignalProximityItem.fromJson(Map<String, dynamic> json) {
    return SignalProximityItem(
      ticker: json['ticker'] as String,
      proximityValue: json['proximity_value'] as int,
      description: json['description'] as String? ?? '',
    );
  }
}

// Providers
final signalViewModelProvider =
    StateNotifierProvider<SignalViewModel, AsyncValue<List<SignalModel>>>(
        (ref) => SignalViewModel(ref));

// Создаем провайдер для хранения количества непрочитанных сигналов
final unreadSignalsCountProvider = StateProvider<int>((ref) => 0);

final watchlistProvider =
    StateNotifierProvider<WatchlistNotifier, AsyncValue<List<String>>>(
        (ref) => WatchlistNotifier());

// Новый провайдер для детальной информации о watchlist
final watchlistDetailsProvider = StateNotifierProvider<WatchlistDetailsNotifier,
    AsyncValue<List<WatchlistItem>>>((ref) => WatchlistDetailsNotifier());

// Провайдер для информации о близости сигналов
final signalProximityProvider = StateNotifierProvider<SignalProximityNotifier,
    AsyncValue<List<SignalProximityItem>>>((ref) => SignalProximityNotifier());

final balanceProvider =
    StateNotifierProvider<BalanceNotifier, AsyncValue<double>>(
        (ref) => BalanceNotifier());

final positionsProvider = StateNotifierProvider<PositionsNotifier,
    AsyncValue<List<Map<String, dynamic>>>>((ref) => PositionsNotifier());

// Provider for all signals categories (pending, confirmed, rejected)
final signalCategoriesProvider =
    FutureProvider<Map<String, List<SignalModel>>>((ref) async {
  final viewModel = ref.read(signalViewModelProvider.notifier);
  return await viewModel.getAllSignalCategories();
});

// Class for managing balance
class BalanceNotifier extends StateNotifier<AsyncValue<double>> {
  bool _disposed = false;

  BalanceNotifier() : super(const AsyncValue.loading()) {
    // Delay initialization to prevent updating during widget tree building
    Future.microtask(() {
      if (!_disposed) {
        fetchBalance();
      }
    });
  }

  final String serverUrl = 'http://127.0.0.1:8001/api/v1';

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  Future<void> fetchBalance() async {
    if (_disposed) return;

    try {
      state = const AsyncValue.loading();
      final response =
          await http.get(Uri.parse('$serverUrl/portfolio/balance'));

      if (_disposed) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final double balance = data['balance'].toDouble();
        state = AsyncValue.data(balance);
        print('Balance retrieved successfully: $balance');
      } else {
        state = AsyncValue.error(
          'Error getting balance: ${response.statusCode}',
          StackTrace.current,
        );
        print('Error getting balance: HTTP ${response.statusCode}');
      }
    } catch (e, stackTrace) {
      if (!_disposed) {
        state = AsyncValue.error(e, stackTrace);
        print('Error getting balance: $e');
      }
    }
  }

  // Method to reset portfolio and balance
  Future<bool> resetPortfolio() async {
    try {
      final response = await http.post(Uri.parse('$serverUrl/portfolio/reset'));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final double balance = data['balance'].toDouble();
        state = AsyncValue.data(balance);
        print('Portfolio reset, new balance: $balance');
        return true;
      }
      print('Error resetting portfolio: HTTP ${response.statusCode}');
      return false;
    } catch (e) {
      print('Error resetting portfolio: $e');
      return false;
    }
  }
}

// Class for managing positions
class PositionsNotifier
    extends StateNotifier<AsyncValue<List<Map<String, dynamic>>>> {
  bool _disposed = false;

  PositionsNotifier() : super(const AsyncValue.loading()) {
    // Delay initialization to prevent updating during widget tree building
    Future.microtask(() {
      if (!_disposed) {
        fetchPositions();
      }
    });
  }

  final String serverUrl = 'http://127.0.0.1:8001/api/v1';

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  Future<void> fetchPositions() async {
    if (_disposed) return;

    try {
      state = const AsyncValue.loading();
      final response =
          await http.get(Uri.parse('$serverUrl/portfolio/positions'));

      if (_disposed) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> positionsData = data['positions'];
        final List<Map<String, dynamic>> positions =
            positionsData.cast<Map<String, dynamic>>();
        state = AsyncValue.data(positions);
        print('Positions retrieved successfully: ${positions.length}');
      } else {
        state = AsyncValue.error(
          'Error getting positions: ${response.statusCode}',
          StackTrace.current,
        );
        print('Error getting positions: HTTP ${response.statusCode}');
      }
    } catch (e, stackTrace) {
      if (!_disposed) {
        state = AsyncValue.error(e, stackTrace);
        print('Error getting positions: $e');
      }
    }
  }

  // Method for getting positions history
  Future<List<Map<String, dynamic>>> getPositionsHistory() async {
    try {
      final response =
          await http.get(Uri.parse('$serverUrl/portfolio/positions/history'));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> positionsData = data['positions_history'] ?? [];
        final List<Map<String, dynamic>> positions =
            positionsData.cast<Map<String, dynamic>>();
        return positions;
      }
      print('Error getting positions history: HTTP ${response.statusCode}');
      return [];
    } catch (e) {
      print('Error getting positions history: $e');
      return [];
    }
  }

  // Method for closing a position
  Future<bool> closePosition(String ticker, double closePrice) async {
    if (_disposed) return false;

    try {
      final response = await http.post(
        Uri.parse('$serverUrl/portfolio/positions/close/$ticker'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'close_price': closePrice}),
      );

      if (_disposed) return false;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final double balance = data['balance'].toDouble();
        final double pnl = data['pnl'].toDouble();

        print('Position closed: $ticker, P&L: $pnl, new balance: $balance');

        Future.microtask(() {
          if (!_disposed) {
            fetchPositions();
          }
        });

        return true;
      }
      print('Error closing position: HTTP ${response.statusCode}');
      return false;
    } catch (e) {
      print('Error closing position: $e');
      return false;
    }
  }
}

class SignalViewModel extends StateNotifier<AsyncValue<List<SignalModel>>> {
  final Ref _ref;
  bool _disposed = false;

  SignalViewModel(this._ref) : super(const AsyncValue.loading()) {
    // Delay initialization to prevent updating during widget tree building
    Future.microtask(() {
      if (!_disposed) {
        fetchSignals();
      }
    });
  }

  final String serverUrl = 'http://127.0.0.1:8001/api/v1';

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  // Метод для обновления счетчика непрочитанных сигналов
  void updateUnreadSignalsCount(List<SignalModel> signals) {
    if (_disposed) return;

    // Считаем только сигналы со статусом pending (ожидающие действия)
    final int pendingCount =
        signals.where((signal) => signal.status == 'pending').length;

    // Обновляем значение в провайдере
    _ref.read(unreadSignalsCountProvider.notifier).state = pendingCount;
  }

  // Метод для сброса счетчика непрочитанных сигналов
  void resetUnreadSignalsCount() {
    if (_disposed) return;
    _ref.read(unreadSignalsCountProvider.notifier).state = 0;
  }

  Future<void> addTicker(String ticker,
      {AnalysisModelType modelType = AnalysisModelType.rsiModel}) async {
    if (_disposed) return;

    print(
        '⭐ SignalViewModel: добавление тикера $ticker с моделью ${modelType.displayName}');

    // Delegate adding ticker to WatchlistNotifier
    final success = await _ref
        .read(watchlistProvider.notifier)
        .addTicker(ticker, modelType: modelType);

    if (success && !_disposed) {
      // Также обновляем WatchlistDetailsNotifier
      print(
          '⭐ SignalViewModel: успешно добавлен тикер, обновляю детали watchlist');
      await _ref
          .read(watchlistDetailsProvider.notifier)
          .fetchWatchlistDetails();

      // Update signals after adding ticker
      await fetchSignals();
    } else {
      print('⭐ SignalViewModel: не удалось добавить тикер');
    }
  }

  Future<void> fetchSignals() async {
    if (_disposed) return;

    try {
      state = const AsyncValue.loading();
      final response = await http.get(Uri.parse('$serverUrl/signals'));

      if (_disposed) return;

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        final List<SignalModel> signals =
            data.map((e) => SignalModel.fromJson(e)).toList();
        state = AsyncValue.data(signals);

        // Обновляем счетчик непрочитанных сигналов
        updateUnreadSignalsCount(signals);
      } else {
        state = AsyncValue.error(
            'Error getting signals: ${response.statusCode}',
            StackTrace.current);
      }
    } catch (e, stackTrace) {
      if (!_disposed) {
        print('Error getting signals: $e');
        state = AsyncValue.error(e, stackTrace);
      }
    }
  }

  // Method for confirming a signal
  Future<bool> confirmSignal(String signalId, double quantity) async {
    if (_disposed) return false;

    try {
      final response = await http.post(
        Uri.parse('$serverUrl/signals/confirm'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'signal_id': signalId,
          'action': 'confirm',
          'quantity': quantity,
        }),
      );

      if (_disposed) return false;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final double balance = data['balance'].toDouble();

        // Update balance and positions state
        Future.microtask(() {
          if (!_disposed) {
            _ref.read(balanceProvider.notifier).fetchBalance();
            _ref.read(positionsProvider.notifier).fetchPositions();
            // Update signals after confirmation
            fetchSignals();
          }
        });

        return true;
      }
      return false;
    } catch (e) {
      print('Error confirming signal: $e');
      return false;
    }
  }

  // Method for rejecting a signal
  Future<bool> rejectSignal(String signalId) async {
    if (_disposed) return false;

    try {
      final response = await http.post(
        Uri.parse('$serverUrl/signals/confirm'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'signal_id': signalId,
          'action': 'reject',
        }),
      );

      if (_disposed) return false;

      if (response.statusCode == 200) {
        // Update signals after rejection
        Future.microtask(() {
          if (!_disposed) {
            fetchSignals();
          }
        });
        return true;
      }
      return false;
    } catch (e) {
      print('Error rejecting signal: $e');
      return false;
    }
  }

  // Method for getting all signals by ticker
  Future<List<SignalModel>> getSignalsByTicker(String ticker) async {
    try {
      final response = await http.get(Uri.parse('$serverUrl/signals/$ticker'));
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        final List<SignalModel> signals =
            data.map((e) => SignalModel.fromJson(e)).toList();
        return signals;
      }
      return [];
    } catch (e) {
      print('Error getting signals by ticker: $e');
      return [];
    }
  }

  // Method for getting signal history
  Future<List<SignalModel>> getSignalHistory() async {
    try {
      final response = await http.get(Uri.parse('$serverUrl/signals/history'));
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        final List<SignalModel> signals =
            data.map((e) => SignalModel.fromJson(e)).toList();
        return signals;
      }
      return [];
    } catch (e) {
      print('Error getting signal history: $e');
      return [];
    }
  }

  // Method for removing ticker from monitoring
  Future<bool> removeTicker(String ticker) async {
    try {
      final response =
          await http.delete(Uri.parse('$serverUrl/tickers/$ticker'));
      if (response.statusCode == 200) {
        // Update watchlist
        await _ref.read(watchlistProvider.notifier).fetchWatchlist();
        // Update signals after removal
        await fetchSignals();
        return true;
      }
      return false;
    } catch (e) {
      print('Error removing ticker: $e');
      return false;
    }
  }

  // Method for getting all signal categories
  Future<Map<String, List<SignalModel>>> getAllSignalCategories() async {
    try {
      // Get active signals (pending)
      final pendingResponse = await http.get(Uri.parse('$serverUrl/signals'));
      List<SignalModel> pendingSignals = [];

      if (pendingResponse.statusCode == 200) {
        final List<dynamic> pendingData = jsonDecode(pendingResponse.body);
        pendingSignals =
            pendingData.map((e) => SignalModel.fromJson(e)).toList();
      }

      // Get history (confirmed and rejected)
      final historyResponse =
          await http.get(Uri.parse('$serverUrl/signals/history'));
      List<SignalModel> historySignals = [];

      if (historyResponse.statusCode == 200) {
        final List<dynamic> historyData = jsonDecode(historyResponse.body);
        historySignals =
            historyData.map((e) => SignalModel.fromJson(e)).toList();
      }

      // Filter signals by status
      final List<SignalModel> confirmedSignals = historySignals
          .where((signal) => signal.status == 'confirmed')
          .toList();

      final List<SignalModel> rejectedSignals = historySignals
          .where((signal) => signal.status == 'rejected')
          .toList();

      // Return dictionary with signal categories
      return {
        'pending': pendingSignals,
        'confirmed': confirmedSignals,
        'rejected': rejectedSignals,
      };
    } catch (e) {
      print('Error getting signal categories: $e');
      return {
        'pending': [],
        'confirmed': [],
        'rejected': [],
      };
    }
  }
}

// Class for managing watchlist
class WatchlistNotifier extends StateNotifier<AsyncValue<List<String>>> {
  bool _disposed = false;

  WatchlistNotifier() : super(const AsyncValue.loading()) {
    // Delay initialization to prevent updating during widget tree building
    Future.microtask(() {
      if (!_disposed) {
        fetchWatchlist();
      }
    });
  }

  final String serverUrl = 'http://127.0.0.1:8001/api/v1';

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  Future<void> fetchWatchlist() async {
    if (_disposed) return;

    try {
      state = const AsyncValue.loading();
      final response = await http.get(Uri.parse('$serverUrl/tickers'));

      if (_disposed) return;

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        final List<String> tickers = data.cast<String>();
        state = AsyncValue.data(tickers);
      } else {
        state = AsyncValue.error(
            'Error getting watchlist: ${response.statusCode}',
            StackTrace.current);
      }
    } catch (e, stackTrace) {
      if (!_disposed) {
        print('Error getting watchlist: $e');
        state = AsyncValue.error(e, stackTrace);
      }
    }
  }

  Future<bool> addTicker(String ticker,
      {AnalysisModelType modelType = AnalysisModelType.rsiModel}) async {
    if (_disposed) return false;

    try {
      print(
          '📡 WatchlistNotifier: отправка тикера $ticker с моделью ${modelType.displayName} (${modelType.value}) на сервер');

      final response = await http.post(
        Uri.parse('$serverUrl/tickers'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'ticker': ticker, 'model_type': modelType.value}),
      );

      if (_disposed) return false;

      if (response.statusCode == 200) {
        print(
            '✓ WatchlistNotifier: успешно добавлен тикер $ticker с моделью ${modelType.value}');
        print('✓ Ответ сервера: ${response.body}');

        Future.microtask(() {
          if (!_disposed) {
            fetchWatchlist();
          }
        });
        return true;
      }
      print(
          '✗ WatchlistNotifier: ошибка добавления тикера. Код: ${response.statusCode}, тело: ${response.body}');
      return false;
    } catch (e) {
      print('✗ WatchlistNotifier: исключение при добавлении тикера: $e');
      return false;
    }
  }

  Future<bool> removeTicker(String ticker) async {
    if (_disposed) return false;

    try {
      final response =
          await http.delete(Uri.parse('$serverUrl/tickers/$ticker'));

      if (_disposed) return false;

      if (response.statusCode == 200) {
        Future.microtask(() {
          if (!_disposed) {
            fetchWatchlist();
          }
        });
        return true;
      }
      return false;
    } catch (e) {
      print('Error removing ticker: $e');
      return false;
    }
  }
}

// Class for managing watchlist with details
class WatchlistDetailsNotifier
    extends StateNotifier<AsyncValue<List<WatchlistItem>>> {
  bool _disposed = false;

  WatchlistDetailsNotifier() : super(const AsyncValue.loading()) {
    // Delay initialization to prevent updating during widget tree building
    Future.microtask(() {
      if (!_disposed) {
        fetchWatchlistDetails();
      }
    });
  }

  final String serverUrl = 'http://127.0.0.1:8001/api/v1';

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  Future<void> fetchWatchlistDetails() async {
    if (_disposed) return;

    try {
      state = const AsyncValue.loading();
      print(
          '📋 WatchlistDetailsNotifier: получение деталей тикеров со стороны сервера');
      final response =
          await http.get(Uri.parse('$serverUrl/tickers/with_models'));

      if (_disposed) return;

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        print('✓ WatchlistDetailsNotifier: получены детали тикеров: $data');

        final List<WatchlistItem> tickers = data
            .map((e) => WatchlistItem.fromJson(e as Map<String, dynamic>))
            .toList();

        print('📊 WatchlistDetailsNotifier: обработанные детали тикеров:');
        for (var item in tickers) {
          print('  - Тикер: ${item.ticker}, Модель: ${item.modelType}');
        }

        state = AsyncValue.data(tickers);
      } else {
        print(
            '✗ WatchlistDetailsNotifier: ошибка получения деталей. Код: ${response.statusCode}, тело: ${response.body}');
        state = AsyncValue.error(
            'Error getting watchlist details: ${response.statusCode}',
            StackTrace.current);
      }
    } catch (e, stackTrace) {
      if (!_disposed) {
        print(
            '✗ WatchlistDetailsNotifier: исключение при получении деталей: $e');
        state = AsyncValue.error(e, stackTrace);
      }
    }
  }

  Future<bool> addTicker(String ticker,
      {AnalysisModelType modelType = AnalysisModelType.rsiModel}) async {
    if (_disposed) return false;

    try {
      final response = await http.post(
        Uri.parse('$serverUrl/tickers'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'ticker': ticker, 'model_type': modelType.value}),
      );

      if (_disposed) return false;

      if (response.statusCode == 200) {
        Future.microtask(() {
          if (!_disposed) {
            fetchWatchlistDetails();
          }
        });
        return true;
      }
      return false;
    } catch (e) {
      print('Error adding ticker: $e');
      return false;
    }
  }

  Future<bool> removeTicker(String ticker) async {
    if (_disposed) return false;

    try {
      final response =
          await http.delete(Uri.parse('$serverUrl/tickers/$ticker'));

      if (_disposed) return false;

      if (response.statusCode == 200) {
        Future.microtask(() {
          if (!_disposed) {
            fetchWatchlistDetails();
          }
        });
        return true;
      }
      return false;
    } catch (e) {
      print('Error removing ticker: $e');
      return false;
    }
  }

  // Получить тип модели для тикера
  String getModelTypeForTicker(String ticker) {
    final items = state.valueOrNull;
    if (items == null) return 'RSI_MODEL';

    final item = items.firstWhere(
      (item) => item.ticker == ticker,
      orElse: () => WatchlistItem(ticker: ticker, modelType: 'RSI_MODEL'),
    );

    return item.modelType;
  }
}

// Class for managing signal proximity data
class SignalProximityNotifier
    extends StateNotifier<AsyncValue<List<SignalProximityItem>>> {
  bool _disposed = false;

  SignalProximityNotifier() : super(const AsyncValue.loading()) {
    // Delay initialization to prevent updating during widget tree building
    Future.microtask(() {
      if (!_disposed) {
        fetchSignalProximity();
      }
    });
  }

  final String serverUrl = 'http://127.0.0.1:8001/api/v1';

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  Future<void> fetchSignalProximity() async {
    if (_disposed) return;

    try {
      state = const AsyncValue.loading();
      print('📡 SignalProximityNotifier: Запрос данных о близости сигналов');
      final response = await http.get(Uri.parse('$serverUrl/tickers/details'));

      if (_disposed) return;

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        print(
            '✓ SignalProximityNotifier: Получены данные о близости сигналов: $data');

        final List<SignalProximityItem> proximityItems = data
            .map((e) => SignalProximityItem.fromJson(e as Map<String, dynamic>))
            .toList();

        state = AsyncValue.data(proximityItems);
      } else {
        print(
            '✗ SignalProximityNotifier: Ошибка получения данных. Код: ${response.statusCode}');

        // В случае ошибки генерируем временные данные
        // В реальном приложении такого быть не должно!
        final tempData = await _generateTemporaryData();
        state = AsyncValue.data(tempData);
      }
    } catch (e, stackTrace) {
      if (!_disposed) {
        print('✗ SignalProximityNotifier: Исключение при получении данных: $e');

        // В случае исключения генерируем временные данные
        // В реальном приложении такого быть не должно!
        final tempData = await _generateTemporaryData();
        state = AsyncValue.data(tempData);
      }
    }
  }

  // Временный метод для генерации данных о близости сигналов
  // В реальном приложении должен быть удален после реализации API
  Future<List<SignalProximityItem>> _generateTemporaryData() async {
    // Получаем список тикеров
    final response = await http.get(Uri.parse('$serverUrl/tickers'));
    if (response.statusCode == 200) {
      final List<dynamic> tickers = jsonDecode(response.body);
      return tickers.map<SignalProximityItem>((ticker) {
        // Генерируем псевдослучайное значение на основе хеша имени тикера
        final int hashCode = ticker.toString().hashCode.abs();
        final int proximityValue = hashCode % 101; // Значение от 0 до 100

        // Генерируем описание на основе значения
        String description = '';
        if (proximityValue > 75) {
          description = proximityValue > 90
              ? 'Очень близко к формированию сигнала'
              : 'Приближается к формированию сигнала';
        } else if (proximityValue > 50) {
          description = 'Умеренное движение к сигнальной зоне';
        } else if (proximityValue > 25) {
          description = 'Начальные признаки формирования сигнала';
        } else {
          description = 'Нейтральное состояние';
        }

        return SignalProximityItem(
          ticker: ticker.toString(),
          proximityValue: proximityValue,
          description: description,
        );
      }).toList();
    }

    // В случае ошибки возвращаем пустой список
    return [];
  }

  // Получение данных о близости сигнала для конкретного тикера
  Future<SignalProximityItem?> getProximityForTicker(String ticker) async {
    try {
      final response = await http
          .get(Uri.parse('$serverUrl/tickers/$ticker/signal_proximity'));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        return SignalProximityItem.fromJson(data);
      }

      // Если API недоступен, ищем в кэше
      final items = state.valueOrNull;
      if (items != null) {
        final item = items.firstWhere(
          (item) => item.ticker == ticker,
          orElse: () => SignalProximityItem(
            ticker: ticker,
            proximityValue: 0,
            description: 'Нет данных',
          ),
        );
        return item;
      }

      return null;
    } catch (e) {
      print('Error getting proximity for ticker $ticker: $e');
      return null;
    }
  }

  // Получение значения близости из кэша для тикера
  int getProximityValueForTicker(String ticker) {
    final items = state.valueOrNull;
    if (items == null) return 0;

    final item = items.firstWhere(
      (item) => item.ticker == ticker,
      orElse: () => SignalProximityItem(
        ticker: ticker,
        proximityValue: 0,
        description: 'Нет данных',
      ),
    );

    return item.proximityValue;
  }

  // Получение описания близости из кэша для тикера
  String getProximityDescriptionForTicker(String ticker) {
    final items = state.valueOrNull;
    if (items == null) return 'Нет данных';

    final item = items.firstWhere(
      (item) => item.ticker == ticker,
      orElse: () => SignalProximityItem(
        ticker: ticker,
        proximityValue: 0,
        description: 'Нет данных',
      ),
    );

    return item.description;
  }
}

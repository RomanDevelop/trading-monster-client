import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../models/signal_model.dart';
import '../services/notification_service.dart';

// Провайдер для хранения "известных" тикеров
final previousTickersProvider = StateProvider<List<String>>((ref) => []);

// Провайдер для хранения списка отслеживаемых тикеров
final watchlistProvider =
    StateNotifierProvider<WatchlistNotifier, AsyncValue<List<String>>>(
  (ref) => WatchlistNotifier(),
);

// Провайдер для хранения баланса пользователя
final balanceProvider =
    StateNotifierProvider<BalanceNotifier, AsyncValue<double>>(
  (ref) => BalanceNotifier(),
);

// Провайдер для хранения открытых позиций
final positionsProvider = StateNotifierProvider<PositionsNotifier,
    AsyncValue<List<Map<String, dynamic>>>>(
  (ref) => PositionsNotifier(),
);

final signalViewModelProvider =
    StateNotifierProvider<SignalViewModel, AsyncValue<List<SignalModel>>>(
  (ref) => SignalViewModel(ref),
);

// Класс для управления балансом
class BalanceNotifier extends StateNotifier<AsyncValue<double>> {
  bool _disposed = false;

  BalanceNotifier() : super(const AsyncValue.loading()) {
    // Отложим инициализацию для предотвращения обновления в процессе построения дерева виджетов
    Future.microtask(() {
      if (!_disposed) {
        fetchBalance();
      }
    });
  }

  final String serverUrl = 'http://127.0.0.1:8000';

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  Future<void> fetchBalance() async {
    if (_disposed) return;

    try {
      state = const AsyncValue.loading();
      final response = await http.get(Uri.parse('$serverUrl/balance'));

      if (_disposed) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final double balance = data['balance'].toDouble();
        state = AsyncValue.data(balance);
        print('Баланс успешно получен: $balance');
      } else {
        state = AsyncValue.error(
          'Ошибка при получении баланса: ${response.statusCode}',
          StackTrace.current,
        );
        print('Ошибка при получении баланса: HTTP ${response.statusCode}');
      }
    } catch (e, stackTrace) {
      if (!_disposed) {
        state = AsyncValue.error(e, stackTrace);
        print('Ошибка при получении баланса: $e');
      }
    }
  }

  // Метод для сброса портфеля и баланса
  Future<bool> resetPortfolio() async {
    if (_disposed) return false;

    try {
      final response = await http.post(Uri.parse('$serverUrl/portfolio/reset'));

      if (_disposed) return false;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final double balance = data['balance'].toDouble();
        state = AsyncValue.data(balance);
        print('Портфель сброшен, новый баланс: $balance');
        return true;
      }
      print('Ошибка при сбросе портфеля: HTTP ${response.statusCode}');
      return false;
    } catch (e) {
      print('Ошибка при сбросе портфеля: $e');
      return false;
    }
  }
}

// Класс для управления позициями
class PositionsNotifier
    extends StateNotifier<AsyncValue<List<Map<String, dynamic>>>> {
  bool _disposed = false;

  PositionsNotifier() : super(const AsyncValue.loading()) {
    // Отложим инициализацию для предотвращения обновления в процессе построения дерева виджетов
    Future.microtask(() {
      if (!_disposed) {
        fetchPositions();
      }
    });
  }

  final String serverUrl = 'http://127.0.0.1:8000';

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  Future<void> fetchPositions() async {
    if (_disposed) return;

    try {
      state = const AsyncValue.loading();
      final response = await http.get(Uri.parse('$serverUrl/positions'));

      if (_disposed) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> positionsData = data['positions'];
        final List<Map<String, dynamic>> positions =
            positionsData.cast<Map<String, dynamic>>();
        state = AsyncValue.data(positions);
        print('Позиции успешно получены: ${positions.length}');
      } else {
        state = AsyncValue.error(
          'Ошибка при получении позиций: ${response.statusCode}',
          StackTrace.current,
        );
        print('Ошибка при получении позиций: HTTP ${response.statusCode}');
      }
    } catch (e, stackTrace) {
      if (!_disposed) {
        state = AsyncValue.error(e, stackTrace);
        print('Ошибка при получении позиций: $e');
      }
    }
  }

  // Метод для закрытия позиции
  Future<bool> closePosition(String ticker, double closePrice) async {
    if (_disposed) return false;

    try {
      final response = await http.post(
        Uri.parse('$serverUrl/positions/close/$ticker'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'close_price': closePrice}),
      );

      if (_disposed) return false;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final double balance = data['balance'].toDouble();
        final double pnl = data['pnl'].toDouble();

        print('Позиция закрыта: $ticker, P&L: $pnl, новый баланс: $balance');

        Future.microtask(() {
          if (!_disposed) {
            fetchPositions();
          }
        });

        return true;
      }
      print('Ошибка при закрытии позиции: HTTP ${response.statusCode}');
      return false;
    } catch (e) {
      print('Ошибка при закрытии позиции: $e');
      return false;
    }
  }
}

class SignalViewModel extends StateNotifier<AsyncValue<List<SignalModel>>> {
  final Ref _ref;
  bool _disposed = false;

  SignalViewModel(this._ref) : super(const AsyncValue.loading()) {
    // Отложим инициализацию для предотвращения обновления в процессе построения дерева виджетов
    Future.microtask(() {
      if (!_disposed) {
        fetchSignals();
      }
    });
  }

  final String serverUrl = 'http://127.0.0.1:8000';

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  Future<void> addTicker(String ticker) async {
    if (_disposed) return;

    // Делегируем добавление тикера в WatchlistNotifier
    final success =
        await _ref.read(watchlistProvider.notifier).addTicker(ticker);

    if (success && !_disposed) {
      // Обновляем сигналы после добавления тикера
      await fetchSignals();
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
      } else {
        state = AsyncValue.error(
            'Ошибка при получении сигналов: ${response.statusCode}',
            StackTrace.current);
      }
    } catch (e, stackTrace) {
      if (!_disposed) {
        print('Ошибка при получении сигналов: $e');
        state = AsyncValue.error(e, stackTrace);
      }
    }
  }

  // Метод для подтверждения сигнала
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

        // Обновляем состояние баланса и позиций
        Future.microtask(() {
          if (!_disposed) {
            _ref.read(balanceProvider.notifier).fetchBalance();
            _ref.read(positionsProvider.notifier).fetchPositions();
            // После подтверждения обновляем сигналы
            fetchSignals();
          }
        });

        return true;
      }
      return false;
    } catch (e) {
      print('Ошибка при подтверждении сигнала: $e');
      return false;
    }
  }

  // Метод для отклонения сигнала
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
        // После отклонения обновляем сигналы
        Future.microtask(() {
          if (!_disposed) {
            fetchSignals();
          }
        });
        return true;
      }
      return false;
    } catch (e) {
      print('Ошибка при отклонении сигнала: $e');
      return false;
    }
  }

  // Метод для получения всех сигналов по тикеру
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
      print('Ошибка при получении сигналов по тикеру: $e');
      return [];
    }
  }

  // Метод для получения истории сигналов
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
      print('Ошибка при получении истории сигналов: $e');
      return [];
    }
  }

  // Метод для удаления тикера из мониторинга
  Future<bool> removeTicker(String ticker) async {
    try {
      final response =
          await http.delete(Uri.parse('$serverUrl/monitor/$ticker'));
      if (response.statusCode == 200) {
        // Обновляем список отслеживаемых тикеров
        await _ref.read(watchlistProvider.notifier).fetchWatchlist();
        // После удаления обновляем сигналы
        await fetchSignals();
        return true;
      }
      return false;
    } catch (e) {
      print('Ошибка при удалении тикера: $e');
      return false;
    }
  }

  // Метод для получения всех категорий сигналов
  Future<Map<String, List<SignalModel>>> getAllSignalCategories() async {
    try {
      // Получаем активные сигналы (pending)
      final pendingResponse = await http.get(Uri.parse('$serverUrl/signals'));
      List<SignalModel> pendingSignals = [];

      if (pendingResponse.statusCode == 200) {
        final List<dynamic> pendingData = jsonDecode(pendingResponse.body);
        pendingSignals =
            pendingData.map((e) => SignalModel.fromJson(e)).toList();
      }

      // Получаем историю (подтвержденные и отклоненные)
      final historyResponse =
          await http.get(Uri.parse('$serverUrl/signals/history'));
      List<SignalModel> historySignals = [];

      if (historyResponse.statusCode == 200) {
        final List<dynamic> historyData = jsonDecode(historyResponse.body);
        historySignals =
            historyData.map((e) => SignalModel.fromJson(e)).toList();
      }

      // Фильтруем сигналы по статусам
      final List<SignalModel> confirmedSignals = historySignals
          .where((signal) => signal.status == 'confirmed')
          .toList();

      final List<SignalModel> rejectedSignals = historySignals
          .where((signal) => signal.status == 'rejected')
          .toList();

      // Возвращаем словарь с категориями сигналов
      return {
        'pending': pendingSignals,
        'confirmed': confirmedSignals,
        'rejected': rejectedSignals,
      };
    } catch (e) {
      print('Ошибка при получении категорий сигналов: $e');
      return {
        'pending': [],
        'confirmed': [],
        'rejected': [],
      };
    }
  }
}

// Класс для управления списком отслеживаемых тикеров
class WatchlistNotifier extends StateNotifier<AsyncValue<List<String>>> {
  bool _disposed = false;

  WatchlistNotifier() : super(const AsyncValue.loading()) {
    // Отложим инициализацию для предотвращения обновления в процессе построения дерева виджетов
    Future.microtask(() {
      if (!_disposed) {
        fetchWatchlist();
      }
    });
  }

  final String serverUrl = 'http://127.0.0.1:8000';

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  Future<void> fetchWatchlist() async {
    if (_disposed) return;

    try {
      state = const AsyncValue.loading();
      final response = await http.get(Uri.parse('$serverUrl/watchlist'));

      if (_disposed) return;

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        final List<String> tickers = data.cast<String>();
        state = AsyncValue.data(tickers);
      } else {
        state = AsyncValue.error(
            'Ошибка при получении списка отслеживаемых тикеров: ${response.statusCode}',
            StackTrace.current);
      }
    } catch (e, stackTrace) {
      if (!_disposed) {
        print('Ошибка при получении списка отслеживаемых тикеров: $e');
        state = AsyncValue.error(e, stackTrace);
      }
    }
  }

  Future<bool> addTicker(String ticker) async {
    if (_disposed) return false;

    try {
      final response = await http.post(
        Uri.parse('$serverUrl/monitor'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'ticker': ticker}),
      );

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
      print('Ошибка при добавлении тикера: $e');
      return false;
    }
  }

  Future<bool> removeTicker(String ticker) async {
    if (_disposed) return false;

    try {
      final response =
          await http.delete(Uri.parse('$serverUrl/monitor/$ticker'));

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
      print('Ошибка при удалении тикера: $e');
      return false;
    }
  }
}

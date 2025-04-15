import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../models/signal_model.dart';
import '../services/notification_service.dart';

// Providers
final signalViewModelProvider =
    StateNotifierProvider<SignalViewModel, AsyncValue<List<SignalModel>>>(
        (ref) => SignalViewModel(ref));

final watchlistProvider =
    StateNotifierProvider<WatchlistNotifier, AsyncValue<List<String>>>(
        (ref) => WatchlistNotifier());

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

  Future<void> addTicker(String ticker,
      {AnalysisModelType modelType = AnalysisModelType.rsiModel}) async {
    if (_disposed) return;

    // Delegate adding ticker to WatchlistNotifier
    final success = await _ref
        .read(watchlistProvider.notifier)
        .addTicker(ticker, modelType: modelType);

    if (success && !_disposed) {
      // Update signals after adding ticker
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
      final response = await http.post(
        Uri.parse('$serverUrl/tickers'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'ticker': ticker, 'model_type': modelType.value}),
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

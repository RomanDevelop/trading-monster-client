import 'dart:async';
import 'package:client/views/portfolio_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../viewmodels/signal_view_model.dart';
import '../database/signal_database.dart';
import '../models/signal_model.dart';

class SignalScreen extends ConsumerStatefulWidget {
  const SignalScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<SignalScreen> createState() => _SignalScreenState();
}

class _SignalScreenState extends ConsumerState<SignalScreen>
    with AutomaticKeepAliveClientMixin, SingleTickerProviderStateMixin {
  // Keep this page in memory when switching tabs
  @override
  bool get wantKeepAlive => true;

  Timer? _timer;
  Map<String, bool> _activePositions = {};
  Map<String, Map<String, dynamic>> _positionsData = {};
  bool _isLoading = false;
  String? _error;

  // Анимация для плавного появления контента
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  // Initial ticker input for testing (for development)
  final TextEditingController _tickerController = TextEditingController();

  @override
  void initState() {
    super.initState();

    // Инициализация анимации
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );

    // Delay initialization until after widget build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadActivePositions();
        ref.read(signalViewModelProvider.notifier).fetchSignals();
        _timer = Timer.periodic(const Duration(seconds: 15), (_) {
          if (mounted) {
            ref.read(signalViewModelProvider.notifier).fetchSignals();
            _loadActivePositions();
          }
        });

        // Запускаем анимацию
        _animationController.forward();
      }
    });
  }

  Future<void> _loadActivePositions() async {
    if (!mounted) return;

    final signalState = ref.read(signalViewModelProvider);

    try {
      if (signalState is AsyncData) {
        final List<SignalModel> signals =
            List<SignalModel>.from(signalState.value ?? []);
        final Map<String, bool> positions = {};
        final Map<String, Map<String, dynamic>> positionsData = {};

        if (signals.isNotEmpty) {
          for (final signal in signals) {
            final position =
                await SignalDatabase.getActivePosition(signal.ticker);
            final hasPosition = position != null;

            positions[signal.ticker] = hasPosition;

            if (hasPosition) {
              // Добавляем данные о P&L
              final pnl = SignalDatabase.calculatePnL(position, signal.close);
              final pnlPercent =
                  SignalDatabase.calculatePnLPercent(position, signal.close);

              positionsData[signal.ticker] = {
                ...position,
                'current_price': signal.close,
                'pnl': pnl,
                'pnl_percent': pnlPercent,
              };
            }
          }
        }

        if (mounted) {
          setState(() {
            _activePositions = positions;
            _positionsData = positionsData;
          });
        }
      }
    } catch (e) {
      print('Error loading active positions: $e');
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _tickerController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    final signalState = ref.watch(signalViewModelProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return RepaintBoundary(
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'Trading Monster App',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                colorScheme.surface,
                colorScheme.surface.withOpacity(0.9),
              ],
            ),
          ),
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 500),
                      switchInCurve: Curves.easeInOut,
                      switchOutCurve: Curves.easeInOut,
                      transitionBuilder: (child, animation) {
                        return FadeTransition(
                          opacity: animation,
                          child: SlideTransition(
                            position: Tween<Offset>(
                              begin: const Offset(0.0, 0.1),
                              end: Offset.zero,
                            ).animate(animation),
                            child: child,
                          ),
                        );
                      },
                      child: signalState.when(
                        loading: () => const Center(
                          key: ValueKey('loading'),
                          child: CircularProgressIndicator(),
                        ),
                        error: (e, _) => Center(
                          key: ValueKey('error'),
                          child: SingleChildScrollView(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.error_outline,
                                    size: 48, color: Colors.redAccent),
                                const SizedBox(height: 16),
                                Text(
                                  'Error: $e',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(fontSize: 16),
                                ),
                                const SizedBox(height: 16),
                                ElevatedButton(
                                  onPressed: () {
                                    ref
                                        .read(signalViewModelProvider.notifier)
                                        .fetchSignals();
                                  },
                                  child: const Text('Retry'),
                                ),
                              ],
                            ),
                          ),
                        ),
                        data: (signals) => signals.isEmpty
                            ? _buildEmptyState()
                            : RepaintBoundary(
                                child: _buildSignalsList(signals, colorScheme),
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.bar_chart, size: 80, color: Colors.grey),
            const SizedBox(height: 24),
            const Text(
              'No active signals',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Go to the "Monitoring" tab and add stock tickers you want to track',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            const Text(
              'The system will only analyze tickers you explicitly specify',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSignalsList(List<dynamic> signals, ColorScheme colorScheme) {
    return ListView.builder(
      key: ValueKey('signals_list_${signals.length}'),
      itemCount: signals.length,
      padding: const EdgeInsets.only(top: 8, bottom: 16),
      itemBuilder: (context, index) {
        final signal = signals[index];
        final hasActivePosition = _activePositions[signal.ticker] ?? false;
        final positionData = _positionsData[signal.ticker];

        // Анимация для появления элементов списка один за другим
        return AnimatedBuilder(
          animation: _animationController,
          builder: (context, child) {
            // Задержка появления каждого элемента
            final double delay = index * 0.1;
            final Animation<double> delayedAnimation = CurvedAnimation(
              parent: _animationController,
              curve: Interval(
                delay.clamp(0.0, 0.9), // Ограничиваем задержку
                (delay + 0.4).clamp(0.0, 1.0),
                curve: Curves.easeOut,
              ),
            );

            return FadeTransition(
              opacity: delayedAnimation,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0.0, 0.2),
                  end: Offset.zero,
                ).animate(delayedAnimation),
                child: child,
              ),
            );
          },
          child: RepaintBoundary(
            child: _buildSignalCard(
                signal, hasActivePosition, positionData, colorScheme),
          ),
        );
      },
    );
  }

  Widget _buildSignalCard(SignalModel signal, bool hasActivePosition,
      Map<String, dynamic>? positionData, ColorScheme colorScheme) {
    // Определяем цвет в зависимости от типа сигнала
    final Color signalColor = signal.signal.toLowerCase() == 'long'
        ? Colors.greenAccent.shade700
        : signal.signal.toLowerCase() == 'short'
            ? Colors.redAccent.shade700
            : colorScheme.primary;

    // Получаем тип модели
    final modelType = signal.modelType != null
        ? getModelTypeFromString(signal.modelType)
        : AnalysisModelType.rsiModel;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        elevation: 2,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: signalColor.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Тикер и тип сигнала
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: signalColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        signal.ticker,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: signalColor,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: signalColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        signal.signal.toUpperCase(),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: signalColor,
                        ),
                      ),
                    ),
                    // Индикатор модели анализа
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: colorScheme.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            modelType.icon,
                            size: 14,
                            color: colorScheme.primary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            modelType.displayName,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (hasActivePosition)
                      Padding(
                        padding: const EdgeInsets.only(left: 0),
                        child: Tooltip(
                          message: 'Active position',
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.amber.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.amber, width: 1),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.account_balance_wallet,
                                  size: 14,
                                  color: Colors.amber.shade800,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'In portfolio',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.amber.shade800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),

                // Статус сигнала
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: _buildSignalStatusBadge(signal, colorScheme),
                ),

                // Процент изменения
                const SizedBox(height: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color:
                        (signal.changePercent >= 0 ? Colors.green : Colors.red)
                            .withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Change: ${signal.changePercent.toStringAsFixed(2)}%',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color:
                          signal.changePercent >= 0 ? Colors.green : Colors.red,
                    ),
                  ),
                ),

                // Данные активной позиции (если есть)
                if (hasActivePosition && positionData != null)
                  _buildPositionDetails(positionData, colorScheme),

                // Сообщение сигнала
                const SizedBox(height: 12),
                Text(
                  signal.message,
                  style: TextStyle(
                    fontSize: 14,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),

                // Детали цен
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _priceItem('Open', signal.open.toString()),
                    _priceItem('Close', signal.close.toString()),
                    _priceItem('EPS Growth',
                        '${signal.epsGrowth.toStringAsFixed(2)}%'),
                  ],
                ),

                // Кнопки действий в зависимости от статуса сигнала
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    // Для сигналов в ожидании (pending)
                    if (signal.status == 'pending' && !hasActivePosition) ...[
                      // Кнопка отклонения
                      OutlinedButton.icon(
                        onPressed: () => _rejectSignal(signal),
                        icon: const Icon(Icons.cancel_outlined),
                        label: const Text('Reject'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Кнопка подтверждения
                      ElevatedButton.icon(
                        onPressed: () => _showConfirmTradeDialog(
                          context,
                          signal,
                          isClosing: false,
                        ),
                        icon: const Icon(Icons.check_circle_outline),
                        label: const Text('Confirm'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: signalColor,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ]
                    // Для подтвержденных сигналов с активной позицией
                    else if (signal.status == 'confirmed' &&
                        hasActivePosition) ...[
                      // Кнопка закрытия позиции
                      ElevatedButton.icon(
                        onPressed: () => _showConfirmTradeDialog(
                          context,
                          signal,
                          isClosing: true,
                        ),
                        icon: const Icon(Icons.remove_circle_outline),
                        label: const Text('Close Position'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey.shade700,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ]
                    // Для отклоненных сигналов или подтвержденных без позиции
                    else if (signal.status == 'rejected' ||
                        (signal.status == 'confirmed' &&
                            !hasActivePosition)) ...[
                      // Информационное сообщение
                      Text(
                        signal.status == 'rejected'
                            ? 'Signal rejected'
                            : 'Position closed',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Виджет для отображения статуса сигнала
  Widget _buildStatusBadge(String text, Color color, ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.5), width: 1),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  // Method to reject signal
  void _rejectSignal(SignalModel signal) async {
    final success = await ref
        .read(signalViewModelProvider.notifier)
        .rejectSignal(signal.id);

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Signal rejected'),
          backgroundColor: Colors.grey,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to reject signal'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildPositionDetails(
      Map<String, dynamic> position, ColorScheme colorScheme) {
    final double pnl = position['pnl'] as double;
    final double pnlPercent = position['pnl_percent'] as double;
    final String signalType = position['signal_type'] as String;
    final double entryPrice = position['price'] as double;
    final double currentPrice = position['current_price'] as double;
    final double quantity = position['quantity'] as double;

    final bool isProfit = pnl > 0;
    final Color pnlColor =
        isProfit ? Colors.green.shade700 : Colors.red.shade700;

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceVariant.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colorScheme.outlineVariant.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Position ${signalType.toUpperCase()}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: pnlColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${pnl.toStringAsFixed(2)} \$ (${pnlPercent.toStringAsFixed(2)}%)',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: pnlColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _positionDetailItem(
                  'Entry', '\$${entryPrice.toStringAsFixed(2)}'),
              _positionDetailItem(
                  'Current', '\$${currentPrice.toStringAsFixed(2)}'),
              _positionDetailItem('Quantity', quantity.toStringAsFixed(2)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _positionDetailItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _priceItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  // Method to show trade confirmation dialog
  void _showConfirmTradeDialog(BuildContext context, SignalModel signal,
      {required bool isClosing}) {
    final double currentPrice = signal.close;
    final String action = isClosing ? 'close' : 'open';
    final String signalTypeText =
        signal.signal.toLowerCase() == 'long' ? 'LONG (buy)' : 'SHORT (sell)';

    showDialog(
      context: context,
      builder: (BuildContext context) {
        double quantity = 1.0; // Default quantity

        return StatefulBuilder(builder: (context, setState) {
          final double totalValue = quantity * currentPrice;

          return AlertDialog(
            title: Text(isClosing
                ? 'Close position ${signal.ticker}'
                : 'Open position ${signal.ticker}'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('You are about to $action a position:'),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Text('Ticker: ',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    Text(signal.ticker, style: const TextStyle(fontSize: 16))
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Text('Type: ',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    Text(signalTypeText, style: const TextStyle(fontSize: 16))
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Text('Current price: ',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    Text('\$${currentPrice.toStringAsFixed(2)}',
                        style: const TextStyle(fontSize: 16))
                  ],
                ),
                if (!isClosing) ...[
                  const SizedBox(height: 16),
                  const Text('Quantity:'),
                  Slider(
                    value: quantity,
                    min: 0.1,
                    max: 10.0,
                    divisions: 99,
                    label: quantity.toStringAsFixed(1),
                    onChanged: (value) {
                      setState(() {
                        quantity = value;
                      });
                    },
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(quantity.toStringAsFixed(1)),
                      Text('Amount: \$${totalValue.toStringAsFixed(2)}',
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (isClosing) {
                    await _closePosition(signal);
                  } else {
                    // Confirm signal via API
                    final success = await ref
                        .read(signalViewModelProvider.notifier)
                        .confirmSignal(signal.id, quantity);

                    if (success) {
                      // Then open position locally
                      await _openPosition(signal, quantity);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Failed to confirm signal'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                  Navigator.pop(context);
                  _loadActivePositions();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: isClosing
                      ? Colors.grey.shade700
                      : signal.signal.toLowerCase() == 'long'
                          ? Colors.greenAccent.shade700
                          : Colors.redAccent.shade700,
                  foregroundColor: Colors.white,
                ),
                child: Text(isClosing ? 'Close position' : 'Confirm signal'),
              ),
            ],
          );
        });
      },
    );
  }

  // Method for opening a position
  Future<void> _openPosition(SignalModel signal, double quantity) async {
    final ticker = signal.ticker;
    final signalType = signal.signal.toLowerCase();
    final price = signal.close;

    // Check if position already exists for this ticker
    final existingPosition = await SignalDatabase.getActivePosition(ticker);
    if (existingPosition != null) {
      return; // Position already exists, exit
    }

    // Get current balance
    final currentBalance = await SignalDatabase.getCurrentBalance();

    // Calculate position value
    final double positionValue = quantity * price;

    // Check if there's enough money (only for long)
    if (signalType == 'long' && positionValue > currentBalance) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Not enough money to open position'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Add entry to portfolio
    await SignalDatabase.insertPortfolio(
      ticker: ticker,
      signalType: signalType,
      price: price,
      quantity: quantity,
      balanceLeft:
          0, // This value will be recalculated in insertPortfolio method
    );

    // Update UI
    _loadActivePositions();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
            'Position $ticker opened at price \$${price.toStringAsFixed(2)}'),
        backgroundColor: Colors.green,
      ),
    );
  }

  // Method for closing a position
  Future<void> _closePosition(SignalModel signal) async {
    final ticker = signal.ticker;
    final closePrice = signal.close;

    // Get active position
    final position = await SignalDatabase.getActivePosition(ticker);
    if (position == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Position not found'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Calculate P&L
    final double pnl = SignalDatabase.calculatePnL(position, closePrice);
    final double pnlPercent =
        SignalDatabase.calculatePnLPercent(position, closePrice);

    // Get balance before closing
    final double balanceBefore = await SignalDatabase.getCurrentBalance();

    // Close position in database
    await SignalDatabase.closePositionByTicker(ticker, closePrice);

    // Get balance after closing
    final double balanceAfter = await SignalDatabase.getCurrentBalance();
    final double balanceDiff = balanceAfter - balanceBefore;

    print(
        "Balance before close: $balanceBefore, after: $balanceAfter, diff: $balanceDiff");

    // IMPORTANT: Update positions AND reset cache
    setState(() {
      // Immediately remove position from local cache
      _activePositions[ticker] = false;
      if (_positionsData.containsKey(ticker)) {
        _positionsData.remove(ticker);
      }
    });

    // Full data update
    await _loadActivePositions();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Position $ticker closed. P&L: \$${pnl.toStringAsFixed(2)} (${pnlPercent.toStringAsFixed(2)}%). Balance: \$${balanceAfter.toStringAsFixed(2)}',
        ),
        backgroundColor: pnl >= 0 ? Colors.green : Colors.red,
      ),
    );
  }

  // Method to display signal status
  Widget _buildSignalStatusBadge(SignalModel signal, ColorScheme colorScheme) {
    if (signal.status == 'pending') {
      return _buildStatusBadge('Pending', Colors.orange, colorScheme);
    } else if (signal.status == 'confirmed') {
      return _buildStatusBadge('Confirmed', Colors.green, colorScheme);
    } else if (signal.status == 'rejected') {
      return _buildStatusBadge('Rejected', Colors.red, colorScheme);
    } else {
      return const SizedBox.shrink();
    }
  }
}

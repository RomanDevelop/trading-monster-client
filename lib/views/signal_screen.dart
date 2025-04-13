import 'dart:async';
import 'package:client/views/history_screen.dart';
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

class _SignalScreenState extends ConsumerState<SignalScreen> {
  Timer? _timer;
  Map<String, bool> _activePositions = {};
  Map<String, Map<String, dynamic>> _positionsData = {};

  @override
  void initState() {
    super.initState();

    // Откладываем инициализацию после построения виджета
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
      print('Ошибка при загрузке активных позиций: $e');
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final signalState = ref.watch(signalViewModelProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '📊 Trading Signal Bot',
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
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Expanded(
                child: signalState.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error_outline,
                              size: 48, color: Colors.redAccent),
                          const SizedBox(height: 16),
                          Text(
                            'Ошибка: $e',
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
                            child: const Text('Повторить'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  data: (signals) => signals.isEmpty
                      ? _buildEmptyState()
                      : _buildSignalsList(signals, colorScheme),
                ),
              ),
            ],
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
              'Нет активных сигналов',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Перейдите на вкладку "Мониторинг" и добавьте тикеры акций, которые хотите отслеживать',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            const Text(
              'Система будет анализировать только явно указанные вами тикеры',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSignalsList(List<dynamic> signals, ColorScheme colorScheme) {
    return RepaintBoundary(
      child: ListView.builder(
        itemCount: signals.length,
        padding: const EdgeInsets.only(top: 8, bottom: 16),
        itemBuilder: (context, index) {
          final signal = signals[index];
          final hasActivePosition = _activePositions[signal.ticker] ?? false;
          final positionData = _positionsData[signal.ticker];

          // Определяем цвет в зависимости от типа сигнала
          final Color signalColor = signal.signal.toLowerCase() == 'long'
              ? Colors.greenAccent.shade700
              : signal.signal.toLowerCase() == 'short'
                  ? Colors.redAccent.shade700
                  : colorScheme.primary;

          return RepaintBoundary(
            child: Padding(
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
                            if (hasActivePosition)
                              Padding(
                                padding: const EdgeInsets.only(left: 0),
                                child: Tooltip(
                                  message: 'Есть активная позиция',
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.amber.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                          color: Colors.amber, width: 1),
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
                                          'В портфеле',
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
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: (signal.changePercent >= 0
                                    ? Colors.green
                                    : Colors.red)
                                .withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Изменение: ${signal.changePercent.toStringAsFixed(2)}%',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: signal.changePercent >= 0
                                  ? Colors.green
                                  : Colors.red,
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
                            if (signal.status == 'pending' &&
                                !hasActivePosition) ...[
                              // Кнопка отклонения
                              OutlinedButton.icon(
                                onPressed: () => _rejectSignal(signal),
                                icon: const Icon(Icons.cancel_outlined),
                                label: const Text('Отклонить'),
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
                                label: const Text('Подтвердить'),
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
                                label: const Text('Закрыть позицию'),
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
                                    ? 'Сигнал отклонен'
                                    : 'Позиция закрыта',
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
            ),
          );
        },
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

  // Метод для отклонения сигнала
  void _rejectSignal(SignalModel signal) async {
    final success = await ref
        .read(signalViewModelProvider.notifier)
        .rejectSignal(signal.id);

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Сигнал отклонен'),
          backgroundColor: Colors.grey,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Не удалось отклонить сигнал'),
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
                'Позиция ${signalType.toUpperCase()}',
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
              _positionDetailItem('Вход', '\$${entryPrice.toStringAsFixed(2)}'),
              _positionDetailItem(
                  'Текущая', '\$${currentPrice.toStringAsFixed(2)}'),
              _positionDetailItem('Количество', quantity.toStringAsFixed(2)),
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

  // Метод для отображения диалога подтверждения сделки
  void _showConfirmTradeDialog(BuildContext context, SignalModel signal,
      {required bool isClosing}) {
    final double currentPrice = signal.close;
    final String action = isClosing ? 'закрыть' : 'открыть';
    final String signalTypeText = signal.signal.toLowerCase() == 'long'
        ? 'LONG (покупка)'
        : 'SHORT (продажа)';

    showDialog(
      context: context,
      builder: (BuildContext context) {
        double quantity = 1.0; // Количество по умолчанию

        return StatefulBuilder(builder: (context, setState) {
          final double totalValue = quantity * currentPrice;

          return AlertDialog(
            title: Text(isClosing
                ? 'Закрыть позицию ${signal.ticker}'
                : 'Открыть позицию ${signal.ticker}'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Вы собираетесь $action позицию:'),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Text('Тикер: ',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    Text(signal.ticker, style: const TextStyle(fontSize: 16))
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Text('Тип: ',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    Text(signalTypeText, style: const TextStyle(fontSize: 16))
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Text('Текущая цена: ',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    Text('\$${currentPrice.toStringAsFixed(2)}',
                        style: const TextStyle(fontSize: 16))
                  ],
                ),
                if (!isClosing) ...[
                  const SizedBox(height: 16),
                  const Text('Количество:'),
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
                      Text('Сумма: \$${totalValue.toStringAsFixed(2)}',
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Отмена'),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (isClosing) {
                    await _closePosition(signal);
                  } else {
                    // Подтверждаем сигнал через API
                    final success = await ref
                        .read(signalViewModelProvider.notifier)
                        .confirmSignal(signal.id, quantity);

                    if (success) {
                      // Затем открываем позицию локально
                      await _openPosition(signal, quantity);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Не удалось подтвердить сигнал'),
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
                child:
                    Text(isClosing ? 'Закрыть позицию' : 'Подтвердить сигнал'),
              ),
            ],
          );
        });
      },
    );
  }

  // Метод для открытия позиции
  Future<void> _openPosition(SignalModel signal, double quantity) async {
    final ticker = signal.ticker;
    final signalType = signal.signal.toLowerCase();
    final price = signal.close;

    // Проверяем, не существует ли уже позиция по данному тикеру
    final existingPosition = await SignalDatabase.getActivePosition(ticker);
    if (existingPosition != null) {
      return; // Позиция уже существует, выходим
    }

    // Получаем текущий баланс
    final currentBalance = await SignalDatabase.getCurrentBalance();

    // Рассчитываем стоимость позиции
    final double positionValue = quantity * price;

    // Проверяем, достаточно ли денег (только для long)
    if (signalType == 'long' && positionValue > currentBalance) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Недостаточно денег для открытия позиции'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Добавляем запись в портфель
    await SignalDatabase.insertPortfolio(
      ticker: ticker,
      signalType: signalType,
      price: price,
      quantity: quantity,
      balanceLeft: 0, // Это значение будет пересчитано в методе insertPortfolio
    );

    // Обновляем UI
    _loadActivePositions();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
            'Позиция $ticker открыта по цене \$${price.toStringAsFixed(2)}'),
        backgroundColor: Colors.green,
      ),
    );
  }

  // Метод для закрытия позиции
  Future<void> _closePosition(SignalModel signal) async {
    final ticker = signal.ticker;
    final closePrice = signal.close;

    // Получаем активную позицию
    final position = await SignalDatabase.getActivePosition(ticker);
    if (position == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Позиция не найдена'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Рассчитываем P&L
    final double pnl = SignalDatabase.calculatePnL(position, closePrice);
    final double pnlPercent =
        SignalDatabase.calculatePnLPercent(position, closePrice);

    // Получаем баланс до закрытия
    final double balanceBefore = await SignalDatabase.getCurrentBalance();

    // Закрываем позицию в базе данных
    await SignalDatabase.closePositionByTicker(ticker, closePrice);

    // Получаем баланс после закрытия
    final double balanceAfter = await SignalDatabase.getCurrentBalance();
    final double balanceDiff = balanceAfter - balanceBefore;

    print(
        "Balance before close: $balanceBefore, after: $balanceAfter, diff: $balanceDiff");

    // ВАЖНО: Обновляем позиции И сбрасываем кэш
    setState(() {
      // Сразу удаляем позицию из локального кэша
      _activePositions[ticker] = false;
      if (_positionsData.containsKey(ticker)) {
        _positionsData.remove(ticker);
      }
    });

    // Полное обновление данных
    await _loadActivePositions();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Позиция $ticker закрыта. P&L: \$${pnl.toStringAsFixed(2)} (${pnlPercent.toStringAsFixed(2)}%). Баланс: \$${balanceAfter.toStringAsFixed(2)}',
        ),
        backgroundColor: pnl >= 0 ? Colors.green : Colors.red,
      ),
    );
  }

  // Метод для отображения статуса сигнала
  Widget _buildSignalStatusBadge(SignalModel signal, ColorScheme colorScheme) {
    if (signal.status == 'pending') {
      return _buildStatusBadge('Ожидает', Colors.orange, colorScheme);
    } else if (signal.status == 'confirmed') {
      return _buildStatusBadge('Подтвержден', Colors.green, colorScheme);
    } else if (signal.status == 'rejected') {
      return _buildStatusBadge('Отклонен', Colors.red, colorScheme);
    } else {
      return const SizedBox.shrink();
    }
  }
}

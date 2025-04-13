import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/signal_database.dart';
import '../viewmodels/signal_view_model.dart';
import '../models/signal_model.dart';

class PortfolioScreen extends ConsumerStatefulWidget {
  const PortfolioScreen({super.key});

  @override
  ConsumerState<PortfolioScreen> createState() => _PortfolioScreenState();
}

class _PortfolioScreenState extends ConsumerState<PortfolioScreen> {
  List<Map<String, dynamic>> trades = [];
  double currentBalance = 1000.0;
  bool _isLoading = true;
  double totalPnL = 0.0;
  double totalPortfolioValue = 0.0;
  double totalAssetValue = 0.0;

  @override
  void initState() {
    super.initState();
    loadPortfolio();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    loadPortfolio();
  }

  Future<void> loadPortfolio() async {
    try {
      setState(() {
        _isLoading = true;
      });

      // Даем виджетам время для отрисовки
      await Future.delayed(const Duration(milliseconds: 100));

      // Получаем текущий баланс
      final balance = await SignalDatabase.getCurrentBalance();
      // Получаем ТОЛЬКО активные позиции, явно исключая BALANCE записи
      final result = await SignalDatabase.getActivePositions();

      // Проверка, не был ли виджет демонтирован
      if (!mounted) return;

      print(
          "Portfolio loading - Balance: $balance, Active positions: ${result.length}");

      if (result.isNotEmpty) {
        // Получаем текущие цены для расчета P&L
        final signals = await _fetchCurrentPrices();
        double pnlSum = 0.0;
        double portfolioValue = 0.0;
        double investedValue = 0.0; // Реально инвестированная сумма

        // Рассчитываем P&L для каждой позиции
        final updatedTrades = result.map((trade) {
          final ticker = trade['ticker'] as String;
          // Если тикер отсутствует в списке текущих сигналов, используем цену из базы данных
          final currentPrice = signals[ticker] ?? trade['price'];

          final double pnl = SignalDatabase.calculatePnL(trade, currentPrice);
          final double pnlPercent =
              SignalDatabase.calculatePnLPercent(trade, currentPrice);

          // Стоимость позиции
          final double quantity = trade['quantity'] as double;
          final double entryPrice = trade['price'] as double;

          // Текущая стоимость позиции
          final double positionValue = quantity * currentPrice;

          // Инвестированная стоимость
          final double investedAmount = quantity * entryPrice;

          pnlSum += pnl;
          portfolioValue += positionValue;
          investedValue += investedAmount;

          print("Position $ticker: Value=$positionValue, P&L=$pnl");

          return {
            ...trade,
            'current_price': currentPrice,
            'pnl': pnl,
            'pnl_percent': pnlPercent,
            'position_value': positionValue,
            'invested_value': investedAmount,
          };
        }).toList();

        setState(() {
          trades = updatedTrades;
          currentBalance = balance; // Используем полученный баланс
          totalPnL = pnlSum;
          totalPortfolioValue = portfolioValue;
          // Общая стоимость портфеля = баланс + инвестировано
          totalAssetValue = balance + portfolioValue;
          _isLoading = false;
        });

        print(
            "Portfolio updated - Balance: $balance, Positions value: $portfolioValue, Total: $totalAssetValue");
      } else {
        setState(() {
          trades = [];
          currentBalance = balance; // Используем полученный баланс
          totalPnL = 0.0;
          totalPortfolioValue = 0.0;
          totalAssetValue = balance; // Только баланс
          _isLoading = false;
        });

        print("Portfolio updated - Empty portfolio, Balance: $balance");
      }
    } catch (e) {
      // Проверка, не был ли виджет демонтирован
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        trades = [];
      });

      // Показываем ошибку только если виджет все еще в дереве
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ошибка загрузки портфеля: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<Map<String, double>> _fetchCurrentPrices() async {
    try {
      final signalState = ref.read(signalViewModelProvider);
      if (signalState is AsyncData) {
        final List<SignalModel> signals =
            List<SignalModel>.from(signalState.value ?? []);
        if (signals.isNotEmpty) {
          return {
            for (var signal in signals) signal.ticker: signal.close,
          };
        }
      }
    } catch (e) {
      debugPrint('Ошибка при получении текущих цен: $e');
    }

    return {};
  }

  Future<void> clearPortfolio() async {
    await SignalDatabase.clearPortfolio();
    setState(() {
      trades.clear();
      currentBalance = 1000.0;
      totalPnL = 0.0;
      totalPortfolioValue = 0.0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: Row(
          children: [
            const Icon(Icons.account_balance, size: 24),
            const SizedBox(width: 8),
            const Text(
              'Портфель',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white70),
            tooltip: 'Обновить данные',
            onPressed: loadPortfolio,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.white70),
            tooltip: 'Очистить портфель',
            onPressed: () {
              showDialog(
                context: context,
                builder: (BuildContext context) {
                  return _buildClearDialog();
                },
              );
            },
          )
        ],
      ),
      body: RepaintBoundary(
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black,
                Color(0xFF101010),
              ],
            ),
          ),
          child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white70),
                  ),
                )
              : Column(
                  children: [
                    RepaintBoundary(
                      child: _buildSummaryCard(),
                    ),
                    Expanded(
                      child: trades.isEmpty
                          ? _buildEmptyState()
                          : _buildTradesList(),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildClearDialog() {
    return Dialog(
      backgroundColor: const Color(0xFF151515),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.warning_amber_rounded,
                color: Color(0xFFFFA726), size: 48),
            const SizedBox(height: 16),
            const Text(
              'Очистить портфель?',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Все сделки будут удалены. Баланс будет сброшен до 1000\$',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white70,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white70,
                  ),
                  child: const Text('Отмена'),
                ),
                ElevatedButton(
                  onPressed: () {
                    clearPortfolio();
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Портфель очищен'),
                        backgroundColor: Color(0xFF1E1E1E),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2D2D2D),
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Очистить'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard() {
    final bool isProfitable = totalPnL >= 0;
    final Color pnlColor = isProfitable
        ? const Color(0xFF66BB6A) // Green
        : const Color(0xFFE57373); // Red

    // Для отладки
    print(
        "Portfolio data: Balance=$currentBalance, PnL=$totalPnL, PositionsValue=$totalPortfolioValue");

    // Общая стоимость = текущий баланс + стоимость открытых позиций
    final double totalValue = currentBalance + totalPortfolioValue;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: RepaintBoundary(
        child: Card(
          elevation: 0,
          color: const Color(0xFF111111),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(
              color: Color(0xFF333333),
              width: 1,
            ),
          ),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Баланс
                _summaryItem(
                  'Доступный баланс',
                  '\$${currentBalance.toStringAsFixed(2)}',
                  Colors.white,
                ),

                // Прибыль/убыток портфеля
                if (trades.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF222222),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isProfitable
                            ? const Color(0xFF1B5E20).withOpacity(0.3)
                            : const Color(0xFFB71C1C).withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isProfitable
                              ? Icons.trending_up
                              : Icons.trending_down,
                          color: pnlColor,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'P&L Портфеля',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '\$${totalPnL.toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: pnlColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Стоимость позиций и общая стоимость
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _summaryItem(
                          'Стоимость позиций',
                          '\$${totalPortfolioValue.toStringAsFixed(2)}',
                          Colors.white70,
                        ),
                      ),
                      const SizedBox(width: 24),
                      Expanded(
                        child: _summaryItem(
                          'Общая стоимость',
                          '\$${totalValue.toStringAsFixed(2)}',
                          Colors.white,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _summaryItem(String label, String value, Color valueColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white60,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: valueColor,
            fontSize: 20,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: RepaintBoundary(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.account_balance_wallet_outlined,
                  size: 64, color: Colors.white30),
              const SizedBox(height: 24),
              const Text(
                'Ваш портфель пуст',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w300,
                  color: Colors.white,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Добавьте тикеры и подтвердите торговые сигналы, чтобы открыть виртуальные позиции',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.white60),
              ),
              const SizedBox(height: 32),
              OutlinedButton.icon(
                onPressed: loadPortfolio,
                icon: const Icon(Icons.refresh),
                label: const Text('Обновить'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white30),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTradesList() {
    return RepaintBoundary(
      child: ListView.builder(
        itemCount: trades.length,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemBuilder: (context, index) {
          final trade = trades[index];
          final isLong = trade['signal_type'].toLowerCase() == 'long';

          final signalColor = isLong
              ? const Color(0xFF66BB6A) // Green
              : const Color(0xFFE57373); // Red

          final double entryPrice = trade['price'];
          final double currentPrice = trade['current_price'] ?? entryPrice;
          final double pnl = trade['pnl'] ?? 0.0;
          final double pnlPercent = trade['pnl_percent'] ?? 0.0;
          final double quantity = trade['quantity'];
          final double positionValue =
              trade['position_value'] ?? (quantity * currentPrice);

          final bool isProfitable = pnl >= 0;
          final Color pnlColor =
              isProfitable ? const Color(0xFF66BB6A) : const Color(0xFFE57373);

          return RepaintBoundary(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Card(
                elevation: 0,
                color: const Color(0xFF111111),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: signalColor.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Заголовок и тикер
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: signalColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: signalColor.withOpacity(0.3),
                                width: 1,
                              ),
                            ),
                            child: Text(
                              trade['ticker'],
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: signalColor,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: signalColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: signalColor.withOpacity(0.3),
                                width: 1,
                              ),
                            ),
                            child: Text(
                              trade['signal_type'].toUpperCase(),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: signalColor,
                              ),
                            ),
                          ),
                          const Spacer(),
                          Icon(
                            isProfitable
                                ? Icons.arrow_upward
                                : Icons.arrow_downward,
                            color: pnlColor,
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${pnlPercent.toStringAsFixed(2)}%',
                            style: TextStyle(
                              color: pnlColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),

                      // Инфо о позиции
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _tradeInfoItem(
                              'Вход',
                              '\$${entryPrice.toStringAsFixed(2)}',
                              Colors.white70,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _tradeInfoItem(
                              'Текущая',
                              '\$${currentPrice.toStringAsFixed(2)}',
                              currentPrice > entryPrice
                                  ? const Color(0xFF66BB6A)
                                  : currentPrice < entryPrice
                                      ? const Color(0xFFE57373)
                                      : Colors.white70,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _tradeInfoItem(
                              'Кол-во',
                              quantity.toStringAsFixed(2),
                              Colors.white70,
                            ),
                          ),
                        ],
                      ),

                      // Стоимость позиции и P&L
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _tradeInfoItem(
                            'Стоимость',
                            '\$${positionValue.toStringAsFixed(2)}',
                            Colors.white,
                          ),
                          _tradeInfoItem(
                            'P&L',
                            '\$${pnl.toStringAsFixed(2)}',
                            pnlColor,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _tradeInfoItem(String label, String value, Color valueColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.white38,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}

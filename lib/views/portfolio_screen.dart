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
          content: Text('Failed to load portfolio: $e'),
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
      debugPrint('Error fetching current prices: $e');
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
              'Portfolio',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white70),
            tooltip: 'Refresh data',
            onPressed: loadPortfolio,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.white70),
            tooltip: 'Clear portfolio',
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
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF2D2D2D),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.warning_amber_rounded,
                  color: Color(0xFFFFA726), size: 48),
            ),
            const SizedBox(height: 20),
            const Text(
              'Clear portfolio?',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'All trades will be deleted. Balance will be reset to 1000\$',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white70,
                fontSize: 15,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 28),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: const Color(0xFF1A1A1A),
                    textStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text('Cancel'),
                ),
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFF2D2D2D),
                        Color(0xFF1A1A1A),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    onPressed: () {
                      clearPortfolio();
                      Navigator.of(context).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Portfolio cleared'),
                          backgroundColor: Color(0xFF1E1E1E),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 30, vertical: 14),
                      textStyle: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    child: const Text('Clear'),
                  ),
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
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
      child: RepaintBoundary(
        child: Card(
          elevation: 4,
          color: const Color(0xFF111111),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(
              color: Color(0xFF333333),
              width: 1,
            ),
          ),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF1A1A1A),
                  Color(0xFF0D0D0D),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.4),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Заголовок карточки
                const Row(
                  children: [
                    Icon(
                      Icons.account_balance_wallet,
                      color: Colors.white60,
                      size: 20,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'PORTFOLIO SUMMARY',
                      style: TextStyle(
                        color: Colors.white60,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.0,
                      ),
                    )
                  ],
                ),
                const SizedBox(height: 20),

                // Баланс
                _summaryItem(
                  'Available balance',
                  '\$${currentBalance.toStringAsFixed(2)}',
                  Colors.white,
                ),

                // Прибыль/убыток портфеля
                if (trades.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF191919),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isProfitable
                            ? const Color(0xFF1B5E20).withOpacity(0.5)
                            : const Color(0xFFB71C1C).withOpacity(0.5),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: isProfitable
                              ? const Color(0xFF1B5E20).withOpacity(0.2)
                              : const Color(0xFFB71C1C).withOpacity(0.2),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isProfitable
                              ? Icons.trending_up
                              : Icons.trending_down,
                          color: pnlColor,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'P&L Portfolio',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Text(
                                    '\$${totalPnL.toStringAsFixed(2)}',
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: pnlColor,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '(${(totalPnL / (totalValue - totalPnL) * 100).toStringAsFixed(2)}%)',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: pnlColor.withOpacity(0.7),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Стоимость позиций и общая стоимость
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: _summaryItem(
                          'Positions value',
                          '\$${totalPortfolioValue.toStringAsFixed(2)}',
                          Colors.white70,
                        ),
                      ),
                      Container(
                        height: 40,
                        width: 1,
                        color: const Color(0xFF333333),
                        margin: const EdgeInsets.symmetric(horizontal: 16),
                      ),
                      Expanded(
                        child: _summaryItem(
                          'Total assets',
                          '\$${totalValue.toStringAsFixed(2)}',
                          Colors.white,
                          isBold: true,
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

  Widget _summaryItem(String label, String value, Color valueColor,
      {bool isBold = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white60,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
            color: valueColor,
            fontSize: isBold ? 24 : 20,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
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
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A1A),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFF333333),
                    width: 1,
                  ),
                ),
                child: const Icon(Icons.account_balance_wallet_outlined,
                    size: 64, color: Colors.white38),
              ),
              const SizedBox(height: 28),
              const Text(
                'Your portfolio is empty',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w300,
                  color: Colors.white,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                constraints: const BoxConstraints(maxWidth: 300),
                child: const Text(
                  'Add tickers and confirm trading signals to open virtual positions',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.white60,
                    height: 1.5,
                  ),
                ),
              ),
              const SizedBox(height: 40),
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1A237E), Color(0xFF3949AB)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF1A237E).withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: OutlinedButton.icon(
                  onPressed: loadPortfolio,
                  icon: const Icon(
                    Icons.refresh,
                    size: 22,
                    color: Colors.white,
                  ),
                  label: const Text(
                    'Refresh',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white30, width: 1.5),
                    backgroundColor: Colors.transparent,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 32, vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
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
        padding: const EdgeInsets.all(16),
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
              padding: const EdgeInsets.only(bottom: 16),
              child: Card(
                elevation: 4,
                color: const Color(0xFF111111),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(
                    color: signalColor.withOpacity(0.3),
                    width: 1.5,
                  ),
                ),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        isLong
                            ? const Color(0xFF1A2C1A)
                            : const Color(0xFF2C1A1A),
                        const Color(0xFF0D0D0D),
                      ],
                      stops: const [0.1, 0.6],
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Заголовок и тикер
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: signalColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: signalColor.withOpacity(0.5),
                                  width: 1.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: signalColor.withOpacity(0.15),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Text(
                                trade['ticker'],
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: signalColor,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: signalColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: signalColor.withOpacity(0.5),
                                  width: 1.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: signalColor.withOpacity(0.15),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Text(
                                trade['signal_type'].toUpperCase(),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: signalColor,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: pnlColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: pnlColor.withOpacity(0.5),
                                  width: 1.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: pnlColor.withOpacity(0.15),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    isProfitable
                                        ? Icons.arrow_upward_rounded
                                        : Icons.arrow_downward_rounded,
                                    color: pnlColor,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    '${pnlPercent.toStringAsFixed(2)}%',
                                    style: TextStyle(
                                      color: pnlColor,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        // Инфо о позиции
                        const SizedBox(height: 24),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFF191919),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: const Color(0xFF333333),
                              width: 1,
                            ),
                          ),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: _tradeInfoItem(
                                      'Entry',
                                      '\$${entryPrice.toStringAsFixed(2)}',
                                      Colors.white70,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: _tradeInfoItem(
                                      'Current',
                                      '\$${currentPrice.toStringAsFixed(2)}',
                                      currentPrice > entryPrice
                                          ? const Color(0xFF66BB6A)
                                          : currentPrice < entryPrice
                                              ? const Color(0xFFE57373)
                                              : Colors.white70,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: _tradeInfoItem(
                                      'Quantity',
                                      quantity.toStringAsFixed(2),
                                      Colors.white70,
                                    ),
                                  ),
                                ],
                              ),
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 16),
                                child: Divider(
                                    color: Color(0xFF333333), height: 1),
                              ),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: _tradeInfoItem(
                                      'Value',
                                      '\$${positionValue.toStringAsFixed(2)}',
                                      Colors.white,
                                      isBold: true,
                                    ),
                                  ),
                                  Container(
                                    height: 40,
                                    width: 1,
                                    color: const Color(0xFF333333),
                                    margin: const EdgeInsets.symmetric(
                                        horizontal: 16),
                                  ),
                                  Expanded(
                                    child: _tradeInfoItem(
                                      'P&L',
                                      '\$${pnl.toStringAsFixed(2)}',
                                      pnlColor,
                                      isBold: true,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
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

  Widget _tradeInfoItem(String label, String value, Color valueColor,
      {bool isBold = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            color: Colors.white38,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
            fontSize: isBold ? 18 : 16,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}

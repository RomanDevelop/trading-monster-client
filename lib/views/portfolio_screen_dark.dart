import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../viewmodels/signal_view_model.dart';
import '../models/signal_model.dart';

class PortfolioScreen extends ConsumerStatefulWidget {
  const PortfolioScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<PortfolioScreen> createState() => _PortfolioScreenState();
}

class _PortfolioScreenState extends ConsumerState<PortfolioScreen> {
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Delay initialization until after widget build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _refreshData();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
  }

  Future<void> _refreshData() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Update balance and positions
      await ref.read(balanceProvider.notifier).fetchBalance();
      await ref.read(positionsProvider.notifier).fetchPositions();
    } catch (e) {
      print('Error updating data: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _closePosition(String ticker, double closePrice) async {
    // Request confirmation
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text(
          'Close Position',
          style: TextStyle(color: Colors.white, fontSize: 18),
        ),
        content: Text(
          'Are you sure you want to close the position for $ticker at the current price \$${closePrice.toStringAsFixed(2)}?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child:
                const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child:
                const Text('Close', style: TextStyle(color: Color(0xFF3A79FF))),
          ),
        ],
      ),
    );

    if (confirm == true) {
      if (!mounted) return;

      setState(() {
        _isLoading = true;
      });

      try {
        final success = await ref
            .read(positionsProvider.notifier)
            .closePosition(ticker, closePrice);

        // Use Future.delayed to allow other processes to complete
        await Future.delayed(const Duration(milliseconds: 500));

        if (!mounted) return;

        if (success) {
          // Update balance
          await ref.read(balanceProvider.notifier).fetchBalance();

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Position for $ticker closed successfully'),
                backgroundColor: Colors.green.shade700,
              ),
            );
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error closing position for $ticker'),
                backgroundColor: Colors.red.shade700,
              ),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: $e'),
              backgroundColor: Colors.red.shade700,
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final balanceState = ref.watch(balanceProvider);
    final positionsState = ref.watch(positionsProvider);

    return RepaintBoundary(
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'Portfolio',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _isLoading ? null : _refreshData,
            ),
          ],
        ),
        body: _isLoading
            ? const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF3A79FF)),
                ),
              )
            : RefreshIndicator(
                onRefresh: _refreshData,
                color: const Color(0xFF3A79FF),
                backgroundColor: const Color(0xFF1A1A1A),
                child: CustomScrollView(
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(
                      child: _buildBalanceCard(balanceState),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Active Positions',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            _buildPositionsCount(positionsState),
                          ],
                        ),
                      ),
                    ),
                    _buildPositionsList(positionsState),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildBalanceCard(AsyncValue<double> balanceState) {
    return RepaintBoundary(
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1A1A1A), Color(0xFF0E0E0E)],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
          border: Border.all(
            color: Colors.white.withOpacity(0.05),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Current Balance',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white70,
                  ),
                ),
                Icon(
                  Icons.account_balance_wallet,
                  color: Color(0xFF3A79FF),
                  size: 24,
                ),
              ],
            ),
            const SizedBox(height: 12),
            balanceState.when(
              data: (balance) => Text(
                '\$${balance.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              loading: () => const SizedBox(
                height: 36,
                child: Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(Color(0xFF3A79FF)),
                    ),
                  ),
                ),
              ),
              error: (error, _) => Text(
                'Error: $error',
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.red,
                ),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                // Request confirmation
                final bool? resetConfirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    backgroundColor: const Color(0xFF1A1A1A),
                    title: const Text(
                      'Reset Portfolio',
                      style: TextStyle(color: Colors.white),
                    ),
                    content: const Text(
                      'Are you sure you want to reset the portfolio and restore the initial balance? All positions will be closed.',
                      style: TextStyle(color: Colors.white70),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancel',
                            style: TextStyle(color: Colors.white70)),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Reset',
                            style: TextStyle(color: Color(0xFF3A79FF))),
                      ),
                    ],
                  ),
                );

                if (resetConfirm == true) {
                  setState(() {
                    _isLoading = true;
                  });

                  try {
                    final success = await ref
                        .read(balanceProvider.notifier)
                        .resetPortfolio();

                    if (success) {
                      await _refreshData();
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Portfolio reset successfully'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      }
                    } else {
                      setState(() {
                        _isLoading = false;
                      });
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Error resetting portfolio'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  } catch (e) {
                    setState(() {
                      _isLoading = false;
                    });
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error: $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade800,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 45),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Reset Portfolio'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPositionsCount(
      AsyncValue<List<Map<String, dynamic>>> positionsState) {
    return positionsState.when(
      data: (positions) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.white.withOpacity(0.1),
            width: 1,
          ),
        ),
        child: Text(
          '${positions.length} ${_getPositionCountText(positions.length)}',
          style: const TextStyle(
            fontSize: 14,
            color: Colors.white70,
          ),
        ),
      ),
      loading: () => const SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF3A79FF)),
        ),
      ),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  String _getPositionCountText(int count) {
    if (count == 1) {
      return 'position';
    } else {
      return 'positions';
    }
  }

  Widget _buildPositionsList(
      AsyncValue<List<Map<String, dynamic>>> positionsState) {
    return positionsState.when(
      data: (positions) {
        if (positions.isEmpty) {
          return SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 40),
                  Icon(
                    Icons.account_balance_wallet_outlined,
                    size: 70,
                    color: Colors.grey.withOpacity(0.3),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No active positions',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white.withOpacity(0.7),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Go to the "Signals" section to open a position',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withOpacity(0.5),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }

        return SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) => RepaintBoundary(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _buildPositionCard(positions[index]),
                ),
              ),
              childCount: positions.length,
            ),
          ),
        );
      },
      loading: () => const SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF3A79FF)),
          ),
        ),
      ),
      error: (error, _) => SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 50, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                'Error loading positions: $error',
                style: const TextStyle(color: Colors.red),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _refreshData,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPositionCard(Map<String, dynamic> position) {
    final ticker = position['ticker'] as String;
    final signalType = position['signal_type'] as String;
    final price = position['price'] as double;
    final quantity = position['quantity'] as double;
    final pnl = position['pnl'] as double? ?? 0.0;
    final pnlPercent = position['pnl_percent'] as double? ?? 0.0;
    final isProfit = pnl > 0;
    final currentPrice = position['current_price'] as double? ?? price;

    final positionColor = signalType.toLowerCase() == 'long'
        ? Colors.green.shade700
        : Colors.red.shade700;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF141414),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withOpacity(0.05),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with ticker and position type
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(
                      ticker,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: positionColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        signalType.toUpperCase(),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: positionColor,
                        ),
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color:
                        (isProfit ? Colors.green : Colors.red).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${isProfit ? '+' : ''}${pnl.toStringAsFixed(2)} \$ (${pnlPercent.toStringAsFixed(2)}%)',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: isProfit ? Colors.green : Colors.red,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Position information
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Position details
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildDetailItem(
                        'Quantity', '${quantity.toStringAsFixed(2)}'),
                    _buildDetailItem(
                        'Entry Price', '\$${price.toStringAsFixed(2)}'),
                    _buildDetailItem('Current Price',
                        '\$${currentPrice.toStringAsFixed(2)}'),
                  ],
                ),

                const SizedBox(height: 16),
                const Divider(color: Color(0xFF2A2A2A), height: 1),
                const SizedBox(height: 16),

                // Close position button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => _closePosition(ticker, currentPrice),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF212121),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('Close Position'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.white.withOpacity(0.5),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Colors.white,
          ),
        ),
      ],
    );
  }
}

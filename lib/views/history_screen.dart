import 'package:flutter/material.dart';
import '../database/signal_database.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<Map<String, dynamic>> history = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    loadHistory();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    loadHistory();
  }

  Future<void> loadHistory() async {
    try {
      setState(() {
        _isLoading = true;
      });

      // Give widgets time to render
      await Future.delayed(const Duration(milliseconds: 100));

      final data = await SignalDatabase.getAllSignals();

      // Check if widget was unmounted
      if (!mounted) return;

      setState(() {
        history = data;
        _isLoading = false;
      });
    } catch (e) {
      // Check if widget was unmounted
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        history = [];
      });

      // Show error only if widget is still in tree
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading history: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> clearHistory() async {
    // Delete all signals from the database
    final db = await SignalDatabase.database;
    await db.delete('signals');

    setState(() {
      history = [];
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '📜 Signal History',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete),
            tooltip: 'Clear History',
            onPressed: () {
              showDialog(
                context: context,
                builder: (BuildContext context) {
                  return AlertDialog(
                    title: const Text('Clear History?'),
                    content: const Text(
                        'All signal history records will be deleted'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFF5252), Color(0xFFE53935)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: ElevatedButton(
                          onPressed: () {
                            clearHistory();
                            Navigator.of(context).pop();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('History cleared')),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 12),
                          ),
                          child: const Text(
                            'Clear',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          )
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              colorScheme.surface,
              colorScheme.surface.withAlpha(230),
            ],
          ),
        ),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : history.isEmpty
                ? _buildEmptyState()
                : _buildHistoryList(colorScheme),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.history,
                  size: 80,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 32),
              const Text(
                'Signal history is empty',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: const Text(
                  'All received signals will be displayed here',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                    height: 1.4,
                  ),
                ),
              ),
              const SizedBox(height: 40),
              Container(
                width: 220,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(30),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1A237E), Color(0xFF3949AB)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blue.withOpacity(0.3),
                      spreadRadius: 1,
                      blurRadius: 15,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ElevatedButton.icon(
                  onPressed: loadHistory,
                  icon: const Icon(Icons.refresh, size: 22),
                  label: const Text(
                    'Refresh',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 30, vertical: 16),
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
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

  Widget _buildHistoryList(ColorScheme colorScheme) {
    return RepaintBoundary(
      child: ListView.builder(
        itemCount: history.length,
        padding: const EdgeInsets.all(16),
        itemBuilder: (context, index) {
          final signal = history[index];

          // Define color based on signal type
          final Color signalColor =
              signal['signal_type'].toLowerCase() == 'long'
                  ? Colors.greenAccent.shade700
                  : signal['signal_type'].toLowerCase() == 'short'
                      ? Colors.redAccent.shade700
                      : colorScheme.primary;

          return RepaintBoundary(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Card(
                elevation: 3,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: signalColor.withAlpha(76), // 0.3 * 255 = ~76
                      width: 1.5,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Ticker and signal type
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: signalColor.withAlpha(25),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: signalColor.withAlpha(50),
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                signal['ticker'],
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: signalColor,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: signalColor.withAlpha(25),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: signalColor.withAlpha(50),
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                signal['signal_type'].toUpperCase(),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: signalColor,
                                ),
                              ),
                            ),
                          ],
                        ),

                        // Change percent
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: (signal['change_percent'] >= 0
                                      ? Colors.green
                                      : Colors.red)
                                  .withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: (signal['change_percent'] >= 0
                                        ? Colors.green
                                        : Colors.red)
                                    .withOpacity(0.3),
                                width: 1,
                              ),
                            ),
                            child: Text(
                              'Δ: ${signal['change_percent'].toStringAsFixed(2)}%',
                              style: TextStyle(
                                color: signal['change_percent'] >= 0
                                    ? Colors.green
                                    : Colors.red,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),

                        // Signal message
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Text(
                            signal['message'],
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 15,
                              height: 1.4,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),

                        // Signal details
                        Container(
                          margin: const EdgeInsets.only(top: 12),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceVariant.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _signalInfoItem(
                                  'Open', signal['open_price'].toString()),
                              _buildVerticalDivider(),
                              _signalInfoItem(
                                  'Close', signal['close_price'].toString()),
                              _buildVerticalDivider(),
                              _signalInfoItem('EPS Growth',
                                  '${signal['eps_growth'].toStringAsFixed(2)}%'),
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

  Widget _buildVerticalDivider() {
    return Container(
      height: 40,
      width: 1,
      color: Colors.grey.withOpacity(0.2),
    );
  }

  Widget _signalInfoItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 4),
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
}

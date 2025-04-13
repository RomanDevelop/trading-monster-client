import 'package:flutter/material.dart';
import '../database/signal_database.dart';
import '../models/signal_model.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<SignalModel> history = [];
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

      // Даем виджетам время для отрисовки
      await Future.delayed(const Duration(milliseconds: 100));

      final data = await SignalDatabase.getAllSignals();

      // Проверка, не был ли виджет демонтирован
      if (!mounted) return;

      setState(() {
        history = data;
        _isLoading = false;
      });
    } catch (e) {
      // Проверка, не был ли виджет демонтирован
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        history = [];
      });

      // Показываем ошибку только если виджет все еще в дереве
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ошибка загрузки истории: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> clearHistory() async {
    await SignalDatabase.clear();
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
          '📜 История сигналов',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete),
            tooltip: 'Очистить историю',
            onPressed: () {
              showDialog(
                context: context,
                builder: (BuildContext context) {
                  return AlertDialog(
                    title: const Text('Очистить историю?'),
                    content:
                        const Text('Все записи истории сигналов будут удалены'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Отмена'),
                      ),
                      TextButton(
                        onPressed: () {
                          clearHistory();
                          Navigator.of(context).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('История очищена')),
                          );
                        },
                        child: const Text('Очистить'),
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
              colorScheme.surface.withOpacity(0.9),
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
    return Container(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Вместо изображения всегда используем иконку
            const Icon(Icons.history, size: 80, color: Colors.grey),
            const SizedBox(height: 24),
            const Text(
              'История сигналов пуста',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Здесь будут отображаться все полученные сигналы',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: loadHistory, // Напрямую обновляем историю
              icon: const Icon(Icons.refresh),
              label: const Text('Обновить'),
            ),
          ],
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
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
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
                                const SizedBox(width: 12),
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
                              ],
                            ),
                            Text(
                              'Δ: ${signal.changePercent.toStringAsFixed(2)}%',
                              style: TextStyle(
                                color: signal.changePercent >= 0
                                    ? Colors.green
                                    : Colors.red,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          signal.message,
                          style: TextStyle(
                            fontSize: 14,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _signalInfoItem('Open', signal.open.toString()),
                            _signalInfoItem('Close', signal.close.toString()),
                            _signalInfoItem('EPS Growth',
                                '${signal.epsGrowth.toStringAsFixed(2)}%'),
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

  Widget _signalInfoItem(String label, String value) {
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
}

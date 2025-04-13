import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../viewmodels/signal_view_model.dart';

class WatchlistScreen extends ConsumerStatefulWidget {
  const WatchlistScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<WatchlistScreen> createState() => _WatchlistScreenState();
}

class _WatchlistScreenState extends ConsumerState<WatchlistScreen> {
  final TextEditingController _tickerController = TextEditingController();

  @override
  void dispose() {
    _tickerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final watchlistState = ref.watch(watchlistProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '📊 Мониторинг тикеров',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Обновить список',
            onPressed: () {
              ref.read(watchlistProvider.notifier).fetchWatchlist();
            },
          ),
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
        child: Column(
          children: [
            // Форма добавления тикера
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Пояснение о работе с тикерами
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: colorScheme.primary.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.info_outline,
                                color: colorScheme.primary, size: 18),
                            const SizedBox(width: 8),
                            Text(
                              'Важно:',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Система отслеживает и присылает сигналы только по тикерам, которые вы явно добавите в этот список.',
                          style: TextStyle(fontSize: 13),
                        ),
                      ],
                    ),
                  ),

                  // Поле добавления тикера
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _tickerController,
                          textCapitalization: TextCapitalization.characters,
                          decoration: InputDecoration(
                            labelText: 'Введите тикер акции',
                            hintText: 'Например: AAPL, MSFT, GOOGL',
                            prefixIcon:
                                Icon(Icons.search, color: colorScheme.primary),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: () {
                          final ticker =
                              _tickerController.text.trim().toUpperCase();
                          if (ticker.isNotEmpty) {
                            ref
                                .read(watchlistProvider.notifier)
                                .addTicker(ticker);
                            _tickerController.clear();

                            // Показываем уведомление об успешном добавлении
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                    'Тикер $ticker добавлен для мониторинга'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: colorScheme.primary,
                          foregroundColor: colorScheme.onPrimary,
                          minimumSize: const Size(110, 56),
                        ),
                        child: const Text('Добавить'),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Список тикеров
            Expanded(
              child: watchlistState.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(
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
                          ref.read(watchlistProvider.notifier).fetchWatchlist();
                        },
                        child: const Text('Повторить'),
                      ),
                    ],
                  ),
                ),
                data: (tickers) => tickers.isEmpty
                    ? _buildEmptyState()
                    : _buildTickersList(tickers, colorScheme),
              ),
            ),
          ],
        ),
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
            const Icon(Icons.radar, size: 80, color: Colors.grey),
            const SizedBox(height: 24),
            const Text(
              'Список мониторинга пуст',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Добавьте тикер выше, чтобы начать его отслеживание на сервере',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 24),
            const Text(
              'После добавления тикеров, система будет автоматически анализировать их и отправлять торговые сигналы на основной экран',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTickersList(List<String> tickers, ColorScheme colorScheme) {
    return ListView.builder(
      itemCount: tickers.length,
      padding: const EdgeInsets.all(16),
      itemBuilder: (context, index) {
        final ticker = tickers[index];

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.all(16),
              title: Text(
                ticker,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              subtitle: const Text(
                'В процессе мониторинга',
                style: TextStyle(fontSize: 14),
              ),
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.trending_up,
                  color: colorScheme.primary,
                  size: 28,
                ),
              ),
              trailing: IconButton(
                icon: const Icon(Icons.remove_circle_outline),
                color: Colors.redAccent,
                tooltip: 'Удалить из мониторинга',
                onPressed: () {
                  _showDeleteConfirmDialog(ticker);
                },
              ),
            ),
          ),
        );
      },
    );
  }

  void _showDeleteConfirmDialog(String ticker) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Удалить $ticker?'),
          content: Text(
            'Тикер $ticker будет удален из мониторинга. Это действие нельзя отменить.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Отмена'),
            ),
            TextButton(
              onPressed: () {
                ref.read(watchlistProvider.notifier).removeTicker(ticker);
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('$ticker удален из мониторинга'),
                  ),
                );
              },
              child: const Text('Удалить'),
            ),
          ],
        );
      },
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../viewmodels/signal_view_model.dart';
import '../models/signal_model.dart';
import 'add_ticker_screen.dart';

class WatchlistScreen extends ConsumerStatefulWidget {
  const WatchlistScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<WatchlistScreen> createState() => _WatchlistScreenState();
}

class _WatchlistScreenState extends ConsumerState<WatchlistScreen> {
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final watchlistState = ref.watch(watchlistProvider);
    final watchlistDetailsState = ref.watch(watchlistDetailsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '📊 Ticker Monitoring',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh List',
            onPressed: () {
              ref.read(watchlistProvider.notifier).fetchWatchlist();
              ref
                  .read(watchlistDetailsProvider.notifier)
                  .fetchWatchlistDetails();
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
                        color: colorScheme.primary.withOpacity(0.5),
                        width: 1.5,
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
                              'Important:',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'The system tracks and sends signals only for tickers that you explicitly add to this list. Due to Alpha Vantage API limitations, data updates every 5 minutes and the recommended maximum is 20 tickers.',
                          style: TextStyle(fontSize: 13),
                        ),
                      ],
                    ),
                  ),

                  // Кнопка добавления тикера (без текстового поля)
                  ElevatedButton.icon(
                    onPressed: () {
                      // Проверка максимального количества тикеров (20)
                      final currentTickers = ref.read(watchlistProvider);
                      if (currentTickers is AsyncData &&
                          (currentTickers.value?.length ?? 0) >= 20) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                                'Ticker limit reached (20). Please remove unused tickers.'),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }

                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const AddTickerScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('Add New Ticker'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colorScheme.primary,
                      foregroundColor: colorScheme.onPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: colorScheme.primary.withOpacity(0.7),
                          width: 1.5,
                        ),
                      ),
                      elevation: 3,
                    ),
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
                        'Error: $e',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 16),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          ref.read(watchlistProvider.notifier).fetchWatchlist();
                          ref
                              .read(watchlistDetailsProvider.notifier)
                              .fetchWatchlistDetails();
                        },
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
                data: (tickers) => tickers.isEmpty
                    ? _buildEmptyState()
                    : _buildTickersList(
                        tickers, colorScheme, watchlistDetailsState),
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
              'Watchlist is empty',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Add a ticker above to start tracking it on the server',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 24),
            const Text(
              'After adding tickers, the system will automatically analyze them and send trading signals to the main screen',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTickersList(List<String> tickers, ColorScheme colorScheme,
      AsyncValue<List<WatchlistItem>> watchlistDetailsState) {
    return ListView.builder(
      itemCount: tickers.length,
      padding: const EdgeInsets.all(16),
      itemBuilder: (context, index) {
        final ticker = tickers[index];

        // Получаем тип модели для текущего тикера
        String modelType = 'RSI_MODEL';
        AnalysisModelType analysisModelType = AnalysisModelType.rsiModel;

        if (watchlistDetailsState is AsyncData) {
          final details = watchlistDetailsState.valueOrNull;
          if (details != null) {
            final item = details.firstWhere(
              (item) => item.ticker == ticker,
              orElse: () =>
                  WatchlistItem(ticker: ticker, modelType: 'RSI_MODEL'),
            );
            modelType = item.modelType;
            analysisModelType = getModelTypeFromString(modelType);
          }
        } else {
          // Временное решение для демонстрации, пока серверный API не реализован
          // В реальном приложении эти данные должны приходить с сервера
          // Назначаем модель в зависимости от индекса, чтобы были разные модели
          final modelTypes = [
            AnalysisModelType.rsiModel,
            AnalysisModelType.macdModel,
            AnalysisModelType.bollingerModel
          ];
          analysisModelType = modelTypes[index % modelTypes.length];
        }

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: colorScheme.primary.withOpacity(0.3),
                width: 1.5,
              ),
            ),
            child: Column(
              children: [
                ListTile(
                  contentPadding: const EdgeInsets.all(16),
                  title: Text(
                    ticker,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: Row(
                    children: [
                      const Text(
                        'Currently monitoring',
                        style: TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: colorScheme.primary.withOpacity(0.5),
                        width: 1.5,
                      ),
                    ),
                    child: Icon(
                      analysisModelType.icon,
                      color: colorScheme.primary,
                      size: 28,
                    ),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.remove_circle_outline),
                    color: Colors.redAccent,
                    tooltip: 'Remove from monitoring',
                    onPressed: () {
                      _showDeleteConfirmDialog(ticker);
                    },
                  ),
                ),

                // Модель анализа
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  margin: const EdgeInsets.only(bottom: 8, left: 16, right: 16),
                  alignment: Alignment.centerLeft,
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.blue.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(analysisModelType.icon,
                          size: 16, color: Colors.blue),
                      const SizedBox(width: 8),
                      Text(
                        analysisModelType.displayName,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.blue,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
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
          title: Text('Remove $ticker?'),
          content: Text(
            'Ticker $ticker will be removed from monitoring. This action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                ref.read(watchlistProvider.notifier).removeTicker(ticker);
                ref
                    .read(watchlistDetailsProvider.notifier)
                    .removeTicker(ticker);
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('$ticker removed from monitoring'),
                  ),
                );
              },
              child: const Text('Remove'),
            ),
          ],
        );
      },
    );
  }
}

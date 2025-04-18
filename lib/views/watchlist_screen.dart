import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../viewmodels/signal_view_model.dart';
import '../models/signal_model.dart';
import 'add_ticker_screen.dart';

class WatchlistScreen extends ConsumerStatefulWidget {
  const WatchlistScreen({super.key});

  @override
  ConsumerState<WatchlistScreen> createState() => _WatchlistScreenState();
}

class _WatchlistScreenState extends ConsumerState<WatchlistScreen> {
  // Метод для обновления деталей watchlist
  void _refreshWatchlistDetails() {
    ref.read(watchlistDetailsProvider.notifier).fetchWatchlistDetails();
  }

  // Метод для открытия экрана добавления тикера
  Future<void> _addTicker() async {
    // Debug output for the watchlist before adding
    print(
        '📋 Watchlist до добавления тикера: ${ref.read(watchlistProvider).value?.length ?? 0} тикеров');

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AddTickerScreen(),
      ),
    );

    if (result == true) {
      print('✅ Tикер успешно добавлен, обновляем watchlistDetails');
      // Обновляем детали watchlist после добавления нового тикера
      _refreshWatchlistDetails();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final watchlistState = ref.watch(watchlistProvider);
    final watchlistDetailsState = ref.watch(watchlistDetailsProvider);
    // Добавляем слежение за состоянием близости сигналов
    final signalProximityState = ref.watch(signalProximityProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Ticker Monitoring',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh List',
            onPressed: () {
              ref.read(watchlistProvider.notifier).fetchWatchlist();
              _refreshWatchlistDetails();
              // Добавляем обновление данных о близости сигналов
              ref.read(signalProximityProvider.notifier).fetchSignalProximity();
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
                          'With the standard subscription, data updates every 5 minutes and the recommended maximum is 20 tickers.',
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

                      _addTicker();
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
    // Логирование состояния деталей watchlist
    print(
        '📌 Состояние watchlistDetailsState: ${watchlistDetailsState.runtimeType}');
    if (watchlistDetailsState is AsyncData) {
      final data = watchlistDetailsState.value;
      if (data != null) {
        print('📌 watchlistDetailsState содержит ${data.length} элементов:');
        for (var item in data) {
          print('  - ${item.ticker}: ${item.modelType}');
        }
      } else {
        print('📌 watchlistDetailsState.value равен null');
      }
    } else if (watchlistDetailsState is AsyncError) {
      print(
          '📌 watchlistDetailsState содержит ошибку: ${watchlistDetailsState.error}');
    } else {
      print('📌 watchlistDetailsState в состоянии загрузки');
    }

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
            print(
                '🔎 Отображение тикера $ticker с моделью из сервера: $modelType');
            analysisModelType = getModelTypeFromString(modelType);
            print(
                '🔎 Преобразовано в Dart-объект: ${analysisModelType.displayName}');
          }
        } else {
          // Временное решение для демонстрации, пока серверный API не реализован
          // В реальном приложении эти данные должны приходить с сервера
          // Назначаем модель в зависимости от индекса, чтобы были разные модели
          final modelTypes = [
            AnalysisModelType.rsiModel,
            //       AnalysisModelType.macdModel,
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

                // Индикатор близости сигнала
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  margin:
                      const EdgeInsets.only(bottom: 16, left: 16, right: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.grey.withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Signal Proximity:',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          _buildProximityPercentage(ticker),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _buildProximityIndicator(ticker),
                      const SizedBox(height: 8),
                      _buildProximityDescription(ticker, analysisModelType),
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

  // Добавим методы для создания индикатора близости сигнала
  Widget _buildProximityPercentage(String ticker) {
    // Получаем значение близости сигнала из провайдера
    final proximityValue = ref
        .read(signalProximityProvider.notifier)
        .getProximityValueForTicker(ticker);

    Color textColor = Colors.grey;
    if (proximityValue > 75) {
      textColor = Colors.red;
    } else if (proximityValue > 50) {
      textColor = Colors.orange;
    } else if (proximityValue > 25) {
      textColor = Colors.blue;
    }

    return Text(
      '$proximityValue%',
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.bold,
        color: textColor,
      ),
    );
  }

  Widget _buildProximityIndicator(String ticker) {
    // Получаем значение близости сигнала из провайдера
    final proximityValue = ref
        .read(signalProximityProvider.notifier)
        .getProximityValueForTicker(ticker);

    Color progressColor = Colors.grey;
    if (proximityValue > 75) {
      progressColor = Colors.red;
    } else if (proximityValue > 50) {
      progressColor = Colors.orange;
    } else if (proximityValue > 25) {
      progressColor = Colors.blue;
    }

    return LinearProgressIndicator(
      value: proximityValue / 100,
      backgroundColor: Colors.grey.withOpacity(0.2),
      valueColor: AlwaysStoppedAnimation<Color>(progressColor),
      minHeight: 8,
      borderRadius: BorderRadius.circular(4),
    );
  }

  Widget _buildProximityDescription(
      String ticker, AnalysisModelType modelType) {
    // Получаем описание близости сигнала из провайдера
    final description = ref
        .read(signalProximityProvider.notifier)
        .getProximityDescriptionForTicker(ticker);

    return Text(
      description,
      style: const TextStyle(
        fontSize: 12,
        fontStyle: FontStyle.italic,
        color: Colors.grey,
      ),
    );
  }
}

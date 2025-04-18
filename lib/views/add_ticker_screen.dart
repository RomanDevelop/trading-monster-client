import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../viewmodels/signal_view_model.dart';
import '../models/signal_model.dart';

class AddTickerScreen extends ConsumerStatefulWidget {
  const AddTickerScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<AddTickerScreen> createState() => _AddTickerScreenState();
}

class _AddTickerScreenState extends ConsumerState<AddTickerScreen> {
  final TextEditingController _controller = TextEditingController();
  AnalysisModelType _selectedModelType = AnalysisModelType.bollingerModel;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    print(
        '🚀 Инициализация экрана добавления тикера с моделью по умолчанию: ${_selectedModelType.displayName} (${_selectedModelType.value})');
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // Метод для прокрутки к описанию модели
  void _scrollToModelDescription() {
    // Добавляем небольшую задержку для обновления интерфейса
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent - 200,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Add Ticker',
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
        child: SingleChildScrollView(
          controller: _scrollController,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // User instructions
                Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.info_outline,
                                color: colorScheme.primary),
                            const SizedBox(width: 8),
                            Text(
                              'How to add a ticker',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          '1. Enter the ticker symbol (e.g., AAPL for Apple)',
                          style: TextStyle(fontSize: 14),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          '2. Select an analysis model',
                          style: TextStyle(fontSize: 14),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          '3. Click "Add" to start tracking',
                          style: TextStyle(fontSize: 14),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '4. The bot will start analyzing the stock and suggesting signals',
                          style: TextStyle(fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                ),

                // Ticker input field
                _buildSearchBar(colorScheme),

                // Model selection
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Select Analysis Model:',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildModelSelection(colorScheme),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Popular tickers examples
                Text(
                  'Popular tickers:',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildTickerChip('AAPL', colorScheme),
                    _buildTickerChip('MSFT', colorScheme),
                    _buildTickerChip('GOOGL', colorScheme),
                    _buildTickerChip('AMZN', colorScheme),
                    _buildTickerChip('TSLA', colorScheme),
                    _buildTickerChip('META', colorScheme),
                    _buildTickerChip('NVDA', colorScheme),
                    _buildTickerChip('JPM', colorScheme),
                  ],
                ),

                // Model explanation
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(_selectedModelType.icon,
                                color: colorScheme.primary),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'About ${_selectedModelType.displayName}',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: colorScheme.primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _selectedModelType.description,
                          style: const TextStyle(fontSize: 14),
                        ),
                        if (_selectedModelType ==
                            AnalysisModelType.bollingerModel) ...[
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            onPressed: () => _showBollingerBandsInfo(context),
                            icon: const Icon(Icons.info_outline),
                            label:
                                const Text('Learn more about Bollinger Bands'),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                // Дополнительное пространство внизу для лучшей прокрутки
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModelSelection(ColorScheme colorScheme) {
    return Column(
      children: [
        for (final modelType in AnalysisModelType.values)
          RadioListTile<AnalysisModelType>(
            title: Row(
              children: [
                Icon(modelType.icon, size: 20, color: colorScheme.primary),
                const SizedBox(width: 8),
                Text(modelType.displayName),
              ],
            ),
            value: modelType,
            groupValue: _selectedModelType,
            onChanged: (value) {
              if (value != null) {
                print(
                    '🔍 Пользователь выбрал модель: ${value.displayName} (${value.value})');
                setState(() {
                  _selectedModelType = value;
                });
                _scrollToModelDescription();
              }
            },
            activeColor: colorScheme.primary,
            dense: true,
          ),
      ],
    );
  }

  Widget _buildSearchBar(ColorScheme colorScheme) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                labelText: 'Enter ticker',
                hintText: 'Example: AAPL, MSFT, GOOGL',
                prefixIcon: Icon(Icons.search, color: colorScheme.primary),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton(
            onPressed: () {
              final ticker = _controller.text.trim().toUpperCase();
              if (ticker.isNotEmpty) {
                print(
                    '✅ Добавление тикера: $ticker с моделью: ${_selectedModelType.displayName} (${_selectedModelType.value})');
                ref.read(signalViewModelProvider.notifier).addTicker(
                      ticker,
                      modelType: _selectedModelType,
                    );
                _controller.clear();

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                        'Ticker $ticker added for monitoring with ${_selectedModelType.displayName}'),
                    backgroundColor: Colors.green,
                  ),
                );

                // Возвращаемся на предыдущий экран
                Navigator.of(context).pop();
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: colorScheme.primary,
              foregroundColor: colorScheme.onPrimary,
              minimumSize: const Size(110, 56),
            ),
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  Widget _buildTickerChip(String ticker, ColorScheme colorScheme) {
    return ActionChip(
      avatar: const Icon(Icons.add, size: 16),
      label: Text(ticker),
      onPressed: () {
        ref.read(signalViewModelProvider.notifier).addTicker(
              ticker,
              modelType: _selectedModelType,
            );
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Ticker $ticker added for monitoring with ${_selectedModelType.displayName}'),
            backgroundColor: Colors.green,
          ),
        );

        // Возвращаемся на предыдущий экран
        Navigator.of(context).pop();
      },
    );
  }

  void _showBollingerBandsInfo(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(AnalysisModelType.bollingerModel.icon,
                color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 8),
            const Text('Bollinger Bands Guide'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Bollinger Bands is a technical volatility indicator created by John Bollinger.',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              const Text(
                'How it works:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              const Text(
                  '• Middle band - moving average (typically 20 periods)'),
              const Text(
                  '• Upper and lower bands - standard deviation from the average'),
              const Text('• Bands narrowing indicates low volatility'),
              const Text('• Bands widening indicates high volatility'),
              const SizedBox(height: 12),
              const Text(
                'Trading signals:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              const Text(
                  '• Price crossing the upper band - opportunity for short position'),
              const Text(
                  '• Price crossing the lower band - opportunity for long position'),
              const Text('• Price bouncing off bands - trend reversal signal'),
              const SizedBox(height: 12),
              const Text(
                'Bollinger Bands are especially effective:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              const Text('• In volatile markets with sharp movements'),
              const Text('• When breaking out from low volatility periods'),
              const Text(
                  '• In combination with other indicators for confirmation'),
              const SizedBox(height: 12),
              const Text(
                'Bollinger Bands chart shows:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              const Text('• Middle line (SMA)'),
              const Text('• Upper band (SMA + 2SD)'),
              const Text('• Lower band (SMA - 2SD)'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }
}

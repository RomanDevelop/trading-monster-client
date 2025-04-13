import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../viewmodels/signal_view_model.dart';

class AddTickerScreen extends ConsumerStatefulWidget {
  const AddTickerScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<AddTickerScreen> createState() => _AddTickerScreenState();
}

class _AddTickerScreenState extends ConsumerState<AddTickerScreen> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
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
                          Icon(Icons.info_outline, color: colorScheme.primary),
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
                        '2. Click "Add" to start tracking',
                        style: TextStyle(fontSize: 14),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '3. The bot will start analyzing the stock and suggesting signals',
                        style: TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ),

              // Ticker input field
              _buildSearchBar(colorScheme),

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
            ],
          ),
        ),
      ),
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
                ref.read(signalViewModelProvider.notifier).addTicker(ticker);
                _controller.clear();

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Ticker $ticker added for monitoring'),
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
        ref.read(signalViewModelProvider.notifier).addTicker(ticker);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ticker $ticker added for monitoring'),
            backgroundColor: Colors.green,
          ),
        );
      },
    );
  }
}

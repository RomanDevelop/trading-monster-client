class SignalModel {
  final String id; // Уникальный ID сигнала
  final String ticker;
  final String signal; // long или short
  final String message;
  final double open;
  final double close;
  final double changePercent;
  final double epsGrowth;
  final String timestamp; // Время получения сигнала
  final String status; // pending, confirmed, rejected
  final double? quantity; // Количество для подтвержденных сигналов

  SignalModel({
    required this.id,
    required this.ticker,
    required this.signal,
    required this.message,
    required this.open,
    required this.close,
    required this.changePercent,
    required this.epsGrowth,
    required this.timestamp,
    required this.status,
    this.quantity,
  });

  factory SignalModel.fromJson(Map<String, dynamic> json) {
    return SignalModel(
      id: json['id'].toString(),
      ticker: json['ticker'],
      signal: json['signal'],
      message: json['message'],
      open: json['open'].toDouble(),
      close: json['close'].toDouble(),
      changePercent: json['change_percent'].toDouble(),
      epsGrowth: json['eps_growth'].toDouble(),
      timestamp: json['timestamp'] ?? DateTime.now().toIso8601String(),
      status: json['status'] ?? 'pending',
      quantity: json['quantity'] != null ? json['quantity'].toDouble() : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'ticker': ticker,
      'signal': signal,
      'message': message,
      'open': open,
      'close': close,
      'change_percent': changePercent,
      'eps_growth': epsGrowth,
      'timestamp': timestamp,
      'status': status,
      'quantity': quantity,
    };
  }
}

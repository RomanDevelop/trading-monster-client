class SignalModel {
  final String id; // Unique ID of the signal
  final String ticker;
  final String signal; // long or short
  final String message;
  final double open;
  final double close;
  final double changePercent;
  final double epsGrowth;
  final String timestamp; // Time of receiving the signal
  final String status; // pending, confirmed, rejected
  final double? quantity; // Quantity for confirmed signals

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

  // Create model from JSON
  factory SignalModel.fromJson(Map<String, dynamic> json) {
    return SignalModel(
      id: json['id'] as String,
      ticker: json['ticker'] as String,
      signal: json['signal'] as String,
      message: json['message'] as String,
      open: (json['open'] as num).toDouble(),
      close: (json['close'] as num).toDouble(),
      changePercent: (json['change_percent'] as num).toDouble(),
      epsGrowth: (json['eps_growth'] as num).toDouble(),
      timestamp: json['timestamp'] as String,
      status: json['status'] as String,
      quantity: json['quantity'] != null ? json['quantity'].toDouble() : null,
    );
  }

  // Convert model to JSON
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

  // Create a copy of the model with updated fields
  SignalModel copyWith({
    String? id,
    String? ticker,
    String? signal,
    String? message,
    double? open,
    double? close,
    double? changePercent,
    double? epsGrowth,
    String? timestamp,
    String? status,
    double? quantity,
  }) {
    return SignalModel(
      id: id ?? this.id,
      ticker: ticker ?? this.ticker,
      signal: signal ?? this.signal,
      message: message ?? this.message,
      open: open ?? this.open,
      close: close ?? this.close,
      changePercent: changePercent ?? this.changePercent,
      epsGrowth: epsGrowth ?? this.epsGrowth,
      timestamp: timestamp ?? this.timestamp,
      status: status ?? this.status,
      quantity: quantity ?? this.quantity,
    );
  }
}

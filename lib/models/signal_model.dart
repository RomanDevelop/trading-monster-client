import 'package:flutter/material.dart';

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
  final String? modelType; // Type of analysis model that generated the signal

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
    this.modelType,
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
      modelType: json['model_type'] as String?,
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
      'model_type': modelType,
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
    String? modelType,
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
      modelType: modelType ?? this.modelType,
    );
  }
}

// Перечисление типов моделей анализа
enum AnalysisModelType {
  rsiModel,
  macdModel,
  bollingerModel,
  avModel, // Alpha Vantage model
}

// Расширение для получения строкового представления типа модели
extension AnalysisModelTypeExtension on AnalysisModelType {
  String get value {
    switch (this) {
      case AnalysisModelType.rsiModel:
        return 'RSI_MODEL';
      case AnalysisModelType.macdModel:
        return 'MACD_MODEL';
      case AnalysisModelType.bollingerModel:
        return 'BOLLINGER_MODEL';
      case AnalysisModelType.avModel:
        return 'AV_MODEL';
    }
  }

  String get displayName {
    switch (this) {
      case AnalysisModelType.rsiModel:
        return 'RSI Model';
      case AnalysisModelType.macdModel:
        return 'MACD Model';
      case AnalysisModelType.bollingerModel:
        return 'Bollinger Bands Model';
      case AnalysisModelType.avModel:
        return 'Alpha Vantage Model';
    }
  }

  String get description {
    switch (this) {
      case AnalysisModelType.rsiModel:
        return 'Relative Strength Index анализирует импульс и скорость изменения цены';
      case AnalysisModelType.macdModel:
        return 'Moving Average Convergence Divergence использует скользящие средние для определения тренда';
      case AnalysisModelType.bollingerModel:
        return 'Bollinger Bands анализирует волатильность и отскоки от границ ценового диапазона';
      case AnalysisModelType.avModel:
        return 'Alpha Vantage анализирует данные котировок акций с использованием API Alpha Vantage';
    }
  }

  IconData get icon {
    switch (this) {
      case AnalysisModelType.rsiModel:
        return Icons.show_chart;
      case AnalysisModelType.macdModel:
        return Icons.trending_up;
      case AnalysisModelType.bollingerModel:
        return Icons.architecture;
      case AnalysisModelType.avModel:
        return Icons.analytics;
    }
  }
}

// Получение типа модели из строки
AnalysisModelType getModelTypeFromString(String? modelType) {
  if (modelType == null) return AnalysisModelType.rsiModel;

  switch (modelType) {
    case 'RSI_MODEL':
      return AnalysisModelType.rsiModel;
    case 'MACD_MODEL':
      return AnalysisModelType.macdModel;
    case 'BOLLINGER_MODEL':
      return AnalysisModelType.bollingerModel;
    case 'AV_MODEL':
      return AnalysisModelType.avModel;
    default:
      return AnalysisModelType.rsiModel;
  }
}

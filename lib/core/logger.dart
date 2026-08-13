import 'package:logger/logger.dart';
import 'package:flutter/foundation.dart';

/// Global logger instance for the application
/// Uses different log levels based on build mode:
/// - Debug: All logs (verbose, debug, info, warning, error)
/// - Release: Only warnings and errors
final appLogger = Logger(
  filter: ProductionFilter(),
  printer: PrettyPrinter(
    methodCount: kDebugMode ? 2 : 0,
    errorMethodCount: 5,
    lineLength: 80,
    colors: true,
    printEmojis: true,
    dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
  ),
  level: kDebugMode ? Level.debug : Level.warning,
);

/// Custom filter for production builds
class ProductionFilter extends LogFilter {
  @override
  bool shouldLog(LogEvent event) {
    if (kReleaseMode) {
      return event.level.index >= Level.warning.index;
    }
    return true;
  }
}

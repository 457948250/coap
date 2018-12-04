/*
 * Package : Coap
 * Author : S. Hamblett <steve.hamblett@linux.com>
 * Date   : 12/04/2017
 * Copyright :  S.Hamblett
 */

part of coap;

/// Provides logging to the console
class CoapConsoleLogger implements CoapILogger {
  /// Construction
  CoapConsoleLogger() {
    logging.Logger.root.level = logging.Level.ALL;
  }

  static final logging.Logger _logger = logging.Logger('ConsoleLogger');

  @override
  logging.Logger get root => logging.Logger.root;

  @override
  set root(logging.Logger root) {}

  /// Last message
  String _lastMessage;

  @override
  String get lastMessage => _lastMessage;

  @override
  set lastMessage(String message) {}

  @override
  bool isDebugEnabled() => _logger.level == logging.Level.SEVERE;

  @override
  bool isErrorEnabled() => _logger.level == logging.Level.SHOUT;

  @override
  bool isInfoEnabled() => _logger.level == logging.Level.INFO;

  @override
  bool isWarnEnabled() => _logger.level == logging.Level.WARNING;

  @override
  void debug(String message) {
    _logger.severe(_formatter(message));
  }

  @override
  void error(String message) {
    _logger.shout(_formatter(message));
  }

  @override
  void info(String message) {
    _logger.info(_formatter(message));
  }

  @override
  void warn(String message) {
    _logger.warning(_formatter(message));
  }

  /// Formatter
  String _formatter(String message) {
    final DateTime now = DateTime.now();
    final String level = _logger.level.toString();
    return _lastMessage = '$now  $level >> ';
  }
}

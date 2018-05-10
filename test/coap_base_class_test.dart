/*
 * Package : Coap
 * Author : S. Hamblett <steve.hamblett@linux.com>
 * Date   : 13/04/2017
 * Copyright :  S.Hamblett
 */
import 'package:coap/coap.dart';
import 'package:test/test.dart';
import 'package:log4dart/log4dart_vm.dart';
import 'dart:io';

void main() {

  group('Media types', () {
    test('Properties', () {
      final int type = CoapMediaType.applicationJson;
      expect(CoapMediaType.name(type), "application/json");
      expect(CoapMediaType.fileExtension(type), "json");
      expect(CoapMediaType.isPrintable(type), true);
      expect(CoapMediaType.isImage(type), false);

      final int unknownType = 200;
      expect(CoapMediaType.name(unknownType), "unknown/200");
      expect(CoapMediaType.fileExtension(unknownType), "unknown/200");
      expect(CoapMediaType.isPrintable(unknownType), false);
      expect(CoapMediaType.isImage(unknownType), false);
    });

    test('Negotiation Content', () {
      final int defaultContentType = 10;
      final List<int> supported = [11, 5];
      List<CoapOption> accepted = new List<CoapOption>();
      final CoapOption opt1 = CoapOption.createVal(optionTypeMaxAge, 10);
      final CoapOption opt2 = CoapOption.createVal(optionTypeContentFormat, 5);
      accepted.add(opt1);
      accepted.add(opt2);
      expect(
          CoapMediaType.negotiationContent(
              defaultContentType, supported, accepted),
          5);
      opt2.intValue = 67;
      expect(
          CoapMediaType.negotiationContent(
              defaultContentType, supported, accepted),
          CoapMediaType.undefined);
      accepted = null;
      expect(
          CoapMediaType.negotiationContent(
              defaultContentType, supported, accepted),
          defaultContentType);
    });

    test('Parse', () {
      int res = CoapMediaType.parse(null);
      expect(res, CoapMediaType.undefined);

      res = CoapMediaType.parse("application/xml");
      expect(res, CoapMediaType.applicationXml);
    });

    test('Parse wild card', () {
      List<int> res = CoapMediaType.parseWildcard(null);
      expect(res, isNull);

      res = CoapMediaType.parseWildcard("xml*");
      expect(res, [
        CoapMediaType.textXml,
        CoapMediaType.applicationXml,
        CoapMediaType.applicationRdfXml,
        CoapMediaType.applicationSoapXml,
        CoapMediaType.applicationAtomXml,
        CoapMediaType.applicationXmppXml
      ]);
    });
  });

  group('Configuration', () {
    test('All', () {
      final CoapConfig conf = new CoapConfig("test/config_all.yaml");
      expect(conf.version, "RFC7252");
      expect(conf.defaultPort, 1);
      expect(conf.defaultSecurePort, 2);
      expect(conf.httpPort, 3);
      expect(conf.ackTimeout, 4);
      expect(conf.ackRandomFactor, 5.0);
      expect(conf.ackTimeoutScale, 6.0);
      expect(conf.maxRetransmit, 7);
      expect(conf.maxMessageSize, 8);
      expect(conf.defaultBlockSize, 9);
      expect(conf.blockwiseStatusLifetime, 10);
      expect(conf.useRandomIDStart, isFalse);
      expect(conf.useRandomTokenStart, isFalse);
      expect(conf.notificationMaxAge, 11);
      expect(conf.notificationCheckIntervalTime, 12);
      expect(conf.notificationCheckIntervalCount, 13);
      expect(conf.notificationReregistrationBackoff, 14);
      expect(conf.cropRotationPeriod, 15);
      expect(conf.exchangeLifetime, 16);
      expect(conf.markAndSweepInterval, 17);
      expect(conf.channelReceivePacketSize, 18);
      //TODO expect(conf.deduplicator,"");
      expect(conf.logTarget, "console");
      expect(conf.logFile, "coap_test.log");
      expect(conf.logError, false);
      expect(conf.logInfo, true);
      expect(conf.logWarn, true);
      expect(conf.logDebug, true);
    });

    test('Default', () {
      final CoapConfig conf = new CoapConfig("test/config_default.yaml");
      expect(conf.version, "RFC7252");
      expect(conf.defaultPort, 5683);
      expect(conf.defaultSecurePort, 5684);
      expect(conf.httpPort, 8080);
      expect(conf.ackTimeout, 2000);
      expect(conf.ackRandomFactor, 1.5);
      expect(conf.ackTimeoutScale, 2.0);
      expect(conf.maxRetransmit, 4);
      expect(conf.maxMessageSize, 1024);
      expect(conf.defaultBlockSize, 512);
      expect(conf.blockwiseStatusLifetime, 10 * 60 * 1000);
      expect(conf.useRandomIDStart, isTrue);
      expect(conf.useRandomTokenStart, isTrue);
      expect(conf.notificationMaxAge, 128 * 1000);
      expect(conf.notificationCheckIntervalTime, 24 * 60 * 60 * 1000);
      expect(conf.notificationCheckIntervalCount, 100);
      expect(conf.notificationReregistrationBackoff, 2000);
      expect(conf.cropRotationPeriod, 2000);
      expect(conf.exchangeLifetime, 247 * 1000);
      expect(conf.markAndSweepInterval, 10000);
      expect(conf.channelReceivePacketSize, 2048);
      //TODO expect(conf.deduplicator,"");
      expect(conf.logTarget, "none");
      expect(conf.logFile, "coaplog.txt");
      expect(conf.logError, true);
      expect(conf.logInfo, false);
      expect(conf.logWarn, false);
      expect(conf.logDebug, false);
    });

    test('Instance', () {
      final CoapConfig conf = new CoapConfig("test/config_default.yaml");
      expect(conf == CoapConfig.inst, isTrue);
    });
  });

  group('Logging', () {
    test('Null', () {
      final CoapLogManager logmanager = new CoapLogManager('none');
      final CoapILogger logger = logmanager.logger;
      expect(logger.isDebugEnabled(), isFalse);
      expect(logger.isErrorEnabled(), isFalse);
      expect(logger.isInfoEnabled(), isFalse);
      expect(logger.isWarnEnabled(), isFalse);
      logger.warn("Warning message");
      logger.info("Information message");
      logger.error("Error message");
      logger.debug("Debug message");
    });

    test('Console', () {
      final CoapConfig conf = new CoapConfig("test/config_logging.yaml");
      expect(conf.logTarget, "console");
      final CoapLogManager logmanager = new CoapLogManager('console');
      final CoapILogger logger = logmanager.logger;
      // Add a string appender to test correct log strings
      LoggerFactory.config["ConsoleLogger"].appenders.add(new StringAppender());
      final StringAppender appender =
          LoggerFactory.config["ConsoleLogger"].appenders.last;
      expect(logger.isDebugEnabled(), isTrue);
      expect(logger.isErrorEnabled(), isTrue);
      expect(logger.isInfoEnabled(), isTrue);
      expect(logger.isWarnEnabled(), isTrue);
      logger.warn("Warning message");
      expect(appender.content.contains("WARN ConsoleLogger: Warning message"),
          isTrue);
      appender.clear();
      logger.info("Information message");
      expect(
          appender.content.contains("INFO ConsoleLogger: Information message"),
          isTrue);
      appender.clear();
      logger.error("Error message");
      expect(appender.content.contains("ERROR ConsoleLogger: Error message"),
          isTrue);
      appender.clear();
      logger.debug("Debug message");
      expect(appender.content.contains("DEBUG ConsoleLogger: Debug message"),
          isTrue);
      appender.clear();
    });

    test('File', () {
      final CoapConfig conf = new CoapConfig("test/config_logging.yaml");
      final CoapLogManager logmanager = new CoapLogManager('file');
      final logFile = new File(conf.logFile);
      if (logFile.existsSync()) {
        logFile.deleteSync();
      }
      final CoapILogger logger = logmanager.logger;
      expect(logger.isDebugEnabled(), isTrue);
      expect(logger.isErrorEnabled(), isTrue);
      expect(logger.isInfoEnabled(), isTrue);
      expect(logger.isWarnEnabled(), isTrue);
      logger.warn("Warning message");
      sleep(const Duration(seconds: 1));
      logger.info("Information message");
      sleep(const Duration(seconds: 1));
      logger.error("Error message");
      sleep(const Duration(seconds: 1));
      logger.debug("Debug message");
      expect(logFile.lengthSync() > 0, isTrue);
    });
  });
}

/*
 * Package : Coap
 * Author : S. Hamblett <steve.hamblett@linux.com>
 * Date   : 31/05/2018
 * Copyright :  S.Hamblett
 */

part of coap;

class CoapReregistrationContext {
  static CoapILogger _log = new CoapLogManager("console").logger;
  CoapExchange _exchange;
  ActionGeneric<CoapRequest> _reregister;
  Timer _timer;
  int _timeout;

  CoapReregistrationContext(CoapExchange exchange, int timeout,
      ActionGeneric<CoapRequest> reregister) {
    _exchange = exchange;
    _reregister = reregister;
    _timeout = timeout;
  }

  void start() {
    _timer =
        new Timer(new Duration(milliseconds: _timeout), () => _timerElapsed());
  }

  void restart() {
    cancel();
    _timer =
        new Timer(new Duration(milliseconds: _timeout), () => _timerElapsed());
  }

  void cancel() {
    _timer.cancel();
  }

  void _timerElapsed() {
    final CoapRequest request = _exchange.request;
    if (!request.isCancelled) {
      final CoapRequest refresh = CoapRequest.newGet();
      refresh.setOptions(request.getSortedOptions());
      // Make sure Observe is set and zero
      refresh.markObserve();
      // Use same Token
      refresh.token = request.token;
      refresh.destination = request.destination;
      refresh.copyEventHandler(request);
      _log.debug("Re-registering for $request");
      request.fireReregistering(refresh);
      _reregister(refresh);
    } else {
      _log.debug("Dropping re-registration for canceled $request");
    }
  }
}

class CoapObserveLayer extends CoapAbstractLayer {
  /// Constructs a new observe layer.
  CoapObserveLayer(CoapConfig config) {
    _backoff = config.notificationReregistrationBackoff;
  }

  static CoapILogger _log = new CoapLogManager("console").logger;
  static String reregistrationContextKey = "ReregistrationContext";

  /// Additional time to wait until re-registration
  int _backoff;

  @override
  void sendResponse(
      CoapINextLayer nextLayer, CoapExchange exchange, CoapResponse response) {
    final CoapObserveRelation relation = exchange.relation;
    if (relation != null && relation.established) {
      if (exchange.request.isAcknowledged ||
          exchange.request.type == CoapMessageType.non) {
        // Transmit errors as CON
        if (!CoapCode.isSuccess(response.code)) {
          _log.debug(
              "Response has error code ${response.code} and must be sent as CON");
          response.type = CoapMessageType.con;
          relation.cancel();
        } else {
          // Make sure that every now and than a CON is mixed within
          if (relation.check()) {
            _log.debug(
                "The observe relation check requires the notification to be sent as CON");
            response.type = CoapMessageType.con;
          } else {
            // By default use NON, but do not override resource decision
            if (response.type == CoapMessageType.unknown)
              response.type = CoapMessageType.non;
          }
        }
      }

      // This is a notification
      response.last = false;

      // The matcher must be able to find the NON notifications to remove
      // them from the exchangesByID map
      if (response.type == CoapMessageType.non) {
        relation.addNotification(response);
      }
      // Only one Confirmable message is allowed to be in transit. A CON
      // is in transit as long as it has not been acknowledged, rejected,
      // or timed out. All further notifications are postponed here. If a
      // former CON is acknowledged or timeouts, it starts the freshest
      // notification (In case of a timeout, it keeps the retransmission
      //  counter). When a fresh/younger notification arrives but must be
      //  postponed we forget any former notification.

      if (response.type == CoapMessageType.con) {
        _prepareSelfReplacement(nextLayer, exchange, response);
      }

      // The decision whether to postpone this notification or not and the
      // decision which notification is the freshest to send next must be
      // synchronized
      final CoapResponse current = relation.currentControlNotification;
      if (current != null && _isInTransit(current)) {
        _log.debug(
            "A former notification is still in transit. Postpone $response");
        // use the same ID
        response.id = current.id;
        relation.nextControlNotification = response;
        return;
      } else {
        relation.currentControlNotification = response;
        relation.nextControlNotification = null;
      }
    }
    // Else no observe was requested or the resource does not allow it
    super.sendResponse(nextLayer, exchange, response);
  }

  @override
  void receiveResponse(
      CoapINextLayer nextLayer, CoapExchange exchange, CoapResponse response) {
    if (response.hasOption(optionTypeObserve)) {
      if (exchange.request.isCancelled) {
        // The request was canceled and we no longer want notifications
        _log.debug("ObserveLayer rejecting notification for canceled Exchange");
        final CoapEmptyMessage rst = CoapEmptyMessage.newRST(response);
        sendEmptyMessage(nextLayer, exchange, rst);
        // Matcher sets exchange as complete when RST is sent
      } else {
        _prepareReregistration(
            exchange, response, (msg) => sendRequest(nextLayer, exchange, msg));
        super.receiveResponse(nextLayer, exchange, response);
      }
    } else {
      // No observe option in response => always deliver
      super.receiveResponse(nextLayer, exchange, response);
    }
  }

  void receiveEmptyMessage(CoapINextLayer nextLayer, CoapExchange exchange,
      CoapEmptyMessage message) {
    // NOTE: We could also move this into the MessageObserverAdapter from
    // sendResponse into the method rejected().
    if (message.type == CoapMessageType.rst &&
        exchange.origin == CoapOrigin.remote) {
      // The response has been rejected
      final CoapObserveRelation relation = exchange.relation;
      if (relation != null) {
        relation.cancel();
      } // Else there was no observe relation ship and this layer ignores the rst
    }
    super.receiveEmptyMessage(nextLayer, exchange, message);
  }

  static bool _isInTransit(CoapResponse response) {
    final int type = response.type;
    final bool acked = response.isAcknowledged;
    final bool timeout = response.isTimedOut;
    final bool result = type == CoapMessageType.con && !acked && !timeout;
    return result;
  }

  void _prepareSelfReplacement(
      CoapINextLayer nextLayer, CoapExchange exchange, CoapResponse response) {
    response.acknowledgedHook = () {
      final CoapObserveRelation relation = exchange.relation;
      final CoapResponse next = relation.nextControlNotification;
      relation.currentControlNotification = next; // next may be null
      relation.nextControlNotification = null;
      if (next != null) {
        _log.debug("Notification has been acknowledged, send the next one");
        // this is not a self replacement, hence a new ID
        next.id = CoapMessage.none;
        // Create a new task for sending next response so that we can leave the sync-block
        executor.start(() => sendResponse(nextLayer, exchange, next));
      }
    };

    response.retransmittingHook = () {
      final CoapObserveRelation relation = exchange.relation;
      final CoapResponse next = relation.nextControlNotification;
      if (next != null) {
        _log.debug(
            "The notification has timed out and there is a fresher notification for the retransmission.");
        // Cancel the original retransmission and send the fresh notification here
        response.isCancelled = true;
        // Use the same ID
        next.id = response.id;
        // Convert all notification retransmissions to CON
        if (next.type != CoapMessageType.con) {
          next.type = CoapMessageType.con;
          _prepareSelfReplacement(nextLayer, exchange, next);
        }
        relation.currentControlNotification = next;
        relation.nextControlNotification = null;
        // Create a new task for sending next response so that we can leave the sync-block
        executor.start(() => sendResponse(nextLayer, exchange, next));
      }
    };

    response.timedOutHook = () {
      final CoapObserveRelation relation = exchange.relation;
      _log.debug(
          "Notification ${relation.exchange.request.tokenString} timed out. Cancel all relations with source ${relation.source}");
      relation.cancelAll();
    };
  }

  void _prepareReregistration(CoapExchange exchange, CoapResponse response,
      ActionGeneric<CoapRequest> reregister) {
    final int timeout = response.maxAge * 1000 + _backoff;
    final CoapReregistrationContext ctx =
        exchange.getOrAdd<CoapReregistrationContext>(reregistrationContextKey,
            new CoapReregistrationContext(exchange, timeout, reregister));

    _log.debug(
        "Scheduling re-registration in $timeout ms for ${exchange.request}");
    ctx.restart();
  }
}

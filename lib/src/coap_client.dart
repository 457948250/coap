/*
 * Package : Coap
 * Author : S. Hamblett <steve.hamblett@linux.com>
 * Date   : 05/06/2018
 * Copyright :  S.Hamblett
 */

part of coap;

/// Request fail reason
enum FailReason {
  /// The request has been rejected.
  rejected,

  /// The request has been timed out.
  timedOut
}

/// Provides convenient methods for accessing CoAP resources.
/// This class provides a fairly high level interface for the majority of
/// simple CoAP requests but because of this is fairly coarsely grained.
/// Much finer control of a request can be achieved by direct construction
/// and manipulation of a CoapRequest itself, however this is more involved,
/// for most cases the API in this class should suffice.
class CoapClient {
  /// Instantiates.
  /// A supplied request is optional depending on the API call being used.
  CoapClient(this.uri, this._config, [this.request]);

  CoapILogger _log = CoapLogManager().logger;
  static Iterable<CoapWebLink> _emptyLinks = <CoapWebLink>[CoapWebLink('')];

  /// The URI
  Uri uri;
  CoapConfig _config;

  /// The endpoint
  CoapIEndPoint endpoint;
  int _type = CoapMessageType.con;
  int _blockwise = 0;

  /// The current request
  CoapRequest request;

  /// Timeout
  int timeout = 32767;

  CoapEventBus _eventBus = CoapEventBus();

  /// Tell the client to use Confirmable requests.
  CoapClient useCONs() {
    _type = CoapMessageType.con;
    return this;
  }

  /// Let the client use early negotiation for the blocksize
  /// (16, 32, 64, 128, 256, 512, or 1024). Other values will
  /// be matched to the closest logarithm dualis.
  CoapClient useEarlyNegotiation(int size) {
    _blockwise = size;
    return this;
  }

  /// Let the client use late negotiation for the block size (default).
  CoapClient useLateNegotiation() {
    _blockwise = 0;
    return this;
  }

  /// Performs a CoAP ping and gives up after the given number of milliseconds.
  /// If a timeout is supplied it will overwrite any set in the client
  Future<bool> ping(int timeout) async {
    try {
      // Ping is a confirmable empty message
      CoapRequest request =
          CoapRequest.isConfirmable(CoapCode.empty, confirmable: true);
      request.token = CoapConstants.emptyToken;
      request.uri = uri;
      request = await prepare(request);
      this.request = request;
      final int timeoutToUse = timeout == null ? this.timeout : timeout;
      await request.send().waitForResponse(timeoutToUse);
      return request.isRejected;
    } on Exception catch (e) {
      _log.warn('doPing - Exception raised pinging: $e');
    }
    return false;
  }

  /// Sends a GET request and blocks until the response is available.
  /// If no request has been set in the client a default one is used.
  Future<CoapResponse> get() {
    if (request == null) {
      return send(CoapRequest.newGet());
    } else {
      return send(request);
    }
  }

  /// Sends a GET request with the specified Accept option and blocks
  /// until the response is available.
  Future<CoapResponse> getWithAccept(int acceptVal) =>
      send(accept(CoapRequest.newGet(), acceptVal));

  /// Sends a POST request and blocks until the response is available.
  Future<CoapResponse> post(String payload,
          [int format = CoapMediaType.textPlain]) =>
      send(CoapRequest.newPost().setPayloadMedia(payload, format));

  /// Sends a POST request with the specified Accept option and blocks
  /// until the response is available.
  Future<CoapResponse> postWithAccept(
          String payload, int format, int acceptVal) =>
      send(accept(
          CoapRequest.newPost().setPayloadMedia(payload, format), acceptVal));

  /// Sends a POST request with the specified byte payload and blocks
  /// until the response is available.
  Future<CoapResponse> postBytePayload(typed.Uint8Buffer payload, int format) =>
      send(CoapRequest.newPost().setPayloadMediaRaw(payload, format));

  /// Sends a POST request with the specified Accept option and byte payload.
  /// Blocks until the response is available.
  Future<CoapResponse> postBytePayloadWithAccept(
          typed.Uint8Buffer payload, int format, int acceptVal) =>
      send(accept(CoapRequest.newPost().setPayloadMediaRaw(payload, format),
          acceptVal));

  /// Sends a PUT request and blocks until the response is available.
  Future<CoapResponse> put(String payload,
          [int format = CoapMediaType.textPlain]) =>
      send(CoapRequest.newPut().setPayloadMedia(payload, format));

  /// Sends a PUT request with the specified Accept option and blocks
  /// until the response is available.
  Future<CoapResponse> putBytePayloadWithAccept(
          typed.Uint8Buffer payload, int format, int acceptVal) =>
      send(accept(
          CoapRequest.newPut().setPayloadMediaRaw(payload, format), acceptVal));

  /// If match
  Future<CoapResponse> putIfMatch(
          String payload, int format, List<typed.Uint8Buffer> etags) =>
      send(ifMatch(
          CoapRequest.newPut().setPayloadMedia(payload, format), etags));

  /// If match byte payload
  Future<CoapResponse> putIfMatchBytePayload(typed.Uint8Buffer payload,
          int format, List<typed.Uint8Buffer> etags) =>
      send(ifMatch(
          CoapRequest.newPut().setPayloadMediaRaw(payload, format), etags));

  /// If none match
  Future<CoapResponse> putIfNoneMatch(String payload, int format) =>
      send(ifNoneMatch(CoapRequest.newPut().setPayloadMedia(payload, format)));

  /// If none match byte payload
  Future<CoapResponse> putIfNoneMatchBytePayload(
          typed.Uint8Buffer payload, int format) =>
      send(ifNoneMatch(
          CoapRequest.newPut().setPayloadMediaRaw(payload, format)));

  /// Delete
  Future<CoapResponse> delete() => send(CoapRequest.newDelete());

  /// Validate
  Future<CoapResponse> validate(List<typed.Uint8Buffer> etags) =>
      send(eTags(CoapRequest.newGet(), etags));

  /// Observe
  CoapObserveClientRelation observe(
          [ActionGeneric<CoapResponse> notify,
          ActionGeneric<FailReason> error]) =>
      _observe(CoapRequest.newGet().markObserve(), notify, error);

  /// Observe with accept
  CoapObserveClientRelation observeWithAccept(int acceptVal,
          [ActionGeneric<CoapResponse> notify,
          ActionGeneric<FailReason> error]) =>
      _observe(
          accept(CoapRequest.newGet().markObserve(), acceptVal), notify, error);

  /// Accept
  static CoapRequest accept(CoapRequest request, int accept) {
    request.accept = accept;
    return request;
  }

  /// If match
  static CoapRequest ifMatch(
      CoapRequest request, List<typed.Uint8Buffer> etags) {
    etags.forEach(request.addIfMatch);
    return request;
  }

  /// If none match
  static CoapRequest ifNoneMatch(CoapRequest request) {
    request.ifNoneMatch = true;
    return request;
  }

  /// Etags
  CoapRequest eTags(CoapRequest request, List<typed.Uint8Buffer> etags) {
    etags.forEach(request.addETag);
    return request;
  }

  /// Discovers remote resources.
  /// Creates its own request to do this.
  Future<Iterable<CoapWebLink>> discover(String query) async {
    final CoapRequest request = CoapRequest.newGet();
    request.uri = uri;
    final CoapRequest discover = await prepare(request);
    discover.clearUriPath().clearUriQuery().uriPath =
        CoapConstants.defaultWellKnownURI;
    if (query != null && query.isNotEmpty) {
      discover.uriQuery = query;
    }
    this.request = discover;
    final CoapResponse links = await discover.send().waitForResponse(timeout);
    if (links == null) {
      // If no response, return null (e.g., timeout)
      return null;
    } else if (links.contentFormat != CoapMediaType.applicationLinkFormat) {
      return _emptyLinks;
    } else {
      return CoapLinkFormat.parse(links.payloadString);
    }
  }

  /// Send
  Future<CoapResponse> send(CoapRequest request) async {
    await prepare(request);
    return request.send().waitForResponse(timeout);
  }

  /// Prepare
  Future<CoapRequest> prepare(CoapRequest request) async =>
      await _doPrepare(request);

  /// Cancel the current request
  void cancelRequest() {
    request?.stop();
  }

  /// Close the client, this effectively means this client is no longer usable
  void close() {
    _log.info('Close - closing client');
    cancelRequest();
    _eventBus.destroy();
  }

  /// Gets the effective endpoint that the specified request
  /// is supposed to be sent over.
  CoapIEndPoint _getEffectiveEndpoint(CoapRequest request) {
    if (endpoint != null) {
      return endpoint;
    } else {
      return CoapEndpointManager.getDefaultEndpoint(request.endPoint);
    }
  }

  Future<CoapRequest> _doPrepare(CoapRequest request) async {
    request.type = _type;
    request.uri = uri;

    await request.resolveDestination(InternetAddressType.IPv4);
    CoapEndpointManager.getDefaultSpec();
    final CoapIChannel channel = CoapUDPChannel(request.destination, uri.port);
    request.endPoint = CoapEndPoint(channel, _config);
    request.endPoint.start();

    if (_blockwise != 0) {
      request.setBlock2(CoapBlockOption.encodeSZX(_blockwise), 0, m: false);
    }

    if (endpoint != null) {
      request.endPoint = endpoint;
    }
    return request;
  }

  CoapObserveClientRelation _observe(CoapRequest request,
      ActionGeneric<CoapResponse> notify, ActionGeneric<FailReason> error) {
    final CoapObserveClientRelation relation =
        _observeAsync(request, notify, error);
    final CoapResponse response = relation.request.waitForResponse(timeout);
    if (response == null || !response.hasOption(optionTypeObserve)) {
      relation.cancelled = true;
    }
    relation.current = response;
    return relation;
  }

  CoapObserveClientRelation _observeAsync(CoapRequest request,
      ActionGeneric<CoapResponse> notify, ActionGeneric<FailReason> error) {
    final CoapIEndPoint endpoint = _getEffectiveEndpoint(request);
    final CoapObserveClientRelation relation =
        CoapObserveClientRelation(request, endpoint, _config);
    _doPrepare(request);
    request.send();
    return relation;
  }
}

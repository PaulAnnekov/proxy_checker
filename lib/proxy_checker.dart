library rozetka_email_dumper;

import "dart:io";
import "dart:convert";
import "package:logging/logging.dart";
import "package:duct_tape/duct_tape.dart";

class ProxyChecker implements IsolateWrapper {
  IsolateSpawned _isolate;
  HttpClient _client;
  Logger _log;
  String _hostIP;

  ProxyChecker(this._hostIP);

  run(IsolateSpawned isolate) async {
    Logger.root.level = Level.INFO;
    Logger.root.onRecord.listen((LogRecord rec) {
      print('${rec.level.name}: ${rec.time}: ${rec.message}');
    });

    _isolate = isolate;
    _client = new HttpClient();
    _log = new Logger('proxy-checker');

    _checkProxy(await _isolate.send('getIP'));
  }

  _checkProxy(String proxy) async {
    if (proxy == null)
      return;

    _log.info('Check $proxy');

    _client.findProxy = (Uri url) => 'PROXY $proxy';

    _client.getUrl(Uri.parse('http://www.xhaus.com/headers'))
        .timeout(const Duration(seconds: 5))
        .then((HttpClientRequest request) => request.close())
        .timeout(const Duration(seconds: 5))
        .then((HttpClientResponse response) {
          response.transform(UTF8.decoder).listen((String body) {
            if(!body.contains('Your browser software transmitted the '
                'following HTTP headers') || (!_hostIP.isEmpty && body.contains(_hostIP)))
              return;

            _log.info('$proxy is valid');

            _isolate.send(proxy);
          }).onError(() {
            // Do nothing.
          });
        })
        .catchError((e) {
          _log.fine('Error $e for $proxy');
        })
        .whenComplete(() async {
          _checkProxy(await _isolate.send('getIP'));
        });
  }
}
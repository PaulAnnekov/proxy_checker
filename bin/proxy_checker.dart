/**
 * 1. Collect proxy ips. Only anonymous (check on server).
 * 2. Get categories list. Single request.
 * 3. Get list of products. Pager.
 * 4. Get list of reviews. Pager.
 */

import "dart:io";
import "package:args/args.dart";
import "package:logging/logging.dart";
import "package:duct_tape/duct_tape.dart";
import "package:proxy_checker/proxy_checker.dart";

main(List<String> args) async {
  Logger.root.level = Level.INFO;
  Logger.root.onRecord.listen((LogRecord rec) {
    print('${rec.level.name}: ${rec.time}: ${rec.message}');
  });

  final Logger log = new Logger('main');

  ArgParser argParser = new ArgParser();
  argParser.addOption('proxy-list', abbr: 'p', defaultsTo: 'proxy.txt',
      help: 'Collect from Google search results: ":8080"  ":3128"  ":80" filetype:txt');
  argParser.addOption('proxy-valid', abbr: 'v', defaultsTo: 'proxy-valid.txt');
  argParser.addOption('host-ip', abbr: 'i');
  ArgResults results = argParser.parse(args);

  File proxyFile = new File(results['proxy-list']);
  if(!proxyFile.existsSync()) {
    log.severe('File ${results['proxy-list']} with proxy list does not'
      ' exist.');
    return;
  }

  File validFile = new File(results['proxy-valid']);
  if (validFile.existsSync())
    validFile.deleteSync();

  List<String> proxyIPs = proxyFile.readAsLinesSync();

  IsolatesController isolatesController = new IsolatesController();
  isolatesController.spawn(new ProxyChecker(results['host-ip']));
  isolatesController.spawn(new ProxyChecker(results['host-ip']));
  isolatesController.spawn(new ProxyChecker(results['host-ip']));
  isolatesController.spawn(new ProxyChecker(results['host-ip']));
  isolatesController.listen((message) {
    log.finest('Message from isolate: "$message"');

    if (message == 'getIP') {
      if (!proxyIPs.isEmpty)
        return proxyIPs.removeAt(0);

      log.info('Scanning done');
    } else if ((message as String).contains(':')) {
      validFile.writeAsString(message+'\n', mode: FileMode.APPEND);
    } else {
      log.warning('Unknown message: "$message"');
    }
  });
}
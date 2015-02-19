/**
 * 1. Collect proxy ips. Only anonymous (check on server).
 * 2. Get categories list. Single request.
 * 3. Get list of products. Pager.
 * 4. Get list of reviews. Pager.
 */

import "dart:io";
import "dart:math";
import "package:args/args.dart";
import "package:logging/logging.dart";
import "package:duct_tape/duct_tape.dart";
import "package:proxy_checker/proxy_checker.dart";

main(List<String> args) async {
  Logger.root.level = Level.INFO;
  Logger.root.onRecord.listen((LogRecord rec) {
    print('${rec.level.name}: ${rec.time}: ${rec.message}');
  });

  Random random = new Random();
  final Logger log = new Logger('main');

  ArgParser argParser = new ArgParser();
  argParser.addOption('proxy-list', abbr: 'p', defaultsTo: 'proxy.txt',
      help: 'Collect from Google search results: ":8080"  ":3128"  ":80" filetype:txt');
  argParser.addOption('proxy-valid', abbr: 'v', defaultsTo: 'proxy-valid.txt');
  argParser.addOption('host-ip', abbr: 'i', help: 'Must be set to check for anonymity', defaultsTo: '');
  argParser.addFlag('random', abbr: 'n', help: 'Check IPs in random order', defaultsTo: true);
  argParser.addOption('regex', abbr: 'r', help: 'Regex with capture group to get only proxy address with port', defaultsTo: r'(\d+\.\d+\.\d+\.\d+:\d+)');
  argParser.addFlag('anonymous', abbr: 'a', help: 'Set to save only anonymous proxy', defaultsTo: false);
  argParser.addFlag('help', abbr: 'h', help: 'Displays this usage guide');
  ArgResults results = argParser.parse(args);

  if(results['help']) {
    print(argParser.getUsage());
    return;
  }

  if(results['anonymous'] && results['host-ip'].isEmpty) {
    log.severe('Anonymous check is set but host ip is not passed. Use -i to pass host ip.');
    return;
  }

  File proxyFile = new File(results['proxy-list']);
  if(!proxyFile.existsSync()) {
    log.severe('File ${results['proxy-list']} with proxy list does not'
      ' exist.');
    return;
  }

  if(!results.wasParsed('host-ip')) {
    log.severe('Host ip is not specified.');
    return;
  }

  File validFile = new File(results['proxy-valid']);
  if (validFile.existsSync())
    validFile.deleteSync();

  List<String> proxyIPs = [];
  List<String> fileLines = proxyFile.readAsLinesSync();
  fileLines.forEach((String line) {
    String address = !results['regex'].isEmpty ? new RegExp(results['regex']).stringMatch(line) : line;
    if (address != null && !address.isEmpty) {
      proxyIPs.add(address);
    };
  });

  IsolatesController isolatesController = new IsolatesController();
  isolatesController.spawn(new ProxyChecker(results['host-ip']));
  isolatesController.spawn(new ProxyChecker(results['host-ip']));
  isolatesController.spawn(new ProxyChecker(results['host-ip']));
  isolatesController.spawn(new ProxyChecker(results['host-ip']));
  isolatesController.listen((message) {
    log.finest('Message from isolate: "$message"');

    if (message == 'getIP') {
      if (!proxyIPs.isEmpty) {
        return proxyIPs.removeAt(results['random'] == true ? random.nextInt(proxyIPs.length) : 0);
      }

      log.info('Scanning done');
    } else if ((message as String).contains(':')) {
      validFile.writeAsString(message+'\n', mode: FileMode.APPEND);
    } else {
      log.warning('Unknown message: "$message"');
    }
  });
}
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:mcp_server/mcp_server.dart';

import 'serve_bundle.dart';

/// register_server — a shop register where some buttons are not for everyone.
///
/// The role is not a parameter. It is decided when the session is opened —
/// here by a launch argument, in a real deployment by whatever the connection
/// authenticated as — and the tools read it from there.
///
/// This is the whole point of the sample. If `sale.void` took a `role`
/// argument, then anybody who can call the tool can claim to be a manager, and
/// hiding the button on the screen would be the only thing standing in the
/// way. A hidden button is not a rule. It is a hope about which client is
/// running.
void main(List<String> args) async {
  final role = args
      .firstWhere((a) => a.startsWith('--role='), orElse: () => '--role=staff')
      .substring('--role='.length);

  final config = McpServerConfig(
    name: 'Register ($role)',
    version: '1.0.0',
    capabilities:
        const ServerCapabilities(
      tools: ToolsCapability(listChanged: true),
      resources: ResourcesCapability(listChanged: true),
    ),
  );
  final server = McpServer.createServer(config);
  RegisterServer(
    server,
    role,
    File(Platform.environment['REGISTER_AUDIT'] ?? 'audit.log'),
  ).register();
  // The screen next door: AppPlayer reads it from here and sends the pages'
  // tool calls back to the tools above.
  registerBundleUi(server, '../register.mbd');
  final transport = McpServer.createStdioTransport().get();
  server.connect(transport);
  await Completer<void>().future;
}

class RegisterServer {
  RegisterServer(this.server, this.role, this.audit);

  final Server server;

  /// Who this session is. Fixed for its lifetime, never taken from a call.
  final String role;

  /// Refusals go here as well as into the answer. A refusal that only the
  /// person who was refused can see is not much of a control — the point of
  /// writing it down is that somebody who was not standing there can read it
  /// tomorrow.
  final File audit;

  static const _managerOnly = {'sale.void', 'drawer.open', 'price.override'};

  final _sales = <int>[900, 4200, 1500];
  var _voided = 0;
  var _refused = 0;

  void register() {
    server.addTool(
      name: 'sale.ring',
      description: 'Ring up an amount. Anyone at the register may do this.',
      inputSchema: const {
        'type': 'object',
        'properties': {
          'amount': {'type': 'integer'},
        },
        'required': ['amount'],
      },
      handler: (args) async {
        if (!_allowed('sale.ring')) return _refuse('sale.ring');
        _sales.add(args['amount'] as int);
        return _state(notice: 'rang \$${((args['amount'] as int) / 100).toStringAsFixed(2)}');
      },
    );

    server.addTool(
      name: 'sale.void',
      description: 'Void the last sale. Manager only.',
      inputSchema: const {'type': 'object', 'properties': {}},
      handler: (args) async {
        if (!_allowed('sale.void')) return _refuse('sale.void');
        if (_sales.isEmpty) return _state(notice: 'nothing to void');
        final gone = _sales.removeLast();
        _voided++;
        return _state(notice: 'voided \$${(gone / 100).toStringAsFixed(2)}');
      },
    );

    server.addTool(
      name: 'drawer.open',
      description: 'Open the cash drawer without a sale. Manager only.',
      inputSchema: const {'type': 'object', 'properties': {}},
      handler: (args) async {
        if (!_allowed('drawer.open')) return _refuse('drawer.open');
        return _state(notice: 'drawer opened');
      },
    );

    server.addTool(
      name: 'register.state',
      description: 'What the register looks like right now',
      inputSchema: const {'type': 'object', 'properties': {}},
      handler: (args) async => _state(),
    );
  }

  bool _allowed(String tool) =>
      !_managerOnly.contains(tool) || role == 'manager';

  CallToolResult _refuse(String tool) {
    _refused++;
    // Refused, and said out loud. The screen is told why, and the shop keeps
    // a line about it.
    final line = 'refused $tool for role=$role';
    audit.writeAsStringSync('$line\n', mode: FileMode.append);
    return _state(notice: '$tool is not yours to press', refusedTool: tool);
  }

  CallToolResult _state({String notice = '', String refusedTool = ''}) {
    final total = _sales.fold<int>(0, (a, b) => a + b);
    return CallToolResult(content: [
      TextContent(
        text: jsonEncode({
          'role': role.toUpperCase(),
          'roleColor': role == 'manager' ? '#1d4ed8' : '#6b7280',
          'sales': _sales.length,
          'total': '\$${(total / 100).toStringAsFixed(2)}',
          'voided': _voided,
          'refused': _refused,
          'refusedTool': refusedTool,
          // The rule the till enforces, printed where the clerk can read it.
          // The refusal happens here, not in the screen: a screen that hides
          // the button still sends the call when somebody finds it.
          'guardRule': 'Voids and drawer opens are the manager\'s · '
              'the till refuses and writes the refusal down',
          'refusedNote': refusedTool.isEmpty
              ? 'no refusals this session'
              : '$refusedTool refused · written to the audit log',
          'notice': notice,
        }),
      )
    ]);
  }
}

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:paper_agent/features/agent/action_receipts.dart';
import 'package:paper_agent/features/agent/domain/agent_protocol.dart';
import 'package:paper_agent/features/agent/domain/document_tools.dart';

void main() {
  const call = AgentToolCall(
    id: 'a',
    name: 'insert_block',
    arguments: {'page': 1},
  );
  test(
    'simultaneous deliveries and later retries execute the mutation once',
    () async {
      final receipts = ActionReceipts();
      final pending = Completer<ToolResult?>();
      var writes = 0;
      Future<ToolResult?> mutate() {
        writes++;
        return pending.future;
      }

      final first = receipts.once(call, mutate);
      final second = receipts.once(call, mutate);
      pending.complete(const ToolResult.ok('applied'));
      expect((await first)!.ok, isTrue);
      expect(await second, same(await first));
      expect(await receipts.once(call, mutate), same(await first));
      expect(writes, 1);
    },
  );
  test('reused identity with different arguments is rejected', () async {
    final receipts = ActionReceipts();
    await receipts.once(call, () async => const ToolResult.ok('applied'));
    var executed = false;
    final result = await receipts.once(
      const AgentToolCall(
        id: 'a',
        name: 'insert_block',
        arguments: {'page': 2},
      ),
      () async {
        executed = true;
        return const ToolResult.ok('wrong');
      },
    );
    expect(result!.ok, isFalse);
    expect(executed, isFalse);
  });
  test('an interrupted mutation is not blindly executed again', () async {
    final receipts = ActionReceipts();
    var attempts = 0;
    Future<ToolResult?> fail() async {
      attempts++;
      throw StateError('interrupted');
    }

    expect((await receipts.once(call, fail))!.ok, isFalse);
    expect((await receipts.once(call, fail))!.ok, isFalse);
    expect(attempts, 1);
  });
}

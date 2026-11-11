import 'package:flutter_test/flutter_test.dart';
import 'package:speechcare_flutter/core/util.dart';
import 'package:speechcare_flutter/state/sync_engine.dart';

J rec(String id, String name, [num u = 0]) => <String, dynamic>{'id': id, 'name': name, '_u': u};
J st(List<J> p, {Map<String, dynamic>? me}) => <String, dynamic>{'p': p, 'a': <dynamic>[], 'c': <dynamic>[], 'me': me ?? <String, dynamic>{'name': 'X', 'places': <dynamic>[]}};

void main() {
  test('stable() ignores _u and key order', () {
    expect(stable({'b': 1, 'a': 2, '_u': 5}), stable({'a': 2, 'b': 1.0}));
  });

  test('merge keeps a patient added on each device', () {
    final base = snapshot(st([rec('1', 'A')]));
    final local = st([rec('1', 'A'), rec('2', 'B', 10)]);
    final remote = st([rec('1', 'A'), rec('3', 'C', 11)]);
    final m = mergeStates(base, local, remote);
    final ids = (m['p'] as List).map((e) => e['id']).toSet();
    expect(ids, {'1', '2', '3'});
  });

  test('merge: a deletion made here is not resurrected by the cloud', () {
    final base = snapshot(st([rec('1', 'A'), rec('2', 'B')]));
    final local = st([rec('1', 'A')]);
    final remote = st([rec('1', 'A'), rec('2', 'B')]);
    final m = mergeStates(base, local, remote);
    expect((m['p'] as List).map((e) => e['id']).toList(), ['1']);
  });

  test('merge: edit on one side wins over untouched other side', () {
    final base = snapshot(st([rec('1', 'A')]));
    final local = st([rec('1', 'A2', 20)]);
    final remote = st([rec('1', 'A')]);
    final m = mergeStates(base, local, remote);
    expect((m['p'] as List).first['name'], 'A2');
  });

  test('merge: same record edited on both sides -> newest _u wins', () {
    final base = snapshot(st([rec('1', 'A')]));
    final local = st([rec('1', 'L', 20)]);
    final remote = st([rec('1', 'R', 30)]);
    final m = mergeStates(base, local, remote);
    expect((m['p'] as List).first['name'], 'R');
  });
}

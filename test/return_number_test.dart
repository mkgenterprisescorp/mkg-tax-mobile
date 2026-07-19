import 'package:flutter_test/flutter_test.dart';
import 'package:mkg_tax_mobile/core/tax_year/return_number.dart';

void main() {
  test('prefixFromLastName uses first four letters and pads short names', () {
    expect(ReturnNumber.prefixFromLastName('Govan'), 'GOVA');
    expect(ReturnNumber.prefixFromLastName('Smith-Jones'), 'SMIT');
    expect(ReturnNumber.prefixFromLastName("O'Neill"), 'ONEI');
    expect(ReturnNumber.prefixFromLastName('Lee'), 'LEEX');
    expect(ReturnNumber.prefixFromLastName(''), 'UNKN');
    expect(ReturnNumber.prefixFromLastName(null), 'UNKN');
  });

  test('format builds XXXX-MM-DD-SEQ', () {
    final date = DateTime(2026, 7, 19);
    expect(
      ReturnNumber.format(prefix: 'GOVA', date: date, sequence: 1),
      'GOVA-07-19-01',
    );
    expect(
      ReturnNumber.format(prefix: 'gova', date: date, sequence: 11),
      'GOVA-07-19-11',
    );
  });

  test('next increments daily sequence for same last-name prefix', () {
    final date = DateTime(2026, 7, 19);
    expect(
      ReturnNumber.next(lastName: 'Govan', date: date, existingCodes: const []),
      'GOVA-07-19-01',
    );
    expect(
      ReturnNumber.next(
        lastName: 'Govan',
        date: date,
        existingCodes: const ['GOVA-07-19-01', 'GOVA-07-19-02'],
      ),
      'GOVA-07-19-03',
    );
    expect(
      ReturnNumber.next(
        lastName: 'Govan',
        date: date,
        existingCodes: const ['SMIT-07-19-01'],
      ),
      'GOVA-07-19-01',
    );
  });

  test('fromWorkspaceJson reads laravel and portal shapes', () {
    expect(ReturnNumber.fromWorkspaceJson({'return_number': 'GOVA-07-19-01'}), 'GOVA-07-19-01');
    expect(
      ReturnNumber.fromWorkspaceJson({
        'data': {'returnNumber': 'GOVA-07-19-02'},
      }),
      'GOVA-07-19-02',
    );
    expect(ReturnNumber.fromWorkspaceJson({'id': 1}), isNull);
  });
}

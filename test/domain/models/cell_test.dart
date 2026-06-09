import 'package:flutter_test/flutter_test.dart';
import 'package:gravity_sudoku/domain/models/cell.dart';

void main() {
  group('Cell', () {
    test('default cell is empty', () {
      const c = Cell();
      expect(c.isEmpty, isTrue);
      expect(c.hasNumber, isFalse);
      expect(c.isIceBlock, isFalse);
    });

    test('cell with value is not empty', () {
      const c = Cell(value: 3);
      expect(c.isEmpty, isFalse);
      expect(c.hasNumber, isTrue);
    });

    test('ice block cell is not empty', () {
      const c = Cell(isIceBlock: true);
      expect(c.isEmpty, isFalse);
      expect(c.hasNumber, isFalse);
    });

    test('copyWith replaces only specified fields', () {
      const c = Cell(value: 5, isFixed: true);
      final c2 = c.copyWith(value: 7);
      expect(c2.value, 7);
      expect(c2.isFixed, isTrue);
    });

    test('cleared removes value and fixed flag', () {
      const c = Cell(value: 3, isFixed: false);
      final c2 = c.cleared();
      expect(c2.value, isNull);
      expect(c2.isFixed, isFalse);
    });

    test('equality by value', () {
      expect(const Cell(value: 1), equals(const Cell(value: 1)));
      expect(const Cell(value: 1), isNot(equals(const Cell(value: 2))));
    });
  });
}

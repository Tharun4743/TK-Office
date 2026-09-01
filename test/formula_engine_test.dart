import 'package:flutter_test/flutter_test.dart';
import 'package:tk_office/models/spreadsheet_model.dart';
import 'package:tk_office/services/spreadsheet_service/formula_engine.dart';

void main() {
  group('FormulaEngine Unit Tests', () {
    test('Basic Arithmetic', () {
      final sheet = SheetModel(name: 'Sheet1');
      sheet.setCell(0, 0, CellModel(value: '10')); // A1
      sheet.setCell(0, 1, CellModel(value: '20')); // B1

      expect(FormulaEngine.evaluate('=10 + 20', sheet), '30');
      expect(FormulaEngine.evaluate('=50 - 15', sheet), '35');
      expect(FormulaEngine.evaluate('=6 * 7', sheet), '42');
      expect(FormulaEngine.evaluate('=100 / 4', sheet), '25');
    });

    test('SUM and AVERAGE Formulas', () {
      final sheet = SheetModel(name: 'Sheet1');
      sheet.setCell(0, 0, CellModel(value: '10')); // A1
      sheet.setCell(1, 0, CellModel(value: '20')); // A2
      sheet.setCell(2, 0, CellModel(value: '30')); // A3

      expect(FormulaEngine.evaluate('=SUM(A1:A3)', sheet), '60');
      expect(FormulaEngine.evaluate('=AVERAGE(A1:A3)', sheet), '20');
      expect(FormulaEngine.evaluate('=MIN(A1:A3)', sheet), '10');
      expect(FormulaEngine.evaluate('=MAX(A1:A3)', sheet), '30');
      expect(FormulaEngine.evaluate('=COUNT(A1:A3)', sheet), '3');
    });

    test('Logical IF and String CONCAT Formulas', () {
      final sheet = SheetModel(name: 'Sheet1');
      sheet.setCell(0, 0, CellModel(value: '75')); // A1

      expect(FormulaEngine.evaluate('=IF(A1>50, "Pass", "Fail")', sheet), 'Pass');
      expect(FormulaEngine.evaluate('=IF(A1<50, "Pass", "Fail")', sheet), 'Fail');

      sheet.setCell(0, 1, CellModel(value: 'Hello')); // B1
      sheet.setCell(0, 2, CellModel(value: 'World')); // C1
      expect(FormulaEngine.evaluate('=CONCAT(B1, " ", C1)', sheet), 'Hello World');
      expect(FormulaEngine.evaluate('=LEN(B1)', sheet), '5');
      expect(FormulaEngine.evaluate('=UPPER(B1)', sheet), 'HELLO');
    });
  });
}

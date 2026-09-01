import 'dart:math' as math;
import '../../models/spreadsheet_model.dart';

class FormulaEngine {
  /// Evaluates all formulas within a given Sheet
  static void recalculateSheet(SheetModel sheet) {
    for (final entry in sheet.cells.entries) {
      final cell = entry.value;
      if (cell.formula != null && cell.formula!.startsWith('=')) {
        cell.calculatedValue = evaluate(cell.formula!, sheet);
      } else {
        cell.calculatedValue = cell.value;
      }
    }
  }

  /// Evaluates an individual formula string (e.g., "=SUM(A1:A5) + 10")
  static String evaluate(String formula, SheetModel sheet) {
    if (!formula.startsWith('=')) return formula;
    final expr = formula.substring(1).trim();

    try {
      // 1. Function evaluation
      final upper = expr.toUpperCase();
      if (upper.startsWith('SUM(')) {
        return _evalSum(expr, sheet);
      } else if (upper.startsWith('AVERAGE(')) {
        return _evalAverage(expr, sheet);
      } else if (upper.startsWith('MIN(')) {
        return _evalMin(expr, sheet);
      } else if (upper.startsWith('MAX(')) {
        return _evalMax(expr, sheet);
      } else if (upper.startsWith('COUNT(')) {
        return _evalCount(expr, sheet);
      } else if (upper.startsWith('COUNTA(')) {
        return _evalCountA(expr, sheet);
      } else if (upper.startsWith('IF(')) {
        return _evalIf(expr, sheet);
      } else if (upper.startsWith('CONCAT(')) {
        return _evalConcat(expr, sheet);
      } else if (upper.startsWith('LEN(')) {
        return _evalLen(expr, sheet);
      } else if (upper.startsWith('UPPER(')) {
        return _evalUpper(expr, sheet);
      } else if (upper.startsWith('LOWER(')) {
        return _evalLower(expr, sheet);
      } else if (upper.startsWith('TRIM(')) {
        return _evalTrim(expr, sheet);
      } else if (upper.startsWith('ROUND(')) {
        return _evalRound(expr, sheet);
      } else if (upper.startsWith('ABS(')) {
        return _evalAbs(expr, sheet);
      }

      // 2. Direct cell reference e.g. "=A1"
      if (RegExp(r'^[A-Za-z]+[0-9]+$').hasMatch(expr)) {
        final val = _getCellValue(expr.toUpperCase(), sheet);
        return val;
      }

      // 3. Simple arithmetic evaluation e.g. "=10 + 20" or "=A1 + B1"
      return _evalSimpleArithmetic(expr, sheet);
    } catch (e) {
      return '#VALUE!';
    }
  }

  static List<double> _resolveNumericRange(String arg, SheetModel sheet) {
    final List<double> numbers = [];
    final parts = arg.split(',');

    for (var part in parts) {
      part = part.trim();
      if (part.contains(':')) {
        // Range like A1:A10
        final rangeParts = part.split(':');
        if (rangeParts.length == 2) {
          final cells = _getCellsInRange(rangeParts[0].trim().toUpperCase(), rangeParts[1].trim().toUpperCase(), sheet);
          for (final cellVal in cells) {
            final numVal = double.tryParse(cellVal);
            if (numVal != null) numbers.add(numVal);
          }
        }
      } else if (RegExp(r'^[A-Z]+[0-9]+$').hasMatch(part.toUpperCase())) {
        final val = _getCellValue(part.toUpperCase(), sheet);
        final numVal = double.tryParse(val);
        if (numVal != null) numbers.add(numVal);
      } else {
        final numVal = double.tryParse(part);
        if (numVal != null) numbers.add(numVal);
      }
    }
    return numbers;
  }

  static List<String> _getCellsInRange(String startKey, String endKey, SheetModel sheet) {
    final List<String> values = [];
    final startCol = startKey.codeUnitAt(0) - 65;
    final startRow = int.tryParse(startKey.substring(1)) ?? 1;
    final endCol = endKey.codeUnitAt(0) - 65;
    final endRow = int.tryParse(endKey.substring(1)) ?? 1;

    final minCol = math.min(startCol, endCol);
    final maxCol = math.max(startCol, endCol);
    final minRow = math.min(startRow, endRow);
    final maxRow = math.max(startRow, endRow);

    for (var r = minRow - 1; r < maxRow; r++) {
      for (var c = minCol; c <= maxCol; c++) {
        final key = SheetModel.getCellKey(r, c);
        final cell = sheet.cells[key];
        values.add(cell?.calculatedValue ?? cell?.value ?? '');
      }
    }
    return values;
  }

  static String _getCellValue(String key, SheetModel sheet) {
    final cell = sheet.cells[key];
    if (cell == null) return '';
    return cell.calculatedValue.isNotEmpty ? cell.calculatedValue : cell.value;
  }

  static String _getInsideArgs(String expr) {
    final start = expr.indexOf('(');
    final end = expr.lastIndexOf(')');
    if (start != -1 && end != -1 && end > start) {
      return expr.substring(start + 1, end).trim();
    }
    return '';
  }

  static String _evalSum(String expr, SheetModel sheet) {
    final args = _getInsideArgs(expr);
    final numbers = _resolveNumericRange(args, sheet);
    final sum = numbers.fold<double>(0, (prev, elem) => prev + elem);
    return sum % 1 == 0 ? sum.toInt().toString() : sum.toStringAsFixed(2);
  }

  static String _evalAverage(String expr, SheetModel sheet) {
    final args = _getInsideArgs(expr);
    final numbers = _resolveNumericRange(args, sheet);
    if (numbers.isEmpty) return '#DIV/0!';
    final avg = numbers.fold<double>(0, (prev, elem) => prev + elem) / numbers.length;
    return avg % 1 == 0 ? avg.toInt().toString() : avg.toStringAsFixed(2);
  }

  static String _evalMin(String expr, SheetModel sheet) {
    final args = _getInsideArgs(expr);
    final numbers = _resolveNumericRange(args, sheet);
    if (numbers.isEmpty) return '0';
    final min = numbers.reduce(math.min);
    return min % 1 == 0 ? min.toInt().toString() : min.toString();
  }

  static String _evalMax(String expr, SheetModel sheet) {
    final args = _getInsideArgs(expr);
    final numbers = _resolveNumericRange(args, sheet);
    if (numbers.isEmpty) return '0';
    final max = numbers.reduce(math.max);
    return max % 1 == 0 ? max.toInt().toString() : max.toString();
  }

  static String _evalCount(String expr, SheetModel sheet) {
    final args = _getInsideArgs(expr);
    final numbers = _resolveNumericRange(args, sheet);
    return numbers.length.toString();
  }

  static String _evalCountA(String expr, SheetModel sheet) {
    final args = _getInsideArgs(expr);
    var count = 0;
    if (args.contains(':')) {
      final parts = args.split(':');
      final cells = _getCellsInRange(parts[0].trim().toUpperCase(), parts[1].trim().toUpperCase(), sheet);
      count = cells.where((c) => c.trim().isNotEmpty).length;
    } else {
      final val = _getCellValue(args.toUpperCase(), sheet);
      if (val.trim().isNotEmpty) count = 1;
    }
    return count.toString();
  }

  static String _evalIf(String expr, SheetModel sheet) {
    final inside = _getInsideArgs(expr);
    final parts = inside.split(',');
    if (parts.length < 2) return '#ERROR!';

    final condition = parts[0].trim();
    final trueVal = parts[1].trim();
    final falseVal = parts.length > 2 ? parts[2].trim() : '';

    bool isTrue = false;
    if (condition.contains('=')) {
      final condParts = condition.split('=');
      final left = _resolveValueOrLiteral(condParts[0].trim(), sheet);
      final right = _resolveValueOrLiteral(condParts[1].trim(), sheet);
      isTrue = left == right;
    } else if (condition.contains('>')) {
      final condParts = condition.split('>');
      final left = double.tryParse(_resolveValueOrLiteral(condParts[0].trim(), sheet)) ?? 0;
      final right = double.tryParse(_resolveValueOrLiteral(condParts[1].trim(), sheet)) ?? 0;
      isTrue = left > right;
    } else if (condition.contains('<')) {
      final condParts = condition.split('<');
      final left = double.tryParse(_resolveValueOrLiteral(condParts[0].trim(), sheet)) ?? 0;
      final right = double.tryParse(_resolveValueOrLiteral(condParts[1].trim(), sheet)) ?? 0;
      isTrue = left < right;
    }

    final chosen = isTrue ? trueVal : falseVal;
    return _resolveValueOrLiteral(chosen, sheet);
  }

  static String _resolveValueOrLiteral(String token, SheetModel sheet) {
    var t = token.trim();
    if ((t.startsWith('"') && t.endsWith('"')) || (t.startsWith("'") && t.endsWith("'"))) {
      return t.substring(1, t.length - 1);
    }
    if (RegExp(r'^[A-Z]+[0-9]+$').hasMatch(t.toUpperCase())) {
      return _getCellValue(t.toUpperCase(), sheet);
    }
    return t;
  }

  static String _evalConcat(String expr, SheetModel sheet) {
    final inside = _getInsideArgs(expr);
    final parts = inside.split(',');
    final buffer = StringBuffer();
    for (final p in parts) {
      buffer.write(_resolveValueOrLiteral(p.trim(), sheet));
    }
    return buffer.toString();
  }

  static String _evalLen(String expr, SheetModel sheet) {
    final inside = _getInsideArgs(expr);
    final val = _resolveValueOrLiteral(inside, sheet);
    return val.length.toString();
  }

  static String _evalUpper(String expr, SheetModel sheet) {
    final inside = _getInsideArgs(expr);
    return _resolveValueOrLiteral(inside, sheet).toUpperCase();
  }

  static String _evalLower(String expr, SheetModel sheet) {
    final inside = _getInsideArgs(expr);
    return _resolveValueOrLiteral(inside, sheet).toLowerCase();
  }

  static String _evalTrim(String expr, SheetModel sheet) {
    final inside = _getInsideArgs(expr);
    return _resolveValueOrLiteral(inside, sheet).trim();
  }

  static String _evalRound(String expr, SheetModel sheet) {
    final inside = _getInsideArgs(expr);
    final parts = inside.split(',');
    final numVal = double.tryParse(_resolveValueOrLiteral(parts[0].trim(), sheet)) ?? 0;
    final decimals = parts.length > 1 ? (int.tryParse(parts[1].trim()) ?? 0) : 0;
    return numVal.toStringAsFixed(decimals);
  }

  static String _evalAbs(String expr, SheetModel sheet) {
    final inside = _getInsideArgs(expr);
    final numVal = double.tryParse(_resolveValueOrLiteral(inside, sheet)) ?? 0;
    final absVal = numVal.abs();
    return absVal % 1 == 0 ? absVal.toInt().toString() : absVal.toString();
  }

  static String _evalSimpleArithmetic(String expr, SheetModel sheet) {
    // Replace cell references with values
    final refRegex = RegExp(r'[A-Za-z]+[0-9]+');
    final replaced = expr.replaceAllMapped(refRegex, (match) {
      final key = match.group(0)!.toUpperCase();
      final val = _getCellValue(key, sheet);
      final num = double.tryParse(val) ?? 0;
      return num.toString();
    });

    if (replaced.contains('+')) {
      final p = replaced.split('+');
      final left = double.tryParse(p[0].trim()) ?? 0;
      final right = double.tryParse(p[1].trim()) ?? 0;
      final res = left + right;
      return res % 1 == 0 ? res.toInt().toString() : res.toStringAsFixed(2);
    } else if (replaced.contains('-')) {
      final p = replaced.split('-');
      final left = double.tryParse(p[0].trim()) ?? 0;
      final right = double.tryParse(p[1].trim()) ?? 0;
      final res = left - right;
      return res % 1 == 0 ? res.toInt().toString() : res.toStringAsFixed(2);
    } else if (replaced.contains('*')) {
      final p = replaced.split('*');
      final left = double.tryParse(p[0].trim()) ?? 0;
      final right = double.tryParse(p[1].trim()) ?? 0;
      final res = left * right;
      return res % 1 == 0 ? res.toInt().toString() : res.toStringAsFixed(2);
    } else if (replaced.contains('/')) {
      final p = replaced.split('/');
      final left = double.tryParse(p[0].trim()) ?? 0;
      final right = double.tryParse(p[1].trim()) ?? 0;
      if (right == 0) return '#DIV/0!';
      final res = left / right;
      return res % 1 == 0 ? res.toInt().toString() : res.toStringAsFixed(2);
    }

    return replaced;
  }
}

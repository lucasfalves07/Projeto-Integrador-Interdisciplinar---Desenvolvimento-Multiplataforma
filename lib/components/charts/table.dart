import 'package:flutter/material.dart';

/// Tabela estilizada (equivalente ao <Table>)
class CustomTable extends StatelessWidget {
  final List<TableRow> rows;
  final TableBorder? border;
  final EdgeInsetsGeometry cellPadding;

  const CustomTable({
    super.key,
    required this.rows,
    this.border,
    this.cellPadding = const EdgeInsets.all(12),
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Table(
        border: border ??
            TableBorder(
              horizontalInside: BorderSide(
                color: Theme.of(context).dividerColor,
                width: 1,
              ),
            ),
        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
        children: rows,
      ),
    );
  }
}

/// CabeÃ§alho da tabela (equivalente a <TableHeader>)
class TableHeader extends StatelessWidget {
  final List<String> columns;

  const TableHeader({super.key, required this.columns});

  @override
  Widget build(BuildContext context) {
    return TableRow(
      children: columns
          .map((col) => Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  col,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).hintColor,
                      ),
                ),
              ))
          .toList(),
    );
  }
}

/// Linha da tabela (equivalente a <TableRow>)
class CustomTableRow extends TableRow {
  CustomTableRow({
    required List<Widget> children,
  }) : super(children: children.map((c) => Padding(
        padding: const EdgeInsets.all(12),
        child: c,
      )).toList());
}

/// CÃ©lula (equivalente a <TableCell>)
class TableCellText extends StatelessWidget {
  final String text;
  final TextStyle? style;

  const TableCellText(this.text, {super.key, this.style});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: style ?? Theme.of(context).textTheme.bodyMedium,
    );
  }
}

/// Legenda (equivalente a <TableCaption>)
class TableCaption extends StatelessWidget {
  final String caption;

  const TableCaption({super.key, required this.caption});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Text(
        caption,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).hintColor,
            ),
      ),
    );
  }
}

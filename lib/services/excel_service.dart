import 'package:excel/excel.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:typed_data';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';


class ExcelService {

  static Future<void> generateGeneralAssetsExcel(
      BuildContext context) async {

        try {

    final excel = Excel.createExcel();

// Renomeia a aba padrão
excel.rename('Sheet1', 'Ativos');

// Usa a aba renomeada
final Sheet sheet = excel['Ativos'];

sheet.setColumnWidth(0, 18); // Serial
sheet.setColumnWidth(1, 25); // Modelo
sheet.setColumnWidth(2, 18); // Tipo
sheet.setColumnWidth(3, 15); // Status
sheet.setColumnWidth(4, 30); // Clientes
sheet.setColumnWidth(5, 20); // Última Atualização
sheet.setColumnWidth(6, 15); // Valor Base

sheet.appendRow([
  TextCellValue("VOSTTRO ATIVOS"),
]);

sheet.appendRow([
  TextCellValue(""),
]);

sheet.merge(
  CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0),
  CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: 0),
);

var titleCell =
    sheet.cell(CellIndex.indexByColumnRow(
      columnIndex: 0,
      rowIndex: 0,
    ));

titleCell.cellStyle = CellStyle(
  bold: true,
  fontSize: 18,
  horizontalAlign: HorizontalAlign.Center,
);

    sheet.appendRow([
      TextCellValue("Serial"),
      TextCellValue("Modelo"),
      TextCellValue("Tipo"),
      TextCellValue("Status"),
      TextCellValue("Clientes"),
      TextCellValue("Última Atualização"),
      TextCellValue("Valor Base"),
    ]);

    for (int i = 0; i <= 6; i++) {
  sheet
      .cell(
        CellIndex.indexByColumnRow(
          columnIndex: i,
          rowIndex: 2,
        ),
      )
      .cellStyle = CellStyle(
    bold: true,
    horizontalAlign: HorizontalAlign.Center,
  );
}


  final firestore = FirebaseFirestore.instance;

  final ativosSnapshot =
      await firestore.collection('ativos').get();

  final clientesSnapshot =
      await firestore.collection('clientes').get();

  Map<String,String> clientes = {};
  for (var doc in clientesSnapshot.docs) {
  clientes[doc.id] =
      doc['nome_fantasia'] ?? 'N/A';
}

    for (var doc in ativosSnapshot.docs) {
      final data = doc.data();

      String cliente = "N/A";

      if (data['cliente_atual_id'] != null) {
        cliente =
            clientes[data['cliente_atual_id']]
            ?? "N/A";
      }




      String ultima = "N/A";

      if (data['ultima_atualizacao_status'] != null) {
        ultima = DateFormat(
          'dd/MM/yyyy',
        ).format(
          (data['ultima_atualizacao_status']
                  as Timestamp)
              .toDate(),
        );
      }

      double valorBase =
    (data['valor_base'] ?? 0).toDouble();

      sheet.appendRow([
        TextCellValue(data['serial'] ?? ""),
        TextCellValue(data['modelo'] ?? ""),
        TextCellValue(data['tipo'] ?? ""),
        TextCellValue(
          _formatStatus(
            data['status'] ?? "",
          ),
        ),
        TextCellValue(cliente),
        TextCellValue(ultima),
TextCellValue(
  NumberFormat.currency(
    locale: 'pt_BR',
    symbol: 'R\$',
  ).format(data['valor_base'] ?? 0),
),
      ]);
    }


final String fileName =
    "Epopeia_Ativos_${DateFormat('dd-MM-yyyy_HH-mm').format(DateTime.now())}.xlsx";

final List<int>? fileBytes = excel.save();

if (fileBytes == null) {
  throw Exception(
    "Não foi possível gerar o arquivo Excel.",
  );
}

final Uint8List bytes = Uint8List.fromList(fileBytes);

await Share.shareXFiles(
  [
    XFile.fromData(
      bytes,
      name: fileName,
      mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    ),
  ],
  subject: fileName,
);



} catch(e){

  ScaffoldMessenger.of(context).showSnackBar(

    SnackBar(
content: Text(
        "Erro ao gerar Excel: $e",
      ),
    ),

  );

}

  }


  static String _formatStatus(String status) {
  switch (status) {
    case "estoque":
      return "Estoque";

    case "alugdo":
      return "Alugado";

    case "alugdo_em_manutencao":
      return "Alugado em manutenção";

    case "manutencao":
      return "Manutenção";

    case "estoque_danificado":
      return "Danificado";

    case "substituto":
      return "Substituto";

    default:
      return status;
  }
}

}
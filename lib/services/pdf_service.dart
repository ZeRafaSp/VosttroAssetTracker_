import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';

class PdfService {

  static Future<void> generateGeneralAssetsReport(
      BuildContext context) async {

    final pdf = pw.Document();

    final firestore = FirebaseFirestore.instance;

    try {

      final ativosSnapshot =
          await firestore.collection('ativos').get();

      final clientesSnapshot =
          await firestore.collection('clientes').get();

      Map<String, String> clientes = {};

      for (var doc in clientesSnapshot.docs) {
        clientes[doc.id] =
            doc['nome_fantasia'] ?? 'N/A';
      }

      List<Map<String, dynamic>> ativos = [];

      int estoque = 0;
      int alugado= 0;
      int manutencao = 0;
      int danificados = 0;

      double valorPatrimonial = 0;

      for (var doc in ativosSnapshot.docs) {

        final data = doc.data();

        final status =
            (data['status'] ?? '').toString();

        switch (status) {
          case 'estoque':
            estoque++;
            break;

          case 'Alugado':
            alugado++;
            break;

          case 'manutencao':
            manutencao++;
            break;

          case 'estoque_danificado':
            danificados++;
            break;
        }

        valorPatrimonial +=
            (data['valor_base'] ?? 0)
                .toDouble();

        String clienteAtual = "N/A";

        if (data['cliente_atual_id'] != null) {
          clienteAtual =
              clientes[data['cliente_atual_id']]
                  ?? "N/A";
        }

        String ultimaAtualizacao = "N/A";

        if (data['ultima_atualizacao_status']
            != null) {

          Timestamp ts =
              data['ultima_atualizacao_status'];

          ultimaAtualizacao =
              DateFormat('dd/MM/yyyy')
                  .format(ts.toDate());
        }

        ativos.add({

          'serial':
              data['serial'] ?? '',

          'modelo':
              data['modelo'] ?? '',

          'tipo':
              data['tipo'] ?? '',

          'status':
              _formatStatus(status),

          'cliente':
              clienteAtual,

          'ultima':
              ultimaAtualizacao,

        });
      }

      pdf.addPage(
  pw.MultiPage(
    pageFormat: PdfPageFormat.a4,
    build: (pw.Context context) {
      return [

        pw.Center(
          child: pw.Text(
            'VOSTTRO ATIVOS',
            style: pw.TextStyle(
              fontSize: 24,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ),

        pw.SizedBox(height: 10),

        pw.Center(
          child: pw.Text(
            'RELATÓRIO GERAL DE ATIVOS',
            style: const pw.TextStyle(
              fontSize: 18,
            ),
          ),
        ),

        pw.SizedBox(height: 20),

        pw.Text(
          'Data de emissão: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}',
        ),

        pw.SizedBox(height: 20),

        pw.Text(
          'RESUMO',
          style: pw.TextStyle(
            fontWeight: pw.FontWeight.bold,
            fontSize: 16,
          ),
        ),

        pw.SizedBox(height: 10),

        pw.Text('Total de ativos: ${ativos.length}'),
        pw.Text('Estoque: $estoque'),
        pw.Text('Alugado: $alugado'),
        pw.Text('Manutenção: $manutencao'),
        pw.Text('Danificados: $danificados'),

        pw.SizedBox(height: 10),

        pw.Text(
          'Valor patrimonial: '
          'R\$ ${valorPatrimonial.toStringAsFixed(2)}',
        ),

        pw.SizedBox(height: 25),

        pw.Text(
          'LISTAGEM DOS ATIVOS',
          style: pw.TextStyle(
            fontWeight: pw.FontWeight.bold,
            fontSize: 16,
          ),
        ),

        pw.SizedBox(height: 10),

        pw.TableHelper.fromTextArray(

          headers: [
            'Serial',
            'Modelo',
            'Tipo',
            'Status',
            'Clientes',
            'Última Atualização',
          ],

          data: ativos.map((ativo) {

            return [

              ativo['serial'],

              ativo['modelo'],

              ativo['tipo'],

              ativo['status'],

              ativo['cliente'],

              ativo['ultima'],

            ];

          }).toList(),

        ),

        pw.SizedBox(height: 20),

        pw.Divider(),

        pw.Center(
          child: pw.Text(
            'Relatório gerado automaticamente por Vosttro Asset Tracker',
          ),
        ),

      ];
    },
  ),
);

   await Printing.layoutPdf(
  onLayout: (PdfPageFormat format) async {
    return pdf.save();
  },
); 
}


catch (e) {
  ScaffoldMessenger.of(context).showSnackBar(

    SnackBar(

      content: Text(
        'Erro ao gerar PDF: $e',
      ),

    ),

  );
}

   }


   static String _formatStatus(String status) {
  switch (status) {
    case 'estoque':
      return 'Estoque';

    case 'alugado':
      return 'Alugado';

    case 'manutencao':
      return 'Manutenção';

    case 'estoque_danificado':
      return 'Danificado';

    default:
      return status;
  }
}


}


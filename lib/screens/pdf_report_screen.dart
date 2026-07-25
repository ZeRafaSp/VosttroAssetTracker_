import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:vosttro_asset_tracker/services/pdf_service.dart';
import 'package:vosttro_asset_tracker/services/excel_service.dart';


class PdfReportScreen extends StatefulWidget {
  const PdfReportScreen({super.key});

  @override
  State<PdfReportScreen> createState() => _PdfReportScreenState();
}

class _PdfReportScreenState extends State<PdfReportScreen> {

bool _isGenerating = false;

int totalAtivos = 0;
int estoque = 0;
int alugado = 0;
int alugadoEmManutencao = 0;
int manutencao = 0;
int estoqueDanificado = 0;
int substituto= 0;

double valorPatrimonial = 0;


Future<void> _loadAssetStatistics() async {
  setState(() {
    _isGenerating = true;
  });

  try {
    final ativos = await FirebaseFirestore.instance
        .collection('ativos')
        .get();

    totalAtivos = ativos.docs.length;

    estoque = 0;
    alugado = 0;
    alugadoEmManutencao= 0;
    manutencao = 0;
    estoqueDanificado = 0;
    substituto = 0;

    valorPatrimonial = 0;

    for (var doc in ativos.docs) {
      final data = doc.data();

      final status = data['status'] ?? '';

      final valor =
          (data['valor_base'] ?? 0).toDouble();

      valorPatrimonial += valor;

      switch (status) {
        case 'estoque':
          estoque++;
          break;

        case 'alugado':
          alugado++;
          break;

          case 'alugado_em_manutencao':
          alugadoEmManutencao++;
          break;

        case 'manutencao':
          manutencao++;
          break;

        case 'estoque_danificado':
          estoqueDanificado++;
          break;

          case 'substituto':
          substituto++;
          break;
      }
    }
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          "Erro ao carregar dados: $e",
        ),
      ),
    );
  }

  setState(() {
    _isGenerating = false;
  });
}


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Relatórios PDF"),
      ),

body: SingleChildScrollView(
  child: Padding(
    padding: const EdgeInsets.all(16),

    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,

      children: [

            const Center(
              child: Icon(
                Icons.picture_as_pdf,
                size: 80,
                color: Colors.red,
              ),
            ),

            const SizedBox(height: 20),

            const Center(
              child: Text(
                "VOSTTRO ATIVOS",
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            const SizedBox(height: 10),

            const Center(
              child: Text(
                "Central de Relatórios",
                style: TextStyle(
                  fontSize: 18,
                ),
              ),
            ),

            const SizedBox(height: 30),

            Card(
              elevation: 3,

              child: Padding(
                padding: const EdgeInsets.all(16),

                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,

                  children: [

                    const Text(
                      "Relatório Geral de Ativos",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 10),

                    const Text(
                      "Gera um relatório completo.",
                    ),

                    const SizedBox(height: 30),

                    SizedBox(
                      width: double.infinity,

                      child: 
                            ElevatedButton.icon(
                        icon: const Icon(Icons.picture_as_pdf),

                        label: const Text(
                          "Gerar Relatório",
                        ),

                        onPressed: () async {

                           await _loadAssetStatistics();

                              await PdfService.generateGeneralAssetsReport(
                              context,
                              );

                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),


            const SizedBox(height: 20),

if (totalAtivos > 0)
Card(
  child: Padding(
    padding: const EdgeInsets.all(16),

    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,

      children: [

        const Text(
          "Resumo Atual",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),

        const SizedBox(height: 10),

        Text("Total de ativos: $totalAtivos"),

        Text("Estoque: $estoque"),

        Text("Alugado: $alugado"),

         Text("Alugado em manutenção: $alugadoEmManutencao"),

        Text("Manutenção: $manutencao"),

        Text("Danificados: $estoqueDanificado"),

         Text("Substituto: $substituto"),

        const SizedBox(height: 10),

        Text(
          "Valor patrimonial: R\$ ${valorPatrimonial.toStringAsFixed(2)}",
        ),
      ],
    ),
  ),
),
      
                  const SizedBox(height: 30),


Card(
  elevation: 3,
  child: Padding(
    padding: const EdgeInsets.all(16),

    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,

      children: [

        const Text(
          "Relatório Excel",
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),

        const SizedBox(height: 10),

        const Text(
          "Exporta a lista completa de ativos para Excel.",
        ),

        const SizedBox(height: 20),

        SizedBox(
          width: double.infinity,

          child: ElevatedButton.icon(

            icon: const Icon(Icons.table_chart),

            label: const Text(
              "Gerar Excel",
            ),

            onPressed: () async {

              await ExcelService.generateGeneralAssetsExcel(
                context,
              );

ScaffoldMessenger.of(context).showSnackBar(
  const SnackBar(
    content: Text(
      "Relatório Excel gerado com sucesso!",
    ),
  ),
);
            },

          ),
        ),

      ],
    ),
  ),
),


            const SizedBox(height: 30),

            const Divider(),

            const SizedBox(height: 10),


            const SizedBox(height: 60),

          ],
        ),
      ),
    ),
  );

  }
}
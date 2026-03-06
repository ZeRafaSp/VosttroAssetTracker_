import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart'; 
import 'package:vosttro_asset_tracker/models/client_dropdown_item.dart';


class MovementReportScreen extends StatefulWidget {
  const MovementReportScreen({super.key});

  @override
  State<MovementReportScreen> createState() => _MovementReportScreenState();
}

class _MovementReportScreenState extends State<MovementReportScreen> {
  List<ClientDropdownItem> _allClients = [];
  bool _isLoadingClients = true;

  @override
  void initState() {
    super.initState();
    _fetchAllClients();
  }

  Future<void> _fetchAllClients() async {
    try {
      final querySnapshot =
          await FirebaseFirestore.instance.collection('clientes').get();
      List<ClientDropdownItem> clients = [];
      for (var doc in querySnapshot.docs) {
        final clientName = doc.get('nome_fantasia') as String?;
        if (clientName != null && clientName.isNotEmpty) {
          clients.add(ClientDropdownItem(id: doc.id, name: clientName));
        }
      }
      setState(() {
        _allClients = clients;
        _isLoadingClients = false;
      });
    } catch (e) {
      print('Erro ao carregar todos os clientes para relatório: $e');
      setState(() {
        _isLoadingClients = false;
      });
    }
  }

  DateTime? _timestampToDateTime(Timestamp? timestamp) {
    return timestamp?.toDate();
  }

  Future<String> _getTechnicianName(String? technicianUid) async {
    if (technicianUid == null || technicianUid.isEmpty) {
      return 'Técnico Desconhecido';
    }
    try {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('usuario')
          .doc(technicianUid)
          .get();
      if (userDoc.exists) {
        return userDoc.get('nome') ?? 'Nome Não Encontrado';
      }
      return 'Técnico Não Encontrado';
    } catch (e) {
      print('Erro ao buscar nome do técnico $technicianUid: $e');
      return 'Erro ao Carregar Técnico';
    }
  }

  // Finalizada: Busca o nome na lista carregada em memória
  Future<String> _getClientNameForDisplay(String? clientId) async {
    if (clientId == null || clientId.isEmpty || _isLoadingClients) {
      return 'N/A';
    }
    try {
      final client = _allClients.firstWhere(
        (c) => c.id == clientId,
        orElse: () => ClientDropdownItem(id: '', name: 'Cliente não encontrado'),
      );
      return client.name;
    } catch (e) {
      return 'N/A';
    }
  }

  
                    // ... (dentro de _MovementReportScreenState, apos _getTechnicianName)

  // Funcao para obter o nome de exibicao para origem/destino
  // (Copia do AssetDetailScreen, para estoque/manutencao)
  Future<String> _getDisplayLocationName(String? locationId) async {
    if (locationId == null || locationId.isEmpty) {
      return 'N/A';
    }
    final trimmedLocationId = locationId.trim();

    if (trimmedLocationId == 'estoque' || trimmedLocationId == 'manutencao' || trimmedLocationId == 'desconhecido' || trimmedLocationId == 'estoque_danificado' || trimmedLocationId == 'substituto') {
      return trimmedLocationId.replaceAll('_', ' '); // Retorna o termo como ele é, com _ substituido por espaco
    }
    return await _getClientNameForDisplay(locationId); // Usa a funcao que busca na lista
  }
// ...

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Relatório de Movimentações'),
      ),
      body: _isLoadingClients
          ? const Center(child: CircularProgressIndicator())
          : StreamBuilder<QuerySnapshot>(
              // Exemplo buscando da coleção 'historico' (ajuste conforme seu banco)
              stream: FirebaseFirestore.instance
                  .collection('historico_movimentacoes')
                  .orderBy('data', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) return const Center(child: Text('Erro ao carregar dados'));
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

                final docs = snapshot.data!.docs;

               // ... (dentro de _MovementReportScreenState, dentro do metodo build)

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              final dataMov = _timestampToDateTime(data['data'] as Timestamp?);
              final formattedDate = dataMov != null
                  ? DateFormat('dd/MM/yyyy HH:mm').format(dataMov)
                  : 'Data N/A';

              final String rawTipoMovimentacao = data['tipo_movimentacao'] ?? 'N/A';
              final String tipoMovimentacaoDisplay = rawTipoMovimentacao.replaceAll('_', ' '); // Formata o tipo de movimentacao

              final String? ativoId = data['ativo_id'];
              final String? tecnicoUid = data['tecnico_id'];
              final String? origemId = data['origem'];
              final String? destinoId = data['destino'];
              final String observacao = data['observacao'] ?? ''; // Pega a observacao do historico

                    return Card(
  margin: const EdgeInsets.symmetric(
    horizontal: 16,
    vertical: 8,
  ),
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(12),
  ),
  child: InkWell(
    borderRadius: BorderRadius.circular(12),

    child: Padding(
      padding: const EdgeInsets.all(12),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        tipoMovimentacaoDisplay.toUpperCase(),
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 14,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),

      const SizedBox(height: 6),

            Row(
        children: [
          const Icon(Icons.schedule, size: 16, color: Colors.grey),
          const SizedBox(width: 6),
          Text(
            ('Data: $formattedDate'),
            style: const TextStyle(color: Color.fromARGB(255, 94, 94, 94)),
          ),
        ],
      ),

      const SizedBox(height: 12),
      const Divider(),
      const SizedBox(height: 8),

                      Text('Ativo: ${ativoId ?? 'N/A'}'), // <--- EXIBE O ID DO ATIVO
                     

                      FutureBuilder<String>(
                        future: _getDisplayLocationName(origemId), // <--- USA A NOVA FUNÇÃO
                        builder: (context, snapshot) {
                                    return _buildHistoryRow(
                                      icon: Icons.upload,
                                      label: 'Origem',
                                      value: snapshot.connectionState == ConnectionState.waiting
                                      ? 'Carregando...'
                                    : (snapshot.data ?? 'N/A').replaceAll('_', ' '),
                                      );
                          
                        },
                      ),

// Destino
      FutureBuilder<String>(
        future: _getDisplayLocationName(destinoId),
        builder: (context, snapshot) {
          return _buildHistoryRow(
            icon: Icons.download,
            label: 'Destino',
            value: snapshot.connectionState == ConnectionState.waiting
                ? 'Carregando...'
                : (snapshot.data ?? 'N/A').replaceAll('_', ' '),
          );
        },
      ),

      // Técnico
      FutureBuilder<String>(
        future: _getTechnicianName(tecnicoUid),
        builder: (context, snapshot) {
          return _buildHistoryRow(
            icon: Icons.person,
            label: 'Técnico',
            value: snapshot.connectionState == ConnectionState.waiting
                ? 'Carregando...'
                : (snapshot.data ?? 'Desconhecido'),
          );
        },
      ),


  
                     // Observação
      if ((data['observacao'] as String?)?.isNotEmpty ?? false) ...[
        const SizedBox(height: 2),
        _buildHistoryRow(
          icon: Icons.notes,
          label: 'Detalhes',
          value: (data['observacao'] as String).replaceAll('_', ' '),
        ),
      ],
    ],
                  ),
                ),
              ),);

  


                  },
                );
                
              },
            ),
    );
  }

Widget _buildHistoryRow({
  required IconData icon,
  required String label,
  required String value,
}) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: Colors.grey),
        const SizedBox(width: 8),
        SizedBox(
          width: 80,
          child: Text(
            '$label:',
            style: const TextStyle(fontWeight: FontWeight.bold),
            
          ),
        ),
        Expanded(
          child: Text(value),
        ),
      ],
    ),
  );
}

}
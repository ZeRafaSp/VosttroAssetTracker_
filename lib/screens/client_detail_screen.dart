// lib/screens/client_detail_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart'; // Para formatação de data e números
import 'package:vosttro_asset_tracker/screens/asset_detail_screen.dart'; 
import 'package:vosttro_asset_tracker/screens/edit_client_screen.dart';
import 'package:vosttro_asset_tracker/services/client_service.dart'; 
import 'package:vosttro_asset_tracker/services/auth_service.dart'; 
import 'package:vosttro_asset_tracker/widgets/ui_helpers.dart';

class ClientDetailScreen extends StatefulWidget {
  final DocumentSnapshot clientDocument;

  const ClientDetailScreen({super.key, required this.clientDocument});

  @override
  State<ClientDetailScreen> createState() => _ClientDetailScreenState();
}

class _ClientDetailScreenState extends State<ClientDetailScreen> {
  final ClientService _clientService = ClientService(); // Instancia do ClientService
  final AuthService _authService = AuthService();       // Instancia do AuthService
  bool _isDeleting = false; // Estado para controlar o loading da exclusao

  // Converte o Timestamp do Firestore para DateTime, ou retorna null se nao houver
  DateTime? _timestampToDateTime(Timestamp? timestamp) {
    return timestamp?.toDate();
  }

  // Funcao auxiliar para buscar detalhes de um ativo especifico E SEU DOCUMENTO COMPLETO
  Future<DocumentSnapshot?> _getAssetDocument(String assetSerial) async {
    try {
      DocumentSnapshot assetDoc = await FirebaseFirestore.instance
          .collection('ativos')
          .doc(assetSerial)
          .get();
      return assetDoc.exists ? assetDoc : null;
    } catch (e) {
      print('Erro ao buscar documento do ativo $assetSerial: $e');
      return null;
    }
  }

  // NOVO MÉTODO: Diálogo de confirmação e exclusão do cliente
  Future<void> _confirmDeleteClient() async {
    final String clientId = widget.clientDocument.id;
    final Map<String, dynamic>? clientDataMap = widget.clientDocument.data() as Map<String, dynamic>?;
    final String clientName = clientDataMap?['nome_fantasia'] as String? ?? 'Cliente';
  
    final bool confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar Exclusão do Cliente'),
        content: Text('Tem certeza que deseja excluir o cliente "$clientName"? Esta ação não pode ser desfeita e é irreversível.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false), // Não confirmar
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true), // Confirmar
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Excluir', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    ) ?? false;

    if (confirm) {
      setState(() {
        _isDeleting = true; // Ativa o loading da exclusão
      });

      String? errorMessage = await _clientService.deleteClient(
        clientId: clientId,
        tecnicoUid: _authService.getCurrentUserUid(), // Pega o UID do técnico logado
      );

      if (mounted) {
        setState(() {
          _isDeleting = false; // Desativa o loading
        });

 if (errorMessage == null) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Cliente excluído com sucesso!')),
              );
              Navigator.of(context).pop(); // Volta para a ClientListScreen
            } else {
              // --- NOVO TRATAMENTO DE ERRO AQUI ---
              // A mensagem amigável já vem do ClientService, basta exibi-la.
              // O ClientService já retorna "Não é possível excluir o cliente. Existem ativos alocados a ele."
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Erro: $errorMessage')), // Apenas exibe a mensagem bruta
              );
        }
      }
    }
  }
  
 @override
Widget build(BuildContext context) {
  return StreamBuilder<DocumentSnapshot>(
    stream: FirebaseFirestore.instance
        .collection('clientes')
        .doc(widget.clientDocument.id)
        .snapshots(),
    builder: (context, clientSnapshot) {
      if (clientSnapshot.hasError) {
        return Scaffold(
          appBar: AppBar(title: const Text('Erro')),
          body: Center(
            child: Text('Erro ao carregar cliente: ${clientSnapshot.error}'),
          ),
        );
      }

      if (clientSnapshot.connectionState == ConnectionState.waiting) {
        return const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        );
      }

      if (!clientSnapshot.hasData || !clientSnapshot.data!.exists) {
        return const Scaffold(
          body: Center(child: Text('Cliente não encontrado.')),
        );
      }

      final DocumentSnapshot latestClientDocument = clientSnapshot.data!;
      final Map<String, dynamic> clientData =
          latestClientDocument.data()! as Map<String, dynamic>;

      final List<Map<String, dynamic>> allocatedAssets =
          (clientData['ativos_alocados'] as List?)
                  ?.whereType<Map<String, dynamic>>()
                  .toList() ??
              [];

      return Scaffold(
        appBar: AppBar(
          title: Text(clientData['nome_fantasia'] ?? 'Cliente'),
          actions: [
            IconButton(
              icon: const Icon(Icons.edit),
              tooltip: 'Editar Cliente',
              onPressed: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) =>
                        EditClientScreen(clientDocument: latestClientDocument),
                  ),
                );
              },
            ),
            IconButton(
              icon: _isDeleting
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.delete),
              onPressed: _isDeleting ? null : _confirmDeleteClient,
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // 📌 CARD DE INFORMAÇÕES DO CLIENTE
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDetailRow(
                      'Nome Fantasia',
                      clientData['nome_fantasia'],
                    ),
                    const SizedBox(height: 8),
                    _buildDetailRow(
                      'Endereço',
                      clientData['endereco'],
                    ),
                    const SizedBox(height: 8),
                    _buildDetailRow(
                      'Contato',
                      clientData['contato'],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // 📌 TÍTULO ATIVOS
            Text(
              'Ativos Alocados',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),

            if (allocatedAssets.isEmpty)
              const Text('Nenhum ativo alocado a este cliente.')
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: allocatedAssets.length,
                itemBuilder: (context, index) {
                  final allocatedAsset = allocatedAssets[index];
                  final assetSerial =
                      allocatedAsset['serial_ativo'] ?? 'N/A';

                  final Timestamp? dataInicioTimestamp =
                      allocatedAsset['data_inicio_aluguel'];
                  final String formattedInicio =
                      dataInicioTimestamp != null
                          ? DateFormat('dd/MM/yyyy').format(
                              _timestampToDateTime(dataInicioTimestamp)!,
                            )
                          : 'N/A';

                  final String operacao =
                      allocatedAsset['operacao'] ?? 'N/A';

                  return FutureBuilder<DocumentSnapshot?>(
                    future: _getAssetDocument(assetSerial),
                    builder: (context, assetSnapshot) {
                      if (!assetSnapshot.hasData) {
                        return const ListTile(
                          title: Text('Carregando ativo...'),
                        );
                      }

                      final assetDoc = assetSnapshot.data;
                      if (assetDoc == null || !assetDoc.exists) {
                        return ListTile(
                          title: Text('Ativo $assetSerial não encontrado'),
                        );
                      }

                      final assetData =
                          assetDoc.data() as Map<String, dynamic>;

                      final String status = assetData['status'] ?? 'N/A';
                      final Color statusColor = getStatusColor(status);

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    AssetDetailScreen(assetDocument: assetDoc),
                              ),
                            );
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      assetData['serial'] ?? assetSerial,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: statusColor.withOpacity(0.15),
                                        borderRadius:
                                            BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        status.replaceAll('_', ' '),
                                        style: TextStyle(
                                          color: statusColor,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Tipo: ${assetData['tipo'] ?? 'N/A'}',
                                  style: TextStyle(
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                                 const SizedBox(height: 4),

                                Text(
                                  'Modelo: ${assetData['modelo'] ?? 'N/A'}',
                                  style: TextStyle(
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                                const SizedBox(height: 4),


                                Text(
                                  'Valor: ${assetData['valor_base'] != null 
                           ? NumberFormat.simpleCurrency(locale: 'pt_BR').format(assetData['valor_base']) 
                            : 'N/A'}',
                                  style: TextStyle(
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                                

                                const SizedBox(height: 4),

                                Text(
                                  'Início aluguel: $formattedInicio',
                                  style: TextStyle(
                                    color: Colors.grey.shade700,
                                  ),
                                ),

                                  const SizedBox(height: 4),

                                Text(
                                  'Operação: ${operacao.isEmpty ? 'N/A' : operacao}',
                                     style: TextStyle(
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
          ],
        ),
      );
    },
  );
}

  Widget _buildDetailRow(String label, Object? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(value?.toString() ?? 'N/A'),
          ),
        ],
      ),
    );
  }
}

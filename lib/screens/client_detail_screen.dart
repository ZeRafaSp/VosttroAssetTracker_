// lib/screens/client_detail_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart'; // Para formatação de data e números
import 'package:vosttro_asset_tracker/screens/asset_detail_screen.dart'; // Importe a tela de detalhes do ativo
import 'package:vosttro_asset_tracker/screens/edit_client_screen.dart'; // Importe a EditClientScreen
import 'package:vosttro_asset_tracker/services/client_service.dart'; // <--- Importe o ClientService
import 'package:vosttro_asset_tracker/services/auth_service.dart';   // <--- Importe o AuthService para pegar o UID do técnico


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
    // Usa um StreamBuilder para ouvir as mudancas no documento do cliente em tempo real
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('clientes').doc(widget.clientDocument.id).snapshots(),
      builder: (context, clientSnapshot) {
        if (clientSnapshot.hasError) {
          return Scaffold(
            appBar: AppBar(title: const Text('Erro')),
            body: Center(child: Text('Erro ao carregar cliente: ${clientSnapshot.error}')),
          );
        }

        if (clientSnapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            appBar: AppBar(title: const Text('Carregando...')),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        if (!clientSnapshot.hasData || !clientSnapshot.data!.exists) {
          return Scaffold(
            appBar: AppBar(title: const Text('Cliente Nao Encontrado')),
            body: const Center(child: Text('Cliente nao encontrado.')),
          );
        }

        // Se o cliente existe e tem dados, usa o snapshot mais recente
        final DocumentSnapshot latestClientDocument = clientSnapshot.data!;
        final Map<String, dynamic> clientData = latestClientDocument.data()! as Map<String, dynamic>;
        
        final List<Map<String, dynamic>> allocatedAssets = 
            (clientData['ativos_alocados'] as List?)
                ?.whereType<Map<String, dynamic>>()
                .toList() ?? [];

        return Scaffold(
          appBar: AppBar(
            title: Text(clientData['nome_fantasia'] ?? 'Detalhes do Cliente'),
            actions: [ // Acoes na AppBar
              IconButton( // Botao de Editar
                icon: const Icon(Icons.edit),
                tooltip: 'Editar Cliente',
                onPressed: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => EditClientScreen(clientDocument: latestClientDocument),
                    ),
                  );
                },
              ),
              // --- NOVO: Botao de Excluir Cliente ---
              IconButton( 
                icon: _isDeleting // Mostra um loading se estiver deletando
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.delete), // Icone de lixeira
                onPressed: _isDeleting ? null : _confirmDeleteClient, // Chama o metodo de confirmacao de exclusao
                color: Colors.white, // Cor para o botao de excluir
              ),
              // ------------------------------------
            ],
          ),
          body: Padding(
            padding: const EdgeInsets.all(16.0),
            child: ListView(
              children: [
                _buildDetailRow('Nome Fantasia:', clientData['nome_fantasia']),
                _buildDetailRow('Endereco:', clientData['endereco']),
                _buildDetailRow('Contato:', clientData['contato']),
                const Divider(),
                const SizedBox(height: 10),

                const Text(
                  'Ativos Alocados',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),

                if (allocatedAssets.isEmpty)
                  const Text('Nenhum ativo alocado a este cliente.')
                else
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: allocatedAssets.length,
                    itemBuilder: (context, index) {
                      final Map<String, dynamic> allocatedAsset = allocatedAssets[index];
                      final String assetSerial = allocatedAsset['serial_ativo'] ?? 'N/A';

                      // Formatando a data de inicio do aluguel
                      final Timestamp? dataInicioAluguelTimestamp = allocatedAsset['data_inicio_aluguel'] as Timestamp?;
                      final String formattedDataInicio = dataInicioAluguelTimestamp != null
                          ? DateFormat('dd/MM/yyyy').format(_timestampToDateTime(dataInicioAluguelTimestamp)!)
                          : 'N/A';
                      
                      final String operacao = allocatedAsset['operacao'] ?? 'N/A';


                      return FutureBuilder<DocumentSnapshot?>(
                        future: _getAssetDocument(assetSerial),
                        builder: (context, assetSnapshot) {
                          if (assetSnapshot.connectionState == ConnectionState.waiting) {
                            return const ListTile(
                              title: Text('Carregando detalhes do ativo...'),
                            );
                          }
                          if (assetSnapshot.hasError) {
                            return ListTile(
                              title: Text('Erro ao carregar ativo ${assetSerial}: ${assetSnapshot.error}'),
                            );
                          }
                          
                          final DocumentSnapshot? fullAssetDocument = assetSnapshot.data;
                          final Map<String, dynamic>? assetDetails = fullAssetDocument?.data() as Map<String, dynamic>?;

                          if (fullAssetDocument == null || !fullAssetDocument.exists) {
                            return ListTile(
                              title: Text('Ativo $assetSerial nao encontrado ou removido.'),
                              subtitle: Text('Inicio: $formattedDataInicio, Operacao: ${operacao.isEmpty ? 'N/A' : operacao}'),
                            );
                          }
                          
                          // Extrai o status atualizado do ativo
                          final String currentAssetStatus = assetDetails?['status'] ?? 'N/A';
                          final String statusDisplay = currentAssetStatus.replaceAll('_', ' ');
                          
                          // Extrai o valor base atualizado
                          final double currentAssetValorBase = (assetDetails?['valor_base'] as num?)?.toDouble() ?? 0.0;
                          final String formattedCurrentAssetValorBase = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$').format(currentAssetValorBase);


                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 4.0),
                            child: InkWell(
                              onTap: () async {
                                await Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (context) => AssetDetailScreen(assetDocument: fullAssetDocument),
                                  ),
                                );
                              },
                              child: Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Serial: ${assetDetails?['serial'] ?? assetSerial}', style: const TextStyle(fontWeight: FontWeight.bold)),
                                    Text('Tipo: ${assetDetails?['tipo'] ?? 'N/A'}'),
                                    Text('Modelo: ${assetDetails?['modelo'] ?? 'N/A'}'),
                                    Text('Status: $statusDisplay'),
                                    Text('Valor Base (Ativo): $formattedCurrentAssetValorBase'),
                                    Text('Inicio Aluguel: $formattedDataInicio'),
                                    Text('Operacao: ${operacao.isEmpty ? 'N/A' : operacao}'),
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
          ),
        );
      }
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

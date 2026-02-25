// lib/screens/client_list_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:vosttro_asset_tracker/screens/client_detail_screen.dart'; 
import 'package:vosttro_asset_tracker/screens/add_client_screen.dart'; 
import 'package:vosttro_asset_tracker/widgets/ui_helpers.dart';


class ClientListScreen extends StatefulWidget {
  const ClientListScreen({super.key});

          @override
        State<ClientListScreen> createState() => _ClientListScreenState();
}

    class _ClientListScreenState extends State<ClientListScreen> {
      TextEditingController _searchController = TextEditingController();
      String _currentSearchQuery = '';
      bool _isSearching = false; // Estado para controlar a visibilidade da barra de busca

      @override
      void initState() {
        super.initState();
        _searchController.addListener(_onSearchChanged);
      }

      @override
      void dispose() {
        _searchController.removeListener(_onSearchChanged);
        _searchController.dispose();
        super.dispose();
      }

      void _onSearchChanged() {
        setState(() {
          _currentSearchQuery = _searchController.text;
        });
      }

      // Funcao auxiliar para buscar o nome do cliente (Mantida para consistencia, ja que estava no StatefulWidget anterior)
      Future<String> _getClientName(String? clientId) async {
        if (clientId == null || clientId.isEmpty) {
          return 'N/A';
        }
        try {
          DocumentSnapshot clientDoc = await FirebaseFirestore.instance
              .collection('clientes')
              .doc(clientId)
              .get();
          if (clientDoc.exists) {
            return clientDoc.get('nome_fantasia') ?? 'Nome Desconhecido';
          }
          return 'Cliente Não Encontrado';
        } catch (e) {
          print('Erro ao buscar nome do cliente $clientId: $e');
          return 'Erro ao Carregar Cliente';
        }
      }
    @override
Widget build(BuildContext context) {
  return Scaffold(
    appBar: AppBar(
      title: _isSearching
          ? TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                hintText: 'Buscar por Nome Fantasia...',
                border: InputBorder.none,
                hintStyle: TextStyle(color: Colors.white70),
              ),
              style: const TextStyle(color: Colors.white),
              autofocus: true,
            )
          : const Text('Lista de Clientes'),
      actions: [
        IconButton(
          icon: Icon(_isSearching ? Icons.close : Icons.search),
          onPressed: () {
            setState(() {
              _isSearching = !_isSearching;
              if (!_isSearching) {
                _searchController.clear();
                _currentSearchQuery = '';
              }
            });
          },
        ),
      ],
    ),
    body: StreamBuilder<QuerySnapshot>(
      stream: _buildQuery().snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text('Erro ao carregar clientes: ${snapshot.error}'),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('Nenhum cliente encontrado.'));
        }

        final filteredDocs = _filterDocuments(snapshot.data!.docs);

        return ListView.builder(
          itemCount: filteredDocs.length,
          itemBuilder: (context, index) {
            final document = filteredDocs[index];
            final data = document.data()! as Map<String, dynamic>;

            final int allocatedAssetsCount =
                (data['ativos_alocados'] as List?)?.length ?? 0;

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
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) =>
                          ClientDetailScreen(clientDocument: document),
                    ),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 📌 COLUNA PRINCIPAL
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              data['nome_fantasia'] ?? 'Nome Indisponível',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              data['endereco'] ?? 'Endereço não informado',
                              style: TextStyle(
                                color: Colors.grey.shade700,
                                
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Contato: ${data['contato'] ?? 'N/A'}',
                              style: TextStyle(
                                color: Colors.grey.shade700,
                                
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(width: 12),

                      // 📌 BADGE DE ATIVOS
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .primary
                                  .withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '$allocatedAssetsCount ativos',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.primary,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Icon(
                            Icons.arrow_forward_ios,
                            size: 16,
                            color: Colors.grey,
                          ),
                        ],
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
    floatingActionButton: FloatingActionButton(
      onPressed: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => const AddClientScreen(),
          ),
        );
      },
      tooltip: 'Adicionar Novo Cliente',
      child: const Icon(Icons.add),
    ),
  );
}

             Query<Map<String, dynamic>> _buildQuery() {
        // A query base sempre sera ordenada pelo nome_fantasia para performance
        Query<Map<String, dynamic>> query = FirebaseFirestore.instance
            .collection('clientes')
            .orderBy('nome_fantasia');

        // Se houver uma query de busca, nao adicionamos 'where' na query do Firestore
        // pois isso exigiria um indice especifico que esta problematico.
        // A filtragem por texto sera feita NO CLIENTE (no .map() do StreamBuilder)
        
        return query;
      }

      // Funcao auxiliar para filtrar os documentos no CLIENTE
      List<DocumentSnapshot> _filterDocuments(List<DocumentSnapshot> docs) {
        if (_currentSearchQuery.isEmpty) {
          return docs; // Retorna todos os documentos se nao houver busca
        }

        final searchLower = _currentSearchQuery.toLowerCase();
        return docs.where((doc) {
          final nomeFantasia = doc.get('nome_fantasia') as String? ?? '';
         // final contato = doc.get('contato') as String? ?? ''; // Talvez buscar no contato tambem?
          
          return nomeFantasia.toLowerCase().contains(searchLower);
                // contato.toLowerCase().contains(searchLower); // Busca em nome_fantasia ou contato
        }).toList();
      }
    }
  
 
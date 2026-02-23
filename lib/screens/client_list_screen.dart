// lib/screens/client_list_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:vosttro_asset_tracker/screens/client_detail_screen.dart'; // Importe a tela de detalhes do cliente
import 'package:vosttro_asset_tracker/screens/add_client_screen.dart'; 


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
                    border: InputBorder.none, // Remove a borda padrao
                    hintStyle: TextStyle(color: Colors.white70), // Estilo do placeholder
                  ),
                  style: const TextStyle(color: Colors.white), // Estilo do texto digitado
                  autofocus: true, // Foca no campo de busca ao abrir
                )
              : const Text('Lista de Clientes'), // Titulo padrao
          actions: [
            IconButton( // Botao de busca (lupa) ou fechar (x)
              icon: Icon(_isSearching ? Icons.close : Icons.search),
              onPressed: () {
                setState(() {
                  _isSearching = !_isSearching; // Alterna o estado de busca
                  if (!_isSearching) { // Se parou de buscar, limpa o campo e a query
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
            return Center(child: Text('Erro ao carregar clientes: ${snapshot.error}'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }          
          
          final filteredDocs = _filterDocuments(snapshot.data!.docs);

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('Nenhum cliente encontrado.'));
          }

          return ListView.builder(
                  itemCount: filteredDocs.length,
                  itemBuilder: (context, index) {
                    DocumentSnapshot document = filteredDocs[index]; // Usa os documentos filtrados
                    Map<String, dynamic> data = document.data()! as Map<String, dynamic>;

              // Contar quantos ativos estão alocados (se o campo existir e for uma lista)
              final int allocatedAssetsCount = (data['ativos_alocados'] as List?)?.length ?? 0;

              return Card(
                margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                child: ListTile(
                  title: Text(data['nome_fantasia'] ?? 'Nome Indisponível'),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Endereço: ${data['endereco'] ?? 'N/A'}'),
                      Text('Contato: ${data['contato'] ?? 'N/A'}'),
                      Text('Ativos Alocados: $allocatedAssetsCount'),
                    ],
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios),
                  onTap: () {
                    // Navega para a tela de detalhes do cliente, passando o DocumentSnapshot
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => ClientDetailScreen(clientDocument: document),
                      ),
                    );
                  },
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
            child: const Icon(Icons.add),
            tooltip: 'Adicionar Novo Cliente',
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
  
 
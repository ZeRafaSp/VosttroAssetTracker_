import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:vosttro_asset_tracker/screens/asset_detail_screen.dart'; 
import 'package:vosttro_asset_tracker/screens/add_asset_screen.dart';

class AssetListScreen extends StatefulWidget {
  final String? initialStatusFilter; // NOVO PARAMETRO: filtro de status inicial

  const AssetListScreen({super.key, this.initialStatusFilter}); // Construtor com o novo parametro
      

  @override
  State<AssetListScreen> createState() => _AssetListScreenState();
}

class _AssetListScreenState extends State<AssetListScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _currentSearchQuery = '';
  String? _selectedStatusFilter;
  bool _isSearching = false;

  final Map<String, String> availableStatusesDisplay = {
    'estoque': 'Estoque',
    'alugado': 'Alugado',
    'manutencao': 'Manutenção',
    'alugado_em_manutencao': 'Alugado e em Manutenção',
    'estoque_danificado': 'Estoque (Danificado)',
    'substituto': 'Substituto',
  };

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _selectedStatusFilter = widget.initialStatusFilter; 
    
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _currentSearchQuery = _searchController.text.toLowerCase();
    });
  }

  Future<String> _getClientName(String? clientId) async {
    if (clientId == null || clientId.isEmpty) return 'N/A';
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
                  hintText: 'Buscar por Serial/Modelo...',
                  border: InputBorder.none,
                  hintStyle: TextStyle(color: Colors.white70),
                ),
                style: const TextStyle(color: Colors.white),
                autofocus: true,
              )
            : const Text('Lista de Ativos'),
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
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: DropdownButton<String>(
              value: _selectedStatusFilter,
              hint: const Text('Filtrar Status', style: TextStyle(color: Colors.white70)),
              icon: const Icon(Icons.filter_list, color: Colors.white),
              underline: const SizedBox(),
              onChanged: (String? newValue) {
                setState(() {
                  _selectedStatusFilter = newValue;
                });
              },
              items: [
                const DropdownMenuItem<String>(
                  value: null,
                  child: Text('Todos os Status'),
                ),
                ...availableStatusesDisplay.keys.map((String key) {
                  return DropdownMenuItem<String>(
                    value: key,
                    child: Text(availableStatusesDisplay[key]!),
                  );
                }).toList(),
              ],
            ),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
            stream: _buildQuery().snapshots(), // <--- CHAMA A NOVA FUNÇÃO AQUI
   

        builder: (context, snapshot) {
          if (snapshot.hasError) return Center(child: Text('Erro: ${snapshot.error}'));
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Center(child: Text('Nenhum ativo encontrado.'));

          // Lógica de filtro local (Busca e Status)
          final docs = snapshot.data!.docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final serial = (data['serial'] ?? '').toString().toLowerCase();
            final modelo = (data['modelo'] ?? '').toString().toLowerCase();
            final status = data['status'] as String?;

            final matchesSearch = serial.contains(_currentSearchQuery) || modelo.contains(_currentSearchQuery);
            final matchesStatus = _selectedStatusFilter == null || status == _selectedStatusFilter;

            return matchesSearch && matchesStatus;
          }).toList();

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {

              final document = docs[index]; 
              final data = document.data() as Map<String, dynamic>;

              
              final String? clienteAtualId = data['cliente_atual_id'];
              final String statusDisplay = (data['status'] ?? 'N/A').toString().replaceAll('_', ' ');

              return Card(
                margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                child: ListTile(
                  title: Text(data['serial'] ?? 'Serial Indisponível'),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Tipo: ${data['tipo'] ?? 'N/A'}'),
                      Text('Modelo: ${data['modelo'] ?? 'N/A'}'),
                      Text('Status: $statusDisplay'),
                      if ((data['status'] == 'alugado' || data['status'] == 'alugado_em_manutencao') && clienteAtualId != null)
                        FutureBuilder<String>(
                          future: _getClientName(clienteAtualId),
                          builder: (context, clientSnapshot) {
                            return Text('Cliente: ${clientSnapshot.data ?? 'Carregando...'}');
                          },
                        ),
                    ],
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                         builder: (context) => AssetDetailScreen(assetDocument: document), 
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
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const AddAssetScreen())),
        child: const Icon(Icons.add),
      ),
    );
  }

      // ... (final do método build(BuildContext context) { ... }, dentro de _AssetListScreenState)

      // NOVO: Constrói a query do Firestore dinamicamente com base nos filtros
      Query<Map<String, dynamic>> _buildQuery() {
        Query<Map<String, dynamic>> query = FirebaseFirestore.instance.collection('ativos');

        // 1. Filtro por Status
        if (_selectedStatusFilter != null && _selectedStatusFilter!.isNotEmpty) {
          query = query.where('status', isEqualTo: _selectedStatusFilter);
        }

        // 2. Busca por Serial/Modelo (prefix search)
        // O Firestore só permite where('campo', '>=') e where('campo', '<=') em um único campo.
        // Se quisermos buscar em 'serial' OU 'modelo', teríamos que fazer DUAS QUERIES separadas
        // e mesclar os resultados no cliente, ou usar uma solução de busca externa (ex: Algolia, ElasticSearch).
        // Por simplicidade para esta demonstracao, vamos buscar apenas por 'serial' para evitar
        // complexidade de merges e requisitos de indices compostos complexos para campos diferentes.
        // Se precisar de "modelo" também, considere a solução de "search_tags" no Firestore
        // ou buscar em "serial" E "modelo" em duas consultas e depois combinar.
        if (_currentSearchQuery.isNotEmpty) {
          String searchLower = _currentSearchQuery.toLowerCase();
          query = query
              .where('serial', isGreaterThanOrEqualTo: searchLower)
              .where('serial', isLessThanOrEqualTo: searchLower + '\uf8ff');
              // Nota: .where('serial', isGreaterThanOrEqualTo: searchLower)
              //       .where('serial', isLessThanOrEqualTo: searchLower + '\uf8ff')
              //      funciona para prefix search "case-insensitive" se o campo 'serial' no Firestore
              //      estiver armazenado em lowercase. Para o nosso caso, onde o serial pode ter
              //      letras maiusculas, esta busca funcionara como "case-sensitive".
              //      Para uma busca verdadeiramente case-insensitive, precisariamos de um campo 'serial_lowercase'
              //      no Firestore ou um search index.
        }
        
        // 3. Ordenação
        // As queries que usam 'where' precisam de um 'orderBy' no mesmo campo para ter indice.
        // Se ha filtro por status e busca por serial, a ordenacao deve ser por 'serial'.
        // Se apenas filtrar por status, a ordenacao pode ser por status ou outro campo.
        // Para simplificar e garantir que a query seja valida em Firestore, sempre ordenaremos por 'serial'.
        query = query.orderBy('serial');


        return query;
      }
    } // <--- Fechamento da classe _AssetListScreenState

    // ... (Se houver extensões ListExtension ou StringExtension logo apos a classe)
   



// lib/screens/asset_detail_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:vosttro_asset_tracker/services/asset_service.dart';
import 'package:vosttro_asset_tracker/models/client_dropdown_item.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart'; // <--- Adicione este import para FilteringTextInputFormatter
import 'package:vosttro_asset_tracker/services/auth_service.dart'; // NOVO: Importe o AuthService


class AssetDetailScreen extends StatefulWidget {
  final DocumentSnapshot assetDocument;

  const AssetDetailScreen({super.key, required this.assetDocument});

  @override
  State<AssetDetailScreen> createState() => _AssetDetailScreenState();
}

class _AssetDetailScreenState extends State<AssetDetailScreen> {
  // Estado interno para os dropdowns
  String? _selectedStatus;
  ClientDropdownItem? _selectedClient;
  bool? _selectedTemSeguro; // Novo estado para o dropdown "Tem Seguro"
  String? _selectedSubstituteAssetId; // NOVO: ID do ativo substituto selecionado
  List<ClientDropdownItem> _availableSubstituteAssets = []; // NOVO: Lista de ativos em estoque
        

  TextEditingController _valorBaseController = TextEditingController(); // Novo controller
  TextEditingController _operacaoController = TextEditingController(); // Novo controller
  TextEditingController _observacaoDefeitoController = TextEditingController(); // NOVO CONTROLLER
        

  bool _isLoadingClients = true;
  List<ClientDropdownItem> _availableClients = [];

          final Map<String, String> availableStatusesDisplay = {
            'estoque': 'Estoque',
            'alugado': 'Alugado',
            'manutencao': 'Manutenção',
            'alugado_em_manutencao': 'Alugado e em Manutenção',
            'estoque_danificado': 'Estoque (Danificado)',
            'substituto': 'Substituto', // Adicione o status substituto aqui
          };

  final AssetService _assetService = AssetService();
  final AuthService _authService = AuthService();
  bool _isSaving = false;
  bool _isDeleting = false;

  DateTime? _timestampToDateTime(Timestamp? timestamp) {
    return timestamp?.toDate();
  }

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void dispose() {
    _valorBaseController.dispose();
    _operacaoController.dispose();
    _observacaoDefeitoController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    final Map<String, dynamic> data = widget.assetDocument.data()! as Map<String, dynamic>;
    _selectedStatus = data['status'] as String?;

            // --- NOVO: Validacao do _selectedStatus ---
        // Se o status atual do ativo nao esta na lista de opcoes do dropdown, seta para null
        final Map<String, String> availableStatusesDisplay = {
          'estoque': 'Estoque',
          'alugado': 'Alugado',
          'manutencao': 'Manutenção',
          'alugado_em_manutencao': 'Alugado e em Manutenção',
          'estoque_danificado': 'Estoque (Danificado)',
          'substituto': 'Substituto', // Adicione o status substituto aqui
        };

        if (_selectedStatus != null && !availableStatusesDisplay.containsKey(_selectedStatus!)) {
          _selectedStatus = null; // Seta para nulo se o status nao e uma opcao valida
        }
    _selectedTemSeguro = data['tem_seguro'] as bool?; // Inicializa o "Tem Seguro"
    _observacaoDefeitoController.text = data['observacao_defeito'] as String? ?? '';
    
     if (_selectedStatus == 'alugado_em_manutencao') {
          _selectedSubstituteAssetId = data['substitute_asset_id'] as String?;
        } else {
          _selectedSubstituteAssetId = null; // Garante que e nulo se o status nao for o de manutencao
        }

    // Inicializa o controller do valor base
    // Use NumberFormat para garantir a formatação correta do decimal com vírgula para exibição
    final double initialValorBase = (data['valor_base'] as num?)?.toDouble() ?? 0.0;
    _valorBaseController.text = NumberFormat('###,##0.00', 'pt_BR').format(initialValorBase);

    // Carrega clientes e define o cliente inicial
    await _fetchClientsAndSetInitial(data['cliente_atual_id'] as String?);
    
     // NOVO: Carrega os ativos em estoque para o dropdown de substitutos
        await _fetchAvailableSubstituteAssets(); // Adicione esta chamada com await
        

    // Tenta carregar a 'operacao' se o ativo já estiver alocado a um cliente
    if ((_selectedStatus == 'alugado' || _selectedStatus == 'alugado_em_manutencao') && _selectedClient != null) {
      final String assetSerial = data['serial'] as String;
      final String clientId = _selectedClient!.id;
      await _loadInitialOperacao(assetSerial, clientId);
    }
    setState(() {}); // Força a reconstrução para exibir valores iniciais
  }

  // Novo: Carrega a operação inicial do cliente se o ativo já estiver alocado
  Future<void> _loadInitialOperacao(String assetSerial, String clientId) async {
    try {
      final clientDoc = await FirebaseFirestore.instance.collection('clientes').doc(clientId).get();
      if (clientDoc.exists) {
        final clientData = clientDoc.data() as Map<String, dynamic>?;
        if (clientData != null && clientData.containsKey('ativos_alocados')) {
          final List<Map<String, dynamic>> allocatedAssets = (clientData['ativos_alocados'] as List?)
              ?.whereType<Map<String, dynamic>>()
              .toList() ?? [];
          
          final currentAllocation = allocatedAssets.firstWhereOrNull((item) => item['serial_ativo'] == assetSerial);
          if (currentAllocation != null && currentAllocation.containsKey('operacao')) {
            _operacaoController.text = currentAllocation['operacao'] ?? '';
          }
        }
      }
    } catch (e) {
      print('Erro ao carregar operação inicial: $e');
    }
  }


  Future<void> _fetchClientsAndSetInitial(String? initialClientId) async {
    try {
      final querySnapshot = await FirebaseFirestore.instance.collection('clientes').get();
      List<ClientDropdownItem> clients = [];
      ClientDropdownItem? initialClientItem;

      for (var doc in querySnapshot.docs) {
        final clientName = doc.get('nome_fantasia') as String?;
        if (clientName != null && clientName.isNotEmpty) {
          final clientItem = ClientDropdownItem(id: doc.id, name: clientName);
          clients.add(clientItem);
          if (doc.id == initialClientId) {
            initialClientItem = clientItem;
          }
        }
      }

      setState(() {
        _availableClients = clients;
        if ((_selectedStatus == 'alugado' || _selectedStatus == 'alugado_em_manutencao') && initialClientItem != null) {
          _selectedClient = initialClientItem;
        }
        _isLoadingClients = false;
      });
    } catch (e) {
      print('Erro ao carregar clientes: $e');
      setState(() {
        _isLoadingClients = false;
      });
    }
  }
      // NOVO: Funcao para buscar ativos em estoque para o dropdown de substitutos
Future<void> _fetchAvailableSubstituteAssets() async {
        try {
          // Comeca com ativos em estoque
          QuerySnapshot querySnapshot = await FirebaseFirestore.instance
              .collection('ativos')
              .where('status', isEqualTo: 'estoque')
              .get();
          
          List<ClientDropdownItem> assets = [];
          for (var doc in querySnapshot.docs) {
            // Nao incluir o ativo principal na lista de substitutos
            if (doc.id != widget.assetDocument.id) { 
              assets.add(ClientDropdownItem(id: doc.id, name: '${doc.get('serial')} - ${doc.get('modelo')}'));
            }
          }

          // Se o ativo principal ja tem um substituto designado (e ele nao e o proprio ativo principal)
          // Extrai os dados do documento principal de forma segura
          final Map<String, dynamic>? assetDataMap = widget.assetDocument.data() as Map<String, dynamic>?;
          // NOVO: Acessa 'substitute_asset_id' de forma segura
          final String? currentSubstituteId = assetDataMap?['substitute_asset_id'] as String?;
          if (currentSubstituteId != null && currentSubstituteId.isNotEmpty) {
            // Buscar o substituto atual, se ainda nao estiver na lista (porque seu status nao eh mais 'estoque')
            final currentSubstituteDoc = await FirebaseFirestore.instance.collection('ativos').doc(currentSubstituteId).get();
            if (currentSubstituteDoc.exists && currentSubstituteDoc.id != widget.assetDocument.id) { // Nao pode ser o proprio ativo principal
              // Verifica se ele ja foi adicionado (caso tenha status 'estoque' por algum motivo)
              if (!assets.any((asset) => asset.id == currentSubstituteId)) {
                 assets.add(ClientDropdownItem(id: currentSubstituteDoc.id, name: '${currentSubstituteDoc.get('serial')} - ${currentSubstituteDoc.get('modelo')}'));
              }
            }
          }

          // Opcional: ordenar a lista de ativos substitutos
          assets.sort((a, b) => a.name.compareTo(b.name));

          setState(() {
            _availableSubstituteAssets = assets;
          });
        } catch (e) {
          print('Erro ao carregar ativos substitutos: $e');
        }
      }
  
  // Função auxiliar para buscar o nome do técnico
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

  // Funcao para obter o nome de exibicao para origem/destino
    Future<String> _getDisplayLocationName(String? locationId) async {
      print("DEBUG _getDisplayLocationName: Processando locationId: $locationId");
      if (locationId == null || locationId.isEmpty) {
        print("DEBUG _getDisplayLocationName: locationId é nulo ou vazio. Retornando 'N/A'.");
        return 'N/A';
      }

      // --- ALTERACAO AQUI: Vamos comparar diretamente o valor vindo do Firestore (apos trim) ---
      final trimmedLocationId = locationId.trim();

          if (trimmedLocationId == 'estoque' || trimmedLocationId == 'manutencao' || trimmedLocationId == 'desconhecido' || trimmedLocationId == 'estoque_danificado') {
            print("DEBUG _getDisplayLocationName: locationId '$trimmedLocationId' corresponde a um termo fixo. Retornando.");
            return trimmedLocationId; // Retorna o termo exatamente como ele é, apenas com trim
          }
      // --- FIM DA ALTERACAO ---

      print("DEBUG _getDisplayLocationName: Assumindo que $locationId é um clientId. Chamando _getClientName.");
      return await _getClientName(locationId);
    }

    // Funcao auxiliar para buscar o nome do cliente (MAIS ROBUSTA E COM DEBUG PRINTS)
    Future<String> _getClientName(String? clientId) async {
      print("DEBUG _getClientName: Buscando nome para clientId: $clientId");
      if (clientId == null || clientId == '') { // Use == '' para strings vazias
        print("DEBUG _getClientName: clientId é nulo ou vazio. Retornando 'N/A'.");
        return 'N/A';
      }
      
      // Tenta encontrar o cliente na lista já carregada (para dropdowns, etc.)
      // Esta lista é primariamente para o dropdown e pode nao conter todos os clientes historicos
      final clientItem = _availableClients.firstWhereOrNull((c) => c.id == clientId);
      if (clientItem != null) {
        print("DEBUG _getClientName: Encontrado na lista local: ${clientItem.name}");
        return clientItem.name;
      }

      // Se nao encontrou na lista carregada, faz uma busca direta no Firestore para garantir (principalmente para historico)
      print("DEBUG _getClientName: Nao encontrado na lista local, buscando no Firestore para clientId: $clientId");
      try {
        DocumentSnapshot clientDoc = await FirebaseFirestore.instance
            .collection('clientes')
            .doc(clientId)
            .get();
        if (clientDoc.exists) {
          final clientName = clientDoc.get('nome_fantasia') ?? 'Nome Desconhecido';
          print("DEBUG _getClientName: Encontrado no Firestore: $clientName");
          return clientName;
        }
        print("DEBUG _getClientName: Documento do cliente $clientId nao existe no Firestore.");
        return 'Cliente Nao Encontrado'; // ID de cliente mas documento nao existe
      } catch (e) {
        print('DEBUG _getClientName: Erro ao buscar nome do cliente $clientId para exibicao: $e');
        return 'Erro ao Carregar Cliente';
      }
    }
   
  void _saveChanges() async {
    if (_isSaving) return;

    setState(() {
      _isSaving = true;
    });

    final Map<String, dynamic> oldAssetData = widget.assetDocument.data()! as Map<String, dynamic>;
    final String assetId = widget.assetDocument.id;
    final String oldStatus = oldAssetData['status'] as String;
    final String? oldClientId = oldAssetData['cliente_atual_id'] as String?;

    // --- Coleta dos novos valores ---
    // Converte de "1.234,50" para double 1234.50
    final double newValorBase = double.tryParse(_valorBaseController.text.replaceAll('.', '').replaceAll(',', '.')) ?? 0.0;
    final bool newTemSeguro = _selectedTemSeguro ?? false;
    final String newOperacaoAllocated = _operacaoController.text.trim();
    final String? newObservacaoDefeito = _selectedStatus == 'estoque_danificado' ? _observacaoDefeitoController.text.trim() : null; // NOVO: Coleta condicionalmente
    final String? substituteAssetIdToPass = _selectedStatus == 'alugado_em_manutencao' ? _selectedSubstituteAssetId : null;
            
    print("DEBUG _saveChanges: _selectedSubstituteAssetId antes de chamar o serviço: $_selectedSubstituteAssetId");
    print("DEBUG _saveChanges: substituteAssetIdToPass antes de chamar o serviço: $substituteAssetIdToPass");


    // -------------------------------

    if (_selectedStatus == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, selecione um status para o ativo.')),
      );
      setState(() { _isSaving = false; });
      return;
    }

    if ((_selectedStatus == 'alugado' || _selectedStatus == 'alugado_em_manutencao') && _selectedClient == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Para o status selecionado, um cliente deve ser alocado.')),
      );
      setState(() { _isSaving = false; });
      return;
    }

    String? errorMessage = await _assetService.updateAssetStatus(
      assetId: assetId,
      oldStatus: oldStatus,
      oldClientId: oldClientId,
      newStatus: _selectedStatus!,
      newClient: _selectedClient,
      oldAssetData: oldAssetData,
      newValorBase: newValorBase,           // Novo valor base
      newTemSeguro: newTemSeguro,           // Novo status "Tem Seguro"
      newOperacaoAllocated: newOperacaoAllocated, // Nova operação alocada
      newObservacaoDefeito: newObservacaoDefeito,
      substituteAssetId: _selectedSubstituteAssetId,

    );

    if (mounted) {
      setState(() {
        _isSaving = false;
      });

      if (errorMessage == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Alterações salvas com sucesso!')),
        );
        Navigator.of(context).pop();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao salvar: $errorMessage')),
        );
      }
    }
  }

      // ... (final do metodo _saveChanges())

         // NOVO MÉTODO: Diálogo de confirmação e exclusão
    Future<void> _confirmDelete() async {
      final String assetId = widget.assetDocument.id;
      // CORREÇÃO AQUI: Acessar cliente_atual_id de forma mais segura
      // Verifica se o campo existe e e do tipo String
      final String? clienteAtualId = (widget.assetDocument.data() as Map<String, dynamic>?)?['cliente_atual_id'] as String?;


      final bool confirm = await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Confirmar Exclusão'),
          content: Text('Tem certeza que deseja excluir o ativo "$assetId"? Esta ação não pode ser desfeita.'),
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

        // CORREÇÃO AQUI: Chamar getCurrentUserUid() do _authService
        String? errorMessage = await _assetService.deleteAsset(
          assetId: assetId,
          clienteAtualId: clienteAtualId,
          tecnicoUid: _authService.getCurrentUserUid(), // CHAMA DO _authService AGORA
        );

        if (mounted) {
          setState(() {
            _isDeleting = false; // Desativa o loading
          });

          if (errorMessage == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Ativo excluído com sucesso!')),
            );
            Navigator.of(context).pop(); // Retorna para a lista de ativos
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Erro ao excluir ativo: $errorMessage')),
            );
          }
        }
      }
    }
  



  @override
  Widget build(BuildContext context) {
    final Map<String, dynamic> data = widget.assetDocument.data()! as Map<String, dynamic>;
    final String currentAssetSerial = data['serial'] ?? 'N/A';
    final String currentAssetId = widget.assetDocument.id;

    final Map<String, String> availableStatusesDisplay = {
      'estoque': 'Estoque',
      'alugado': 'Alugado',
      'manutencao': 'Manutenção',
      'alugado_em_manutencao': 'Alugado e em Manutenção',
      'estoque_danificado': 'Estoque (Danificado)',
      'substituto': 'Substituto',
    };

    final Timestamp? ultimaAtualizacaoTimestamp = data['ultima_atualizacao_status'] as Timestamp?;
    final String formattedUltimaAtualizacao = ultimaAtualizacaoTimestamp != null
        ? DateFormat('dd/MM/yyyy HH:mm').format(ultimaAtualizacaoTimestamp.toDate().toLocal())
        : 'N/A';

    return Scaffold(
      appBar: AppBar(
        title: Text(currentAssetSerial),
        actions: [
          IconButton(
            icon: _isSaving
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(Icons.save),
            onPressed: _isSaving ? null : _saveChanges,
          ),
                      // --- NOVO: Botão de Excluir ---
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
              onPressed: _isDeleting ? null : _confirmDelete, // Chama o metodo de confirmacao de exclusao
              color: Colors.white, // Cor para o botão de excluir
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            _buildDetailRow('Serial:', data['serial']),
            _buildDetailRow('Tipo:', data['tipo']),
            _buildDetailRow('Modelo:', data['modelo']),
            // NOVO: TextField para Valor Base
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Row(
                children: [
                  const SizedBox(
                      width: 150,
                      child: Text('Valor Base (Aluguel):', style: TextStyle(fontWeight: FontWeight.bold))),
                  Expanded(
                    child: TextField(
                      controller: _valorBaseController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'^\d*[,]?\d{0,2}')),
                      ],
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        isDense: true,
                        prefixText: 'R\$ ',
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // NOVO: Dropdown para Tem Seguro
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Row(
                children: [
                  const SizedBox(
                      width: 150,
                      child: Text('Tem Seguro:', style: TextStyle(fontWeight: FontWeight.bold))),
                  Expanded(
                    child: DropdownButton<bool>(
                      isExpanded: true,
                      value: _selectedTemSeguro,
                      hint: const Text('Selecionar'),
                      onChanged: (bool? newValue) {
                        setState(() {
                          _selectedTemSeguro = newValue;
                        });
                      },
                      items: const [
                        DropdownMenuItem(value: true, child: Text('Sim')),
                        DropdownMenuItem(value: false, child: Text('Não')),
                      ],
                    ),
                  ),
                ],
              ),
            ),
                          _buildDetailRow(
                  'Status:', 
                  (data['status'] as String? ?? 'N/A').replaceAll('_', ' '),
                  valueStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold,), // Exemplo de estilo
                ),
            _buildDetailRow('Última Atualização:', formattedUltimaAtualizacao),
            const Divider(),

            // Dropdown para Status Atual (para alteração)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Row(
                children: [
                  const SizedBox(
                      width: 150,
                      child: Text('Alterar Status Para:', style: TextStyle(fontWeight: FontWeight.bold))),
                  Expanded(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: _selectedStatus,
                      hint: const Text('Selecione o Status'),
                      onChanged: (String? newValue) {
                        setState(() {
                          _selectedStatus = newValue;
                          // Limpa a operacao e o cliente se o status nao for alugado
                          if (newValue != 'alugado' && newValue != 'alugado_em_manutencao') {
                            _selectedClient = null;
                            _operacaoController.clear();
                          }
                        });
                      },
                      items: availableStatusesDisplay.keys.map<DropdownMenuItem<String>>((String key) {
                        return DropdownMenuItem<String>(
                          value: key,
                          child: Text(availableStatusesDisplay[key]!),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),

            if (_selectedStatus == 'estoque_danificado')
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Row(
                  children: [
                    const SizedBox(
                        width: 150,
                        child: Text('Obs. Defeito:', style: TextStyle(fontWeight: FontWeight.bold))),
                    Expanded(
                      child: TextField(
                        controller: _observacaoDefeitoController,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          isDense: true,
                          hintText: 'Descreva o defeito',
                        ),
                        maxLines: 3, // Permite multiplas linhas
                      ),
                    ),
                  ],
                ),
              ),

            if (_selectedStatus == 'alugado' || _selectedStatus == 'alugado_em_manutencao')
              Column( // Coluna para agrupar Cliente e Operação
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Row(
                      children: [
                        const SizedBox(
                            width: 150,
                            child: Text('Cliente Alocado:', style: TextStyle(fontWeight: FontWeight.bold))),
                        Expanded(
                          child: _isLoadingClients
                              ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                              : DropdownButton<ClientDropdownItem>(
                                  isExpanded: true,
                                  value: _selectedClient,
                                  hint: const Text('Selecionar cliente'),
                                  onChanged: (ClientDropdownItem? newValue) {
                                    setState(() {
                                      _selectedClient = newValue;
                                    });
                                  },
                                  items: _availableClients.map<DropdownMenuItem<ClientDropdownItem>>((ClientDropdownItem client) {
                                    return DropdownMenuItem<ClientDropdownItem>(
                                      value: client,
                                      child: Text(client.name),
                                    );
                                  }).toList(),
                                ),
                        ),
                      ],
                    ),
                  ),
                  // NOVO: TextField para Operação
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Row(
                      children: [
                        const SizedBox(
                            width: 150,
                            child: Text('Operação (Cliente):', style: TextStyle(fontWeight: FontWeight.bold))),
                        Expanded(
                          child: TextField(
                            controller: _operacaoController,
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                              isDense: true,
                              hintText: 'Descrição da Operação',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              if (_selectedStatus == 'alugado_em_manutencao') // <--- Este if deve englobar o Padding
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Row(
                        children: [
                          const SizedBox(
                              width: 150,
                              child: Text('Ativo Substituto:', style: TextStyle(fontWeight: FontWeight.bold))),
                          Expanded(
                            child: DropdownButton<String>( // Dropdown para selecionar o ativo substituto
                              isExpanded: true,
                              value: _selectedSubstituteAssetId,
                              hint: const Text('Selecionar Ativo em Estoque'),
                               onChanged: (String? newValue) {
                                setState(() {
                                  _selectedSubstituteAssetId = newValue; 
                                });
                              },
                              items: _availableSubstituteAssets.map<DropdownMenuItem<String>>((ClientDropdownItem asset) {
                                return DropdownMenuItem<String>(
                                  value: asset.id,
                                  child: Text(asset.name),
                                );
                              }).toList(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  // --- FIM NOVO ---
                ], // <--- FECHAMENTO DA LISTA DE CHILDREN DA COLUMN
              ),// --- FIM NOVO ---
               
             if (!(_selectedStatus == 'alugado' || _selectedStatus == 'alugado_em_manutencao'))
              _buildDetailRow('Cliente Alocado:', 'N/A'),

            const SizedBox(height: 30),
            const Text(
              'Histórico de Movimentações',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),

            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('historico_movimentacoes')
                  .where('ativo_id', isEqualTo: currentAssetId)
                  .orderBy('data', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Erro ao carregar histórico: ${snapshot.error}'));
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('Nenhum histórico de movimentação encontrado.'));
                }

                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    DocumentSnapshot historyDoc = snapshot.data!.docs[index];
                    Map<String, dynamic> historyData = historyDoc.data()! as Map<String, dynamic>;

                    final Timestamp? dataTimestamp = historyData['data'] as Timestamp?;
                    final String formattedDate = dataTimestamp != null
                        ? DateFormat('dd/MM/yyyy HH:mm').format(dataTimestamp.toDate().toLocal())
                        : 'N/A';
                    
                    final String rawTipoMovimentacao = historyData['tipo_movimentacao'] ?? 'N/A';
                    final String tipoMovimentacaoDisplay = rawTipoMovimentacao.replaceAll('_', ' ');

                    final String? tecnicoUid = historyData['tecnico_id'];
                    final String? origemId = historyData['origem'];
                    final String? destinoId = historyData['destino'];

                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 4.0),
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Tipo: $tipoMovimentacaoDisplay', style: const TextStyle(fontWeight: FontWeight.bold)),
                            Text('Data: $formattedDate'),
                            FutureBuilder<String>(
                              future: _getDisplayLocationName(origemId),
                              builder: (context, originSnapshot) {
                                if (originSnapshot.connectionState == ConnectionState.waiting) {
                                  return const Text('Origem: Carregando...');
                                }
                                return Text('Origem: ${(originSnapshot.data ?? 'N/A').replaceAll('_', ' ')}');
                              },
                            ),
                            FutureBuilder<String>(
                              future: _getDisplayLocationName(destinoId),
                              builder: (context, destinySnapshot) {
                                if (destinySnapshot.connectionState == ConnectionState.waiting) {
                                  return const Text('Destino: Carregando...');
                                }
                                return Text('Destino: ${(destinySnapshot.data ?? 'N/A').replaceAll('_', ' ')}');
                              },
                            ),
                            FutureBuilder<String>(
                              future: _getTechnicianName(tecnicoUid),
                              builder: (context, technicianSnapshot) {
                                if (technicianSnapshot.connectionState == ConnectionState.waiting) {
                                  return const Text('Técnico: Carregando...');
                                }
                                if (technicianSnapshot.hasError) {
                                  return Text('Técnico: Erro (${technicianSnapshot.error})');
                                }
                                return Text('Técnico: ${technicianSnapshot.data ?? 'Desconhecido'}');
                              },
                            ),
                            Text('Observação: ${(historyData['observacao'] as String? ?? 'N/A').replaceAll('_', ' ')}'), 
                          ],
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

   Widget _buildDetailRow(String label, Object? value, {TextStyle? valueStyle}) {
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
            child: Text(
                  value?.toString() ?? 'N/A',
                  style: valueStyle,
          ),
          ),
        ],
      ),
    );
  }
}

// A ListExtension permanece aqui por enquanto, pois só é usada neste arquivo.
extension ListExtension<T> on List<T> {
  T? firstWhereOrNull(bool Function(T element) test) {
    for (var element in this) {
      if (test(element)) {
        return element;
      }
    }
    return null;
  }
}

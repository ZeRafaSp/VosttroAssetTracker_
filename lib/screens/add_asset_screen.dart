// lib/screens/add_asset_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart'; // Para formatação de números
import 'package:flutter/services.dart'; // Para FilteringTextInputFormatter
import 'package:vosttro_asset_tracker/models/client_dropdown_item.dart'; // Para ClientDropdownItem
import 'package:vosttro_asset_tracker/services/asset_service.dart'; // Para AssetService
import 'package:vosttro_asset_tracker/services/auth_service.dart'; // Para AuthService (para pegar o UID do tecnico)


class AddAssetScreen extends StatefulWidget {
  const AddAssetScreen({super.key});

  @override
  State<AddAssetScreen> createState() => _AddAssetScreenState();
}

class _AddAssetScreenState extends State<AddAssetScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _serialController = TextEditingController();
  final TextEditingController _tipoController = TextEditingController();
  final TextEditingController _modeloController = TextEditingController();
  final TextEditingController _valorBaseController = TextEditingController();
  final TextEditingController _operacaoController = TextEditingController(); // Para a operacao inicial
  final TextEditingController _observacaoDefeitoController = TextEditingController(); // NOVO CONTROLLER
        

  bool? _selectedTemSeguro;
  String? _selectedStatus;
  ClientDropdownItem? _selectedClient;

  bool _isLoadingClients = true;
  List<ClientDropdownItem> _availableClients = [];

  final AssetService _assetService = AssetService();
  final AuthService _authService = AuthService(); // Para pegar o UID do tecnico
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _fetchClients();
  }

  @override
  void dispose() {
    _serialController.dispose();
    _tipoController.dispose();
    _modeloController.dispose();
    _valorBaseController.dispose();
    _operacaoController.dispose();
    _observacaoDefeitoController.dispose();
    super.dispose();
  }

  Future<void> _fetchClients() async {
    try {
      final querySnapshot = await FirebaseFirestore.instance.collection('clientes').get();
      List<ClientDropdownItem> clients = [];
      for (var doc in querySnapshot.docs) {
        final clientName = doc.get('nome_fantasia') as String?;
        if (clientName != null && clientName.isNotEmpty) {
          clients.add(ClientDropdownItem(id: doc.id, name: clientName));
        }
      }
      setState(() {
        _availableClients = clients;
        _isLoadingClients = false;
      });
    } catch (e) {
      print('Erro ao carregar clientes: $e');
      setState(() {
        _isLoadingClients = false;
      });
    }
  }

  Future<void> _createAsset() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_isSaving) return;

    setState(() {
      _isSaving = true;
    });

    final String serial = _serialController.text.trim();
    final String tipo = _tipoController.text.trim();
    final String modelo = _modeloController.text.trim();
    final double valorBase = double.tryParse(_valorBaseController.text.replaceAll('.', '').replaceAll(',', '.')) ?? 0.0;
    final bool temSeguro = _selectedTemSeguro ?? false;
    final String status = _selectedStatus ?? 'estoque'; // Default para estoque se nao selecionado
    final String operacao = _operacaoController.text.trim();
    final String? observacaoDefeito = (status == 'estoque_danificado') ? _observacaoDefeitoController.text.trim() : null;

    if ((status == 'alugado' || status == 'alugado_em_manutencao') && _selectedClient == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Para o status selecionado, um cliente deve ser alocado.')),
      );
      setState(() { _isSaving = false; });
      return;
    }

    String? errorMessage = await _assetService.createAsset(
      assetId: serial,
      tipo: tipo,
      modelo: modelo,
      valorBase: valorBase,
      temSeguro: temSeguro,
      status: status,
      cliente: _selectedClient,
      operacao: operacao,
      observacaoDefeito: observacaoDefeito,
      tecnicoUid: _authService.getCurrentUserUid(), // Passa o UID do tecnico logado
    );

    if (mounted) {
      setState(() {
        _isSaving = false;
      });

      if (errorMessage == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ativo criado com sucesso!')),
        );
        Navigator.of(context).pop(); // Volta para a tela anterior (AssetListScreen ou HomeScreen)
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao criar ativo: $errorMessage')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final Map<String, String> availableStatusesDisplay = {
      'estoque': 'Estoque',
      'alugado': 'Alugado',
      'manutencao': 'Manutenção',
      'estoque_danificado': 'Estoque(Danificado)'
      
    };

    return Scaffold(
      appBar: AppBar(
        title: const Text('Adicionar Novo Ativo'),
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
            onPressed: _isSaving ? null : _createAsset,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _serialController,
                decoration: const InputDecoration(
                  labelText: 'Número de Série',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor, insira o número de série.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16.0),
              TextFormField(
                controller: _tipoController,
                decoration: const InputDecoration(
                  labelText: 'Tipo (ex: scanner, desktop)',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor, insira o tipo do equipamento.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16.0),
              TextFormField(
                controller: _modeloController,
                decoration: const InputDecoration(
                  labelText: 'Modelo (ex: Kodak i2800)',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor, insira o modelo.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16.0),
              // TextField para Valor Base
              TextFormField(
                controller: _valorBaseController,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*[,]?\d{0,2}')),
                ],
                decoration: const InputDecoration(
                  labelText: 'Valor Base (Aluguel)',
                  border: OutlineInputBorder(),
                  prefixText: 'R\$ ',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor, insira o valor base.';
                  }
                  if (double.tryParse(value.replaceAll('.', '').replaceAll(',', '.')) == null) {
                    return 'Valor inválido.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16.0),
              // Dropdown para Tem Seguro
              DropdownButtonFormField<bool>(
                value: _selectedTemSeguro,
                decoration: const InputDecoration(
                  labelText: 'Tem Seguro?',
                  border: OutlineInputBorder(),
                ),
                hint: const Text('Selecionar'),
                onChanged: (bool? newValue) {
                  setState(() {
                    _selectedTemSeguro = newValue;
                  });
                },
                validator: (value) {
                  if (value == null) {
                    return 'Por favor, selecione uma opção.';
                  }
                  return null;
                },
                items: const [
                  DropdownMenuItem(value: true, child: Text('Sim')),
                  DropdownMenuItem(value: false, child: Text('Não')),
                ],
              ),
              const SizedBox(height: 16.0),
              // Dropdown para Status
              DropdownButtonFormField<String>(
                value: _selectedStatus,
                decoration: const InputDecoration(
                  labelText: 'Status Inicial',
                  border: OutlineInputBorder(),
                ),
                hint: const Text('Selecione o Status Inicial'),
                onChanged: (String? newValue) {
                  setState(() {
                    _selectedStatus = newValue;
                    if (newValue != 'alugado' && newValue != 'alugado_em_manutencao') {
                      _selectedClient = null;
                      _operacaoController.clear();
                    }
                  });
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor, selecione o status inicial.';
                  }
                  return null;
                },
                items: availableStatusesDisplay.keys.map<DropdownMenuItem<String>>((String key) {
                  return DropdownMenuItem<String>(
                    value: key,
                    child: Text(availableStatusesDisplay[key]!),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16.0),

              // NOVO: Campo de Observacao de Defeito (aparece apenas se status for "Estoque (Danificado)")
            if (_selectedStatus == 'estoque_danificado')
              Column(
                children: [
                  TextFormField(
                    controller: _observacaoDefeitoController,
                    decoration: const InputDecoration(
                      labelText: 'Observação do Defeito',
                      border: OutlineInputBorder(),
                      isDense: true,
                      hintText: 'Descreva o defeito do ativo em estoque.',
                    ),
                    maxLines: 3, // Permite multiplas linhas
                  ),
                  const SizedBox(height: 16.0),
                ],
              ),
              
              // Dropdown para Cliente (visível e habilitado apenas para status específicos)
              if (_selectedStatus == 'alugado' || _selectedStatus == 'alugado_em_manutencao')
                _isLoadingClients
                    ? const Center(child: CircularProgressIndicator())
                    : DropdownButtonFormField<ClientDropdownItem>(
                        value: _selectedClient,
                        decoration: const InputDecoration(
                          labelText: 'Cliente Inicial (se alugado)',
                          border: OutlineInputBorder(),
                        ),
                        hint: const Text('Selecionar cliente'),
                        onChanged: (ClientDropdownItem? newValue) {
                          setState(() {
                            _selectedClient = newValue;
                          });
                        },
                        validator: (value) {
                          if ((_selectedStatus == 'alugado' || _selectedStatus == 'alugado_em_manutencao') && value == null) {
                            return 'Por favor, selecione um cliente.';
                          }
                          return null;
                        },
                        items: _availableClients.map<DropdownMenuItem<ClientDropdownItem>>((ClientDropdownItem client) {
                          return DropdownMenuItem<ClientDropdownItem>(
                            value: client,
                            child: Text(client.name),
                          );
                        }).toList(),
                      ),
              const SizedBox(height: 16.0),
              // TextField para Operação (visível e habilitado apenas para status específicos)
              if (_selectedStatus == 'alugado' || _selectedStatus == 'alugado_em_manutencao')
                TextFormField(
                  controller: _operacaoController,
                  decoration: const InputDecoration(
                    labelText: 'Operação (Cliente)',
                    border: OutlineInputBorder(),
                    hintText: 'Descrição da Operação Inicial',
                  ),
                ),
              if (_selectedStatus == 'alugado' || _selectedStatus == 'alugado_em_manutencao')
                const SizedBox(height: 16.0),

              ElevatedButton(
                onPressed: _isSaving ? null : _createAsset,
                child: _isSaving
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Adicionar Ativo'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

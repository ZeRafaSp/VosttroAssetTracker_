// lib/screens/edit_client_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:vosttro_asset_tracker/services/client_service.dart'; // Importe o ClientService
import 'package:vosttro_asset_tracker/services/auth_service.dart';   // Importe o AuthService para pegar o UID do técnico

class EditClientScreen extends StatefulWidget {
  final DocumentSnapshot clientDocument; // Documento do cliente a ser editado

  const EditClientScreen({super.key, required this.clientDocument});

  @override
  State<EditClientScreen> createState() => _EditClientScreenState();
}

class _EditClientScreenState extends State<EditClientScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _nomeFantasiaController = TextEditingController();
  final TextEditingController _enderecoController = TextEditingController();
  final TextEditingController _contatoController = TextEditingController();

  final ClientService _clientService = ClientService();
  final AuthService _authService = AuthService(); // Instancia do AuthService
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    // Preenche os controladores com os dados existentes do cliente
    final clientData = widget.clientDocument.data()! as Map<String, dynamic>;
    _nomeFantasiaController.text = clientData['nome_fantasia'] ?? '';
    _enderecoController.text = clientData['endereco'] ?? '';
    _contatoController.text = clientData['contato'] ?? '';
  }

  @override
  void dispose() {
    _nomeFantasiaController.dispose();
    _enderecoController.dispose();
    _contatoController.dispose();
    super.dispose();
  }

  Future<void> _updateClient() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_isSaving) return;

    setState(() {
      _isSaving = true;
    });

    final String clientId = widget.clientDocument.id; // ID do cliente atual
    final String nomeFantasia = _nomeFantasiaController.text.trim();
    final String endereco = _enderecoController.text.trim();
    final String contato = _contatoController.text.trim();
    final String? tecnicoUid = _authService.getCurrentUserUid();

    String? errorMessage = await _clientService.updateClient(
      clientId: clientId,
      nomeFantasia: nomeFantasia,
      endereco: endereco,
      contato: contato,
      tecnicoUid: tecnicoUid,
    );

    if (mounted) {
      setState(() {
        _isSaving = false;
      });

      if (errorMessage == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cliente atualizado com sucesso!')),
        );
        Navigator.of(context).pop(); // Volta para a ClientDetailScreen
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao atualizar cliente: $errorMessage')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Editar Cliente'),
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
            onPressed: _isSaving ? null : _updateClient,
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
                controller: _nomeFantasiaController,
                decoration: const InputDecoration(
                  labelText: 'Nome Fantasia',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor, insira o nome fantasia do cliente.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16.0),
              TextFormField(
                controller: _enderecoController,
                decoration: const InputDecoration(
                  labelText: 'Endereço',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor, insira o endereço do cliente.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16.0),
              TextFormField(
                controller: _contatoController,
                decoration: const InputDecoration(
                  labelText: 'Contato',
                  border: OutlineInputBorder(),
                ),
                // Contato nao é obrigatorio, entao sem validator aqui
              ),
              const SizedBox(height: 24.0),
              ElevatedButton(
                onPressed: _isSaving ? null : _updateClient,
                child: _isSaving
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Salvar Alterações'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

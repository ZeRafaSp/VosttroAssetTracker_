    // lib/screens/add_client_screen.dart

    import 'package:flutter/material.dart';
    import 'package:vosttro_asset_tracker/services/client_service.dart'; // Importe o ClientService
    import 'package:vosttro_asset_tracker/services/auth_service.dart';   // Importe o AuthService para pegar o UID do tecnico

    class AddClientScreen extends StatefulWidget {
      const AddClientScreen({super.key});

      @override
      State<AddClientScreen> createState() => _AddClientScreenState();
    }

    class _AddClientScreenState extends State<AddClientScreen> {
      final _formKey = GlobalKey<FormState>();

      final TextEditingController _nomeFantasiaController = TextEditingController();
      final TextEditingController _enderecoController = TextEditingController();
      final TextEditingController _contatoController = TextEditingController();

      final ClientService _clientService = ClientService();
      final AuthService _authService = AuthService(); // Instancia do AuthService
      bool _isSaving = false;

      @override
      void dispose() {
        _nomeFantasiaController.dispose();
        _enderecoController.dispose();
        _contatoController.dispose();
        super.dispose();
      }

      Future<void> _createClient() async {
        if (!_formKey.currentState!.validate()) {
          return;
        }

        if (_isSaving) return;

        setState(() {
          _isSaving = true;
        });

        final String nomeFantasia = _nomeFantasiaController.text.trim();
        final String endereco = _enderecoController.text.trim();
        final String contato = _contatoController.text.trim();
        final String? tecnicoUid = _authService.getCurrentUserUid();

        String? errorMessage = await _clientService.createClient(
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
              const SnackBar(content: Text('Cliente criado com sucesso!')),
            );
            Navigator.of(context).pop(); // Volta para a tela anterior (ClientListScreen)
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Erro ao criar cliente: $errorMessage')),
            );
          }
        }
      }



      @override
      Widget build(BuildContext context) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Adicionar Novo Cliente'),
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
                onPressed: _isSaving ? null : _createClient,
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
                  ),
                  const SizedBox(height: 24.0),
                  ElevatedButton(
                    onPressed: _isSaving ? null : _createClient,
                    child: _isSaving
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text('Salvar Cliente'),
                  ),
                ],
              ),
            ),
          ),
        );
      }
    }


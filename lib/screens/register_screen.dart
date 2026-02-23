import 'package:flutter/material.dart';
import 'package:vosttro_asset_tracker/services/auth_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  final AuthService _authService = AuthService();
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // Função auxiliar para validar o formato do e-mail
  bool _isValidEmail(String email) {
    // Esta expressão regular verifica se o e-mail tem um formato geral válido,
    // incluindo um '@', um domínio com pelo menos um ponto e um TLD de 2 ou mais caracteres.
    // É uma validação comum para aplicativos.
    return RegExp(r"^[a-zA-Z0-9.a-zA-Z0-9.!#$%&'*+-/=?^_`{|}~]+@[a-zA-Z0-9]+\.[a-zA-Z]+")
        .hasMatch(email);
  }

  Future<void> _register() async {
    setState(() {
      _isLoading = true;
    });

    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    if (name.isEmpty || email.isEmpty || password.isEmpty || confirmPassword.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, preencha todos os campos.')),
      );
      setState(() {
        _isLoading = false;
      });
      return;
    }

    if (!_isValidEmail(email)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, insira um e-mail válido.')),
      );
      setState(() {
        _isLoading = false;
      });
      return;
    }

    if (password != confirmPassword) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('As senhas não coincidem.')),
      );
      setState(() {
        _isLoading = false;
      });
      return;
    }

    // Chamada do serviço para registro e criação de perfil. Role padrão 'admin'
    String? errorMessage = await _authService.signUp(email, password, name, "", 'admin'); 
    
    if (mounted) {
      setState(() {
        _isLoading = false;
      });

      if (errorMessage == null) {
        print('Registro bem-sucedido!');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Registro realizado com sucesso!')),
        );
        Navigator.of(context).pop(); // Volta para a tela de login
      } else {
              String displayMessage = 'Erro ao registrar: $errorMessage'; // Mensagem padrao
             // --- VERIFICACAO DO CODIGO DE ERRO ESPECIFICO DO FIREBASE AUTH ---
              switch (errorMessage) { // <--- AGORA USAMOS switch PARA COMPARAR O CODE
                case 'email-already-in-use':
                  displayMessage = 'Este e-mail já está em uso. Por favor, use outro e-mail.';
                  break;
                case 'weak-password':
                  displayMessage = 'A senha fornecida é muito fraca. Por favor, use uma senha mais forte.';
                  break;
                case 'invalid-email':
                  displayMessage = 'O formato do e-mail é inválido. Por favor, verifique.';
                  break;
                case 'operation-not-allowed': // Exemplo: email/password nao habilitado
                  displayMessage = 'Operação não permitida. Verifique as configurações de autenticação.';
                  break;
                default: // Para outros erros nao mapeados
                  displayMessage = 'Erro ao registrar: $errorMessage'; // Exibe o codigo do erro
                  break;
              }

              // --- FIM VERIFICACAO ---

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(displayMessage)),
              );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Registro')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Nome do Técnico',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.text,
            ),
            const SizedBox(height: 16.0),
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'E-mail',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 16.0),
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(
                labelText: 'Senha',
                border: OutlineInputBorder(),
              ),
              obscureText: true,
            ),
            const SizedBox(height: 16.0),
            TextField(
              controller: _confirmPasswordController,
              decoration: const InputDecoration(
                labelText: 'Confirmar Senha',
                border: OutlineInputBorder(),
              ),
              obscureText: true,
            ),
            const SizedBox(height: 24.0),
            _isLoading
                ? const CircularProgressIndicator()
                : ElevatedButton(
                    onPressed: _register,
                    child: const Text('Registrar'),
                  ),
            const SizedBox(height: 16.0),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Já tem uma conta? Faça login'),
            ),
          ],
        ),
      ),
    );
  }
}

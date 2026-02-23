    import 'package:flutter/material.dart';
    import 'package:vosttro_asset_tracker/services/auth_service.dart'; // <--- Adicione este import
    import 'package:vosttro_asset_tracker/screens/register_screen.dart'; // <--- Certifique-se que este import está aqui
    // Remova a RegisterScreen temporária daqui se ainda estiver no seu arquivo login_screen.dart

    class LoginScreen extends StatefulWidget {
      const LoginScreen({super.key});

      @override
      State<LoginScreen> createState() => _LoginScreenState();
    }

    class _LoginScreenState extends State<LoginScreen> {
      final TextEditingController _emailController = TextEditingController();
      final TextEditingController _passwordController = TextEditingController();
      final AuthService _authService = AuthService(); // <--- Instância do serviço de autenticação
      bool _isLoading = false; // Estado para controlar o loading

      @override
      void dispose() {
        _emailController.dispose();
        _passwordController.dispose();
        super.dispose();
      }

      Future<void> _login() async { // <--- Função assíncrona
        setState(() {
          _isLoading = true; // Ativa o loading
        });

        final email = _emailController.text.trim();
        final password = _passwordController.text.trim();

        if (email.isEmpty || password.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Por favor, preencha todos os campos.')),
          );
          setState(() {
            _isLoading = false; // Desativa o loading
          });
          return;
        }

        String? errorMessage = await _authService.signIn(email, password); // <--- Chama o serviço
        
        if (mounted) { // Verifica se o widget ainda está montado antes de chamar setState
          setState(() {
            _isLoading = false; // Desativa o loading
          });

          if (errorMessage == null) {
            // Login bem-sucedido. O stream de authStateChanges no main.dart vai lidar com a navegação.
            print('Login bem-sucedido!');
          } else {
            // Login falhou
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Erro ao fazer login: $errorMessage')),
            );
          }
        }
      }

      void _goToRegister() {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (context) => const RegisterScreen()),
        );
      }

      @override
      Widget build(BuildContext context) {
        return Scaffold(
          appBar: AppBar(title: const Text('Login')),
          body: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
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
                const SizedBox(height: 24.0),
                _isLoading // <--- Mostra um indicador de progresso se estiver carregando
                    ? const CircularProgressIndicator()
                    : ElevatedButton(
                        onPressed: _login,
                        child: const Text('Entrar'),
                      ),
                const SizedBox(height: 16.0),
                TextButton(
                  onPressed: _goToRegister,
                  child: const Text('Não tem uma conta? Registre-se'),
                ),
              ],
            ),
          ),
        );
      }
    }


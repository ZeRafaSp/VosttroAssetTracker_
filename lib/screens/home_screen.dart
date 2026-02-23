// lib/screens/home_screen.dart

        import 'package:flutter/material.dart';
        import 'package:cloud_firestore/cloud_firestore.dart'; // <--- Adicione este import
        import 'package:vosttro_asset_tracker/services/auth_service.dart';
        import 'package:vosttro_asset_tracker/screens/asset_list_screen.dart';
        import 'package:vosttro_asset_tracker/screens/client_list_screen.dart';
        import 'package:vosttro_asset_tracker/screens/add_asset_screen.dart';
        import 'package:vosttro_asset_tracker/screens/add_client_screen.dart'; // <--- Adicione este import
        import 'package:vosttro_asset_tracker/services/auth_service.dart'; // NOVO: Importe o AuthService

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
        State<HomeScreen> createState() => _HomeScreenState();
      
}

 class _HomeScreenState extends State<HomeScreen> {
          final AuthService _authService = AuthService(); // Instancia do AuthService


@override
Widget build(BuildContext context) {
  return Scaffold(
    backgroundColor: Colors.grey[50],
   appBar: AppBar(
title: const Text.rich(
  TextSpan(
    children: [
      TextSpan(
        text: 'Vosttro ',
        style: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
      TextSpan(
        text: 'asset tracker',
        style: TextStyle(
          fontSize: 19,
          fontWeight: FontWeight.w300,
          color: Colors.white,
        ),
      ),
    ],
  ),
),

  backgroundColor: Colors.blue[900], // 🔵 AppBar azul
  foregroundColor: Colors.white,     // ícones brancos
  elevation: 0,
  actions: [
    IconButton(
      icon: const Icon(Icons.logout),
      onPressed: () async {
        await _authService.signOut();
      },
    ),
  ],
),
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        
        children: [
       // HEADER DE BOAS-VINDAS (BRANCO)
Container(
  width: double.infinity,
  padding: const EdgeInsets.all(20),
  decoration: BoxDecoration(
    color: Colors.white, // fundo branco
    borderRadius: BorderRadius.circular(16),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(0.05),
        blurRadius: 10,
        offset: const Offset(0, 4),
      ),
    ],
  ),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      const Text(
        'Bem-vindo ao seu sistema de rastreamento de ativos!',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Colors.black87,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
      const SizedBox(height: 10),

      StreamBuilder(
        stream: _authService.authStateChanges,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.active) {
            final user = snapshot.data;
            if (user != null) {
              return Text(
                'Logado como: ${user.email}',
                style: const TextStyle(
                  color: Colors.black54,
                  fontSize: 14,
                ),
              );
            }
          }
          return const Text(
            'Nenhum usuário logado',
            style: TextStyle(color: Colors.black54),
          );
        },
      ),
    ],
  ),
),

          const SizedBox(height: 25),
          const Text(
            'Dashboard de Ativos',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 15),

          // DASHBOARD
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('ativos').snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              int total = snapshot.data?.docs.length ?? 0;
              int estoque = 0, alugado = 0, manutencao = 0, alugadoManut = 0; 
              int estoqueDanificado = 0;

              for (var doc in snapshot.data?.docs ?? []) {
                final status = doc.get('status') ?? '';
                if (status == 'estoque') estoque++;
                else if (status == 'alugado') alugado++;
                else if (status == 'manutencao') manutencao++;
                else if (status == 'alugado_em_manutencao') alugadoManut++;
                else if (status == 'estoque_danificado') estoqueDanificado++;
              }

                return GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2, // Este parametro e obrigatorio para GridView.count
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.3,
                  
                    children: [
                      
                          _buildStatCard(context, 'Total', total, Icons.inventory_2, Theme.of(context).primaryColor, null), // NOVO: null para o card Total
                          _buildStatCard(context, 'Alugados', alugado, Icons.assignment_turned_in_rounded, Colors.orange.shade700, 'alugado'), // NOVO: 'alugado'
                          _buildStatCard(context, 'Estoque', estoque, Icons.home_work_rounded, Colors.green.shade700, 'estoque'), // NOVO: 'estoque'
                          _buildStatCard(context, 'Estoque/Danif.', estoqueDanificado, Icons.broken_image_rounded, const Color.fromARGB(255, 168, 75, 96), 'estoque_danificado'), // NOVO: 'estoque_danificado' 
                          _buildStatCard(context, 'Manutenção', manutencao, Icons.build_circle_rounded, Colors.red.shade700, 'manutencao'), // NOVO: 'manutencao'
                          _buildStatCard(context, 'Alugado/Manut.', alugadoManut, Icons.sync_problem_rounded, Colors.purple.shade700, 'alugado_em_manutencao'), // NOVO: 'alugado_em_manutencao'
                         
                        ],
                      );
            },
          ),

          const SizedBox(height: 30),
          const Text(
            'Ações Rápidas',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 15),

          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _buildActionButton(context, 'Ativos', const AssetListScreen(), Icons.list_alt),
              _buildActionButton(context, 'Clientes', const ClientListScreen(), Icons.people_outline),
              _buildActionButton(context, '+ Ativo', const AddAssetScreen(), Icons.add_box),
              _buildActionButton(context, '+ Cliente', const AddClientScreen(), Icons.person_add_alt),
            ],
          ),
          const SizedBox(height: 30),
        ],
      ),
    ),
  );
}

// CARD DO DASHBOARD
          Widget _buildStatCard(BuildContext context, String title, int count, IconData icon, Color color, String? statusToFilter) { // NOVO: statusToFilter
            return InkWell( // Torna o card clicavel
              onTap: () {
               
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => AssetListScreen(initialStatusFilter: statusToFilter), // Passa o filtro
                    ),
                  );
                }
              ,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border(left: BorderSide(color: color, width: 5)), // Detalhe lateral colorido
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(icon, color: color, size: 24),
                        const SizedBox(width: 8),
                      
                          Text(
                            title,
                            style: TextStyle(fontSize: 14, color: Colors.grey[700], fontWeight: FontWeight.w500),
                            //overflow: TextOverflow.ellipsis,
                            maxLines: 2,
                            textAlign: TextAlign.center,
                          ),
                        
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(count.toString(), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            );
          }
// BOTÃO DE AÇÃO
Widget _buildActionButton(
  BuildContext context,
  String title,
  Widget screen,
  IconData icon,
) {
  return SizedBox(
    width: (MediaQuery.of(context).size.width / 2) - 25,
    child: FilledButton.tonal(
      style: FilledButton.styleFrom(
        backgroundColor: const Color.fromARGB(255, 228, 234, 238),      // 🔵 fundo azul claro

        overlayColor: Colors.blue.withOpacity(0.15), // 🔵 efeito de toque
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      onPressed: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => screen),
        );
      },
      child: Column(
        children: [
            Icon(icon, size: 28, color: Colors.grey[800]),
            const SizedBox(height: 6),
            Text(title, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[800])), 
          ],
      ),
    ),
  );
}
}
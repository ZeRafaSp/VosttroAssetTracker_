// lib/services/client_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Para obter o UID do tecnico

class ClientService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance; // Para pegar o UID do tecnico logado

  Future<String?> createClient({
    required String nomeFantasia,
    required String endereco,
    required String contato,
    String? tecnicoUid, // UID do tecnico que está criando o cliente
  }) async {
    if (tecnicoUid == null) {
      return "Usuário não autenticado.";
    }

    // Verifica se já existe um cliente com o mesmo nome fantasia para evitar duplicatas
    final existingClient = await _firestore.collection('clientes')
        .where('nome_fantasia', isEqualTo: nomeFantasia)
        .limit(1)
        .get();

    if (existingClient.docs.isNotEmpty) {
      return "Já existe um cliente com este nome fantasia.";
    }

    final Map<String, dynamic> newClientData = {
      'nome_fantasia': nomeFantasia,
      'endereco': endereco,
      'contato': contato,
      'ativos_alocados': [], // Inicia com lista vazia de ativos alocados
      'createdAt': FieldValue.serverTimestamp(),
      'createdBy': tecnicoUid,
      'lastUpdatedAt': FieldValue.serverTimestamp(),
      'lastUpdatedBy': tecnicoUid,
    };

    try {
      await _firestore.collection('clientes').add(newClientData);
      return null; // Sucesso
    } on FirebaseException catch (e) {
      print("DEBUG createClient: Erro Firebase: ${e.message}");
      return e.message;
    } catch (e, stackTrace) {
      print("DEBUG createClient: Erro inesperado: $e");
      print("DEBUG createClient: Stack Trace: $stackTrace");
      return e.toString();
    }
  }

  // Método para atualizar um cliente existente
  Future<String?> updateClient({
    required String clientId,
    required String nomeFantasia,
    required String endereco,
    required String contato,
    String? tecnicoUid, // UID do tecnico que está atualizando o cliente
  }) async {
    if (tecnicoUid == null) {
      return "Usuário não autenticado.";
    }

    // Verifica se já existe outro cliente com o mesmo nome fantasia (excluindo o cliente atual)
    final existingClient = await _firestore.collection('clientes')
        .where('nome_fantasia', isEqualTo: nomeFantasia)
        .limit(1)
        .get();

    if (existingClient.docs.isNotEmpty && existingClient.docs.first.id != clientId) {
      return "Já existe outro cliente com este nome fantasia.";
    }

    final Map<String, dynamic> updatedClientData = {
      'nome_fantasia': nomeFantasia,
      'endereco': endereco,
      'contato': contato,
      'lastUpdatedAt': FieldValue.serverTimestamp(),
      'lastUpdatedBy': tecnicoUid,
    };

    try {
      await _firestore.collection('clientes').doc(clientId).update(updatedClientData);
      return null; // Sucesso
    } on FirebaseException catch (e) {
      print("DEBUG updateClient: Erro Firebase: ${e.message}");
      return e.message;
    } catch (e, stackTrace) {
      print("DEBUG updateClient: Erro inesperado: $e");
      print("DEBUG updateClient: Stack Trace: $stackTrace");
      return e.toString();
    }
  }

  // NOVO MÉTODO: Método para excluir um cliente

      Future<String?> deleteClient({
        required String clientId,
        String? tecnicoUid,
      }) async {
        if (tecnicoUid == null) {
          return "Usuário não autenticado.";
        }
        print("DEBUG deleteClient: Tentando excluir cliente $clientId por $tecnicoUid");

        try {
          // O runTransaction agora retornara uma String de erro ou null para sucesso
          String? transactionResult = await _firestore.runTransaction<String?>((transaction) async { // <--- MUDANCA AQUI: await _firestore.runTransaction<String?>(...)
            print("DEBUG deleteClient: Dentro da transação para $clientId");
            final clientRef = _firestore.collection('clientes').doc(clientId);
            final clientDoc = await transaction.get(clientRef);

            if (!clientDoc.exists) {
              print("DEBUG deleteClient: Erro: Cliente $clientId não encontrado. Retornando mensagem de erro.");
              return 'Cliente a ser excluído não encontrado.'; // <--- RETORNA STRING DE ERRO
            }
            print("DEBUG deleteClient: Cliente $clientId existe. Verificando ativos alocados.");

            final List<dynamic> ativosAlocados = clientDoc.get('ativos_alocados') ?? [];
            print("DEBUG deleteClient: Ativos alocados: ${ativosAlocados.length} para $clientId");
            if (ativosAlocados.isNotEmpty) {
              print("DEBUG deleteClient: ERRO: Cliente $clientId tem ativos alocados. Retornando mensagem de erro.");
              return 'Não é possível excluir o cliente. Existem ativos alocados a ele.'; // <--- RETORNA STRING DE ERRO
            }
            print("DEBUG deleteClient: Cliente $clientId não tem ativos alocados. Deletando.");

            transaction.delete(clientRef);
            print("DEBUG deleteClient: Cliente $clientId marcado para exclusão.");
            return null; // <--- RETORNA NULL PARA SUCESSO
          });

          // Se transactionResult não for nulo, significa que a transação retornou uma mensagem de erro
          if (transactionResult != null) {
            return transactionResult;
          }

          print("DEBUG deleteClient: Transação de exclusão de cliente concluída com sucesso.");
          return null; // Sucesso
        } on FirebaseException catch (e) {
          print("DEBUG deleteClient: Erro Firebase na exclusão (fora da transação): ${e.message}");
          return e.message; // Retorna a mensagem de erro do FirebaseException
        } catch (e, stackTrace) {
          print("DEBUG deleteClient: Erro inesperado na exclusão (fora da transação): $e");
          print("DEBUG deleteClient: Stack Trace: $stackTrace");
          return "Erro inesperado: $e"; // Retorna a mensagem de erro genérica
        }
      }
  


  }


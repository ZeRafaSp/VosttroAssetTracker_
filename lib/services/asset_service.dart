// lib/services/asset_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:vosttro_asset_tracker/models/client_dropdown_item.dart'; // Importe a classe ClientDropdownItem

class AssetService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;

  //Método para criar um novo ativo
 
Future<String?> createAsset({
  required String assetId,
  required String tipo,
  required String modelo,
  required double valorBase,
  required bool temSeguro,
  required String status,
  required ClientDropdownItem? cliente, // Cliente inicial, pode ser nulo
  required String operacao,            // Operacao inicial, se alocado
  String? tecnicoUid,                  // UID do tecnico que está criando o ativo
  String? observacaoDefeito,
}) async {
  print("DEBUG createAsset: Chamado para assetId: $assetId, status: $status, cliente: ${cliente?.name}");
  if (tecnicoUid == null) {
    print("DEBUG createAsset: Usuário não autenticado.");
    return "Usuário não autenticado.";
  }

  // Verifica se o ativo com este ID (Serial) já existe
  final assetDoc = await _firestore.collection('ativos').doc(assetId).get();
  if (assetDoc.exists) {
    return "Ativo com este número de série já existe.";
  }

  final Map<String, dynamic> newAssetData = {
    'serial': assetId,
    'tipo': tipo,
    'modelo': modelo,
    'valor_base': valorBase,
    'tem_seguro': temSeguro,
    'status': status,
    'cliente_atual_id': (status == 'alugado' || status == 'alugado_em_manutencao')
        ? cliente?.id
        : null,
    'ultima_atualizacao_status': FieldValue.serverTimestamp(),
    'observacao_defeito': observacaoDefeito,
  };
  print("DEBUG createAsset: newAssetData preparado: $newAssetData");

  String initialMovementType = "registro_inicial";
  String initialOrigin = "desconhecido";
  String initialDestination = "desconhecido";

  if (status == 'estoque') {
    initialMovementType = "entrada_em_estoque";
    initialOrigin = "desconhecido"; // Assumindo que vem de fora do sistema
    initialDestination = "estoque";
  } else if (status == 'manutencao') {
    initialMovementType = "entrada_em_manutencao_inicial";
    initialOrigin = "desconhecido";
    initialDestination = "manutencao";
  } else if (status == 'estoque_danificado') {
    initialMovementType = "entrada_em_estoque_danificado_inicial";
    initialOrigin = "desconhecido"; // Assumindo que vem de fora do sistema ou de um inventário
    initialDestination = "estoque_danificado";
  } else if (status == 'alugado' || status == 'alugado_em_manutencao') {
    initialMovementType = "saida_para_cliente_inicial";
    initialOrigin = "estoque"; // Assumindo que o primeiro aluguel sai do estoque
    initialDestination = cliente?.id ?? "desconhecido"; // Ajustado para lidar com cliente nulo defensivamente
  }
  print("DEBUG createAsset: Histórico inicial: type: $initialMovementType, origin: $initialOrigin, dest: $initialDestination");

  final Map<String, dynamic> historyEntryData = {
    'ativo_id': assetId,
    'tipo_movimentacao': initialMovementType,
    'origem': initialOrigin,
    'destino': initialDestination,
    'data': FieldValue.serverTimestamp(),
    'tecnico_id': tecnicoUid,
    'observacao': "Ativo $assetId registrado inicialmente.",
  };
  print("DEBUG createAsset: historyEntryData preparado: $historyEntryData");


  try { // <--- ESTE É O try CORRETO PARA ENVOLVER A TRANSAÇÃO
    print("DEBUG createAsset: Iniciando transação no Firestore.");
    await _firestore.runTransaction((transaction) async {
      print("DEBUG createAsset: Dentro da transação.");

      // --- 0. DECLARAÇÕES DE REFERÊNCIAS ---
      final assetRef = _firestore.collection('ativos').doc(assetId); // Referência ao ativo
      final historyRef = _firestore.collection('historico_movimentacoes').doc(); // Referência para o novo documento de histórico
      
      DocumentReference? clientRef; // Referência ao cliente
      if (cliente != null) { // Apenas cria a referencia se o cliente foi selecionado
        clientRef = _firestore.collection('clientes').doc(cliente.id);
      }
      
      // --- 1. REALIZAR TODAS AS LEITURAS PRIMEIRO ---
      DocumentSnapshot? clientDocSnapshot;
      if (clientRef != null) { // Apenas tenta ler se a referencia do cliente foi criada
        print("DEBUG createAsset: Transação: Lendo documento do cliente ${cliente!.id} ANTES das escritas.");
        clientDocSnapshot = await transaction.get(clientRef);
        print("DEBUG createAsset: Transação: clientDocSnapshot existe: ${clientDocSnapshot.exists}");
        if (!clientDocSnapshot.exists) {
          print("ERROR createAsset: Transação: Cliente selecionado ${cliente.id} nao existe no Firestore. Abortando transacao.");
          throw FirebaseException(
              plugin: 'firestore',
              code: 'not-found',
              message: 'Cliente selecionado para alocacao de ativo nao encontrado no Firestore.');
        }
      }
      // --- FIM DAS LEITURAS ---

      // --- 2. REALIZAR TODAS AS ESCRITAS DEPOIS ---

      // 2a. Criar o documento do ativo
      transaction.set(assetRef, newAssetData);
      print("DEBUG createAsset: Transação: Ativo set() para $assetId.");

      // 2b. Adicionar o registro de histórico inicial
      transaction.set(historyRef, historyEntryData);
      print("DEBUG createAsset: Transação: Histórico adicionado.");

      // 2c. Se o ativo for alugado, atualizar o array 'ativos_alocados' do cliente
      if ((status == 'alugado' || status == 'alugado_em_manutencao') && cliente != null && clientRef != null && clientDocSnapshot != null && clientDocSnapshot.exists) {
        print("DEBUG createAsset: Transação: Ativo alugado. Atualizando cliente ${cliente.id}.");
        
        List<Map<String, dynamic>> allocatedAssets = [];
        final Map<String, dynamic>? clientDataMap = clientDocSnapshot.data() as Map<String, dynamic>?;
        if (clientDataMap != null && clientDataMap.containsKey('ativos_alocados')) {
          final dynamic allocatedAssetsRaw = clientDataMap['ativos_alocados'];
          if (allocatedAssetsRaw is List) {
            allocatedAssets = (allocatedAssetsRaw as List)
                .whereType<Map<String, dynamic>>()
                .toList();
          }
        }
        print("DEBUG createAsset: Transação: allocatedAssets existente (antes de adicionar): $allocatedAssets");

        final newItemToAllocate = {
          'serial_ativo': assetId,
          'valor_aluguel': valorBase,
          'data_inicio_aluguel': Timestamp.fromDate(DateTime.now()), // Data de início do aluguel
          'operacao': operacao,
        };
        print("DEBUG createAsset: Transação: newItemToAllocate: $newItemToAllocate");

        bool found = false;
        for (int i = 0; i < allocatedAssets.length; i++) {
          if (allocatedAssets[i]['serial_ativo'] == assetId) {
            allocatedAssets[i] = newItemToAllocate; // Atualiza o item existente
            found = true;
            break;
          }
        }

        if (!found) {
          allocatedAssets.add(newItemToAllocate);
        }
        print("DEBUG createAsset: Transação: allocatedAssets final para set: $allocatedAssets");

        // Usar set(merge: true) para garantir que o array seja criado/atualizado robustamente
        transaction.set(
          clientRef,
          {'ativos_alocados': allocatedAssets},
          SetOptions(merge: true),
        );
        print("DEBUG createAsset: Transação: Cliente ${cliente.id} atualizado com set(merge: true).");

      } else if ((status == 'alugado' || status == 'alugado_em_manutencao') && (cliente == null || clientRef == null || clientDocSnapshot == null || !clientDocSnapshot.exists)) {
         print("DEBUG createAsset: Transação: Ativo alugado, mas cliente ou snapshot é nulo/inexistente. Retornando erro para UI.");
         // Usamos throw aqui para abortar a transacao e a funcao.
         throw FirebaseException(
             plugin: 'firestore',
             code: 'aborted',
             message: 'Cliente selecionado para alocacao de ativo nao e valido ou nao existe no Firestore.');
      } else {
        print("DEBUG createAsset: Transação: Nenhuma adicao ao cliente novo necessaria (newClient nulo, newClientRef nulo, clientDocSnapshot nulo ou status nao alugado).");
      }
    });
    print("DEBUG createAsset: Transação concluída com sucesso.");
    return null; // Sucesso
  } on FirebaseException catch (e) { // Captura erros específicos do Firebase
    print("DEBUG createAsset: Erro Firebase na transação: ${e.message}");
    return e.message;
  } catch (e, stackTrace) { // Captura outros erros inesperados
    print("DEBUG createAsset: Erro inesperado na transação: $e");
    print("DEBUG createAsset: Stack Trace: $stackTrace");
    rethrow; // Relança a exceção para ver o stack trace completo no console do VS Code
  }
}


// Método para atualizar um ativo existente
Future<String?> updateAssetStatus({
  required String assetId,
  required String oldStatus,
  required String? oldClientId,
  required String newStatus,
  required ClientDropdownItem? newClient,
  required Map<String, dynamic> oldAssetData,
  required double newValorBase,
  required bool newTemSeguro,
  required String newOperacaoAllocated,
  String? newObservacaoDefeito,
  String? substituteAssetId, // NOVO PARAMETRO: ID do ativo substituto
}) async {
  final currentUserId = _firebaseAuth.currentUser?.uid;
  if (currentUserId == null) {
    print("DEBUG updateAssetStatus: Usuário não autenticado.");
    return "Usuário não autenticado.";
  }
   
  print("DEBUG updateAssetStatus: Usuário autenticado: $currentUserId");
  print("DEBUG updateAssetStatus: Iniciando updateAssetStatus para assetId: $assetId");
  print("DEBUG updateAssetStatus: oldStatus: $oldStatus, oldClientId: $oldClientId");
  print("DEBUG updateAssetStatus: newStatus: $newStatus, newClient: ${newClient?.name ?? 'N/A'} (ID: ${newClient?.id ?? 'N/A'})");
  print("DEBUG updateAssetStatus: oldAssetData: $oldAssetData");
  print("DEBUG updateAssetStatus: newValorBase: $newValorBase, newTemSeguro: $newTemSeguro, newOperacaoAllocated: $newOperacaoAllocated");
  print("DEBUG updateAssetStatus: newObservacaoDefeito: $newObservacaoDefeito");
  print("DEBUG updateAssetStatus: substituteAssetId: $substituteAssetId");
   

  String movementType = "atualizacao_status";
  String origin = "desconhecido";
  String destination = "desconhecido";
  String observacaoRegistro = "Status alterado de '$oldStatus' para '$newStatus'"; // Inicializacao defensiva


  // --- Lógica para determinar o tipo de movimentação ---
  if (oldStatus == 'estoque' && (newStatus == 'alugado' || newStatus == 'alugado_em_manutencao')) {
    movementType = "saida_para_cliente";
    origin = "estoque";
    destination = newClient!.id;
  }
  else if (oldStatus == 'estoque' && newStatus == 'manutencao') {
    movementType = "saida_para_manutencao_do_estoque";
    origin = "estoque";
    destination = "manutencao";
  }
  else if (oldStatus == 'estoque' && newStatus == 'estoque_danificado') {
    movementType = "movido_para_estoque_danificado";
    origin = "estoque";
    destination = "estoque_danificado";
  }
  else if ((oldStatus == 'alugado' || oldStatus == 'alugado_em_manutencao') && newStatus == 'estoque') {
    movementType = "devolucao_cliente_para_estoque";
    origin = oldClientId!;
    destination = "estoque";
  } else if ((oldStatus == 'alugado' || oldStatus == 'alugado_em_manutencao') && newStatus == 'manutencao') {
    movementType = "saida_cliente_para_manutencao";
    origin = oldClientId!;
    destination = "manutencao";
  } else if ((oldStatus == 'alugado' || oldStatus == 'alugado_em_manutencao') && newStatus == 'estoque_danificado') {
    movementType = "devolucao_cliente_para_estoque_danificado";
    origin = oldClientId!;
    destination = "estoque_danificado";
  }
  else if (oldStatus == 'manutencao' && (newStatus == 'alugado' || newStatus == 'alugado_em_manutencao')) {
    movementType = "saida_manutencao_para_cliente";
    origin = "manutencao";
    destination = newClient!.id;
  } else if (oldStatus == 'manutencao' && newStatus == 'estoque') {
    movementType = "devolucao_manutencao_para_estoque";
    origin = "manutencao";
    destination = "estoque";
  } else if (oldStatus == 'manutencao' && newStatus == 'estoque_danificado') {
    movementType = "devolucao_manutencao_para_estoque_danificado";
    origin = "manutencao";
    destination = "estoque_danificado";
  }
  else if (newStatus == 'alugado_em_manutencao' && oldStatus == 'alugado') {
    movementType = "movido_para_manutencao_em_cliente";
    origin = oldClientId!;
    destination = oldClientId; // Permanece com o mesmo cliente
    // --- NOVO: Define a observacao para o historico ---
    if (substituteAssetId != null && substituteAssetId.isNotEmpty) {
      observacaoRegistro = "Ativo $assetId movido para manutenção. Substituto: $substituteAssetId.";
    } else {
      observacaoRegistro = "Ativo $assetId movido para manutenção. Sem substituto.";
    }
    // --- FIM NOVO ---
  }
  else if (newStatus == 'alugado' && oldStatus == 'alugado_em_manutencao') {
    movementType = "retorno_manutencao_para_cliente";
    origin = oldClientId!;
    destination = oldClientId;
  }
  else if (oldClientId != newClient?.id && (newStatus == 'alugado' || newStatus == 'alugado_em_manutencao')) {
    movementType = "transferencia_cliente";
    origin = oldClientId ?? "desconhecido";
    destination = newClient!.id;
  }
  else { // Caso em que o status principal nao mudou, mas outros atributos sim, ou e uma transicao nao coberta
    movementType = "atualizacao_dados_do_ativo";
    if (newStatus == 'estoque') {
      origin = "estoque";
      destination = "estoque";
    } else if (newStatus == 'estoque_danificado') {
      origin = "estoque_danificado";
      destination = "estoque_danificado";
    } else if (newStatus == 'manutencao') {
      origin = "manutencao";
      destination = "manutencao";
    }
    else if (newStatus == 'alugado' || newStatus == 'alugado_em_manutencao') {
      origin = newClient?.id ?? oldClientId ?? "desconhecido";
      destination = newClient?.id ?? oldClientId ?? "desconhecido";
    }
  }
  print("DEBUG updateAssetStatus: movementType: $movementType, origin: $origin, destination: $destination");


  final Map<String, dynamic> assetUpdateData = {
    'status': newStatus,
    'ultima_atualizacao_status': FieldValue.serverTimestamp(),
    'cliente_atual_id': (newStatus == 'alugado' || newStatus == 'alugado_em_manutencao')
        ? newClient?.id
        : null,
    'valor_base': newValorBase,
    'tem_seguro': newTemSeguro,
    'observacao_defeito': newObservacaoDefeito,
'substitute_asset_id': (newStatus == 'alugado_em_manutencao' && substituteAssetId != null && substituteAssetId.isNotEmpty)
                         ? substituteAssetId
                         : null,
                         
};
  print("DEBUG updateAssetStatus: assetUpdateData preparado: $assetUpdateData");

  final Map<String, dynamic> historyEntryData = {
    'ativo_id': assetId,
    'tipo_movimentacao': movementType,
    'origem': origin,
    'destino': destination,
    'data': FieldValue.serverTimestamp(),
    'tecnico_id': currentUserId,
    'observacao': observacaoRegistro,
  };
  print("DEBUG updateAssetStatus: historyEntryData preparado: $historyEntryData");


  try { // <--- ESTE É O try CORRETO PARA ENVOLVER A TRANSAÇÃO
    print("DEBUG updateAssetStatus: Iniciando transação no Firestore.");
    await _firestore.runTransaction((transaction) async {
      print("DEBUG updateAssetStatus: Dentro da transação.");

      // --- DECLARAÇÕES DE REFERÊNCIAS ---
      final assetRef = _firestore.collection('ativos').doc(assetId); // Referência ao ativo principal

      DocumentReference? oldClientRef; // Referência ao cliente antigo
      if (oldClientId != null && oldClientId.isNotEmpty) {
        oldClientRef = _firestore.collection('clientes').doc(oldClientId);
      }

      DocumentReference? newClientRef; // Referência ao novo cliente
      if ((newStatus == 'alugado' || newStatus == 'alugado_em_manutencao') && newClient != null) {
        newClientRef = _firestore.collection('clientes').doc(newClient.id);
      }

      DocumentReference? substituteAssetRef; // Referência ao ativo substituto
      if (substituteAssetId != null && substituteAssetId.isNotEmpty) {
        substituteAssetRef = _firestore.collection('ativos').doc(substituteAssetId);
      }

          DocumentReference? oldSubstituteAssetDocRef;
    final String? oldSubstituteAssetIdInMainAsset = oldAssetData['substitute_asset_id'] as String?; // Pega do oldAssetData
    if (oldSubstituteAssetIdInMainAsset != null && oldSubstituteAssetIdInMainAsset.isNotEmpty) {
       oldSubstituteAssetDocRef = _firestore.collection('ativos').doc(oldSubstituteAssetIdInMainAsset);
    }

      // --- FIM DECLARAÇÕES DE REFERÊNCIAS ---


      // --- 1. REALIZAR TODAS AS LEITURAS PRIMEIRO ---
      DocumentSnapshot? oldClientDoc;
      if (oldClientRef != null) {
        print("DEBUG updateAssetStatus: Transação: Lendo documento do cliente antigo $oldClientId.");
        oldClientDoc = await transaction.get(oldClientRef);
        print("DEBUG updateAssetStatus: Transação: oldClientDoc obtido. Exists: ${oldClientDoc.exists}");
      }

      DocumentSnapshot? newClientDoc;
      if (newClientRef != null) {
        print("DEBUG updateAssetStatus: Transação: Lendo documento do cliente novo ${newClient?.id}.");
        newClientDoc = await transaction.get(newClientRef);
        print("DEBUG updateAssetStatus: Transação: newClientDoc obtido. Exists: ${newClientDoc.exists}. Data: ${newClientDoc.data()}");
      }

      DocumentSnapshot? substituteAssetDocumentSnapshot; // <-- snapshot do ativo substituto
 if (substituteAssetRef != null) { // Usa a referencia declarada acima
    print("DEBUG updateAssetStatus: Transação: Lendo documento do ativo substituto (novo) $substituteAssetId.");
    substituteAssetDocumentSnapshot = await transaction.get(substituteAssetRef); // Usa substituteAssetRef
    if (!substituteAssetDocumentSnapshot.exists) {
      print("ERROR updateAssetStatus: Transação: Ativo substituto (novo) $substituteAssetId não encontrado. Abortando.");
      throw FirebaseException(
          plugin: 'firestore',
          code: 'not-found',
          message: 'Ativo substituto $substituteAssetId não encontrado no sistema.');
    }
    // --- CORREÇÃO CHAVE: Validaçao "em estoque" APENAS ao DESIGNAR um NOVO substituto ---
    // Esta validação só deve ocorrer se estamos MUDANDO PARA 'alugado_em_manutencao' e um substituto é fornecido.
    // Não deve ocorrer se estamos saindo de 'alugado_em_manutencao'.
    if (newStatus == 'alugado_em_manutencao' && oldStatus != 'alugado_em_manutencao' && substituteAssetDocumentSnapshot.get('status') != 'estoque') {
       print("ERROR updateAssetStatus: Transação: Ativo substituto (novo) $substituteAssetId não está em estoque. Abortando.");
      throw FirebaseException(
          plugin: 'firestore',
          code: 'failed-precondition',
          message: 'Ativo substituto $substituteAssetId não está disponível (não está em estoque).');
    }
  }

  // --- NOVO: Leitura do ATIVO QUE ERA O SUBSTITUTO (se houver e precisar voltar ao estoque) ---
  DocumentSnapshot? oldSubstituteAssetDocumentSnapshot;
  if (oldSubstituteAssetDocRef != null) {
    print("DEBUG updateAssetStatus: Transação: Lendo documento do ativo substituto (antigo) $oldSubstituteAssetIdInMainAsset.");
    oldSubstituteAssetDocumentSnapshot = await transaction.get(oldSubstituteAssetDocRef);
    if (!oldSubstituteAssetDocumentSnapshot.exists) {
       print("ERROR updateAssetStatus: Transação: Ativo que era substituto $oldSubstituteAssetIdInMainAsset não encontrado. Isso é um erro de dados.");
       // Não lançar erro fatal aqui, apenas logar, pois o objetivo é o principal retornar.
    }
  }
      // --- FIM DAS LEITURAS ---


      // --- 2. REALIZAR TODAS AS ESCRITAS DEPOIS ---

      // 2a. Atualizar o documento do ativo principal
      transaction.update(assetRef, assetUpdateData);
      print("DEBUG updateAssetStatus: Transação: Ativo principal $assetId atualizado.");

      // 2b. Adicionar o registro de histórico principal
      final historyRef = _firestore.collection('historico_movimentacoes').doc();
      transaction.set(historyRef, historyEntryData);
      print("DEBUG updateAssetStatus: Transação: Histórico para ativo principal $assetId adicionado.");

  // 2c. ATUALIZAÇÃO: Lógica para designar NOVO substituto ou retornar substituto para estoque
  // --- CASO 1: Ativo principal passa para ALUGADO_EM_MANUTENCAO e designa um substituto ---
  // Condicao: newStatus eh 'alugado_em_manutencao' E (o oldStatus NAO era 'alugado_em_manutencao' OU o substituto selecionado mudou)
  if (newStatus == 'alugado_em_manutencao' && substituteAssetRef != null && substituteAssetDocumentSnapshot != null && substituteAssetDocumentSnapshot.exists) {
    // Se ja existia um substituto diferente, o antigo precisa voltar para estoque
    if (oldSubstituteAssetIdInMainAsset != null && oldSubstituteAssetIdInMainAsset.isNotEmpty && oldSubstituteAssetIdInMainAsset != substituteAssetId && oldSubstituteAssetDocRef != null && oldSubstituteAssetDocumentSnapshot != null && oldSubstituteAssetDocumentSnapshot.exists) {
        transaction.update(oldSubstituteAssetDocRef, {
          'status': 'estoque',
          'cliente_atual_id': null,
          'ultima_atualizacao_status': FieldValue.serverTimestamp(),
        });
        print("DEBUG updateAssetStatus: Transação: Antigo substituto $oldSubstituteAssetIdInMainAsset voltou para 'estoque' (trocado).");

        final oldSubstituteHistoryRef = _firestore.collection('historico_movimentacoes').doc();
        transaction.set(oldSubstituteHistoryRef, {
          'ativo_id': oldSubstituteAssetIdInMainAsset,
          'tipo_movimentacao': 'retorno_substituto_para_estoque_troca',
          'origem': oldClientId, // Ou newClient?.id
          'destino': 'estoque',
          'data': FieldValue.serverTimestamp(),
          'tecnico_id': currentUserId,
          'observacao': "Ativo $oldSubstituteAssetIdInMainAsset retornou para estoque (trocado de $assetId).",
        });
    }

    // Atribui o novo substituto
    transaction.update(substituteAssetRef, {
      'status': 'substituto',
      'cliente_atual_id': newClient?.id, // Associar ao mesmo cliente do ativo principal
      'ultima_atualizacao_status': FieldValue.serverTimestamp(),
    });
    print("DEBUG updateAssetStatus: Transação: Ativo substituto (novo) $substituteAssetId atualizado para status 'substituto'.");

    // Registrar histórico para o ativo substituto
    final substituteHistoryRef = _firestore.collection('historico_movimentacoes').doc();
    transaction.set(substituteHistoryRef, {
      'ativo_id': substituteAssetId,
      'tipo_movimentacao': 'movido_para_substituicao',
      'origem': 'estoque',
      'destino': newClient?.id, // Onde o substituto foi
      'data': FieldValue.serverTimestamp(),
      'tecnico_id': currentUserId,
      'observacao': "Ativo $substituteAssetId se tornou substituto para $assetId.",
    });
    print("DEBUG updateAssetStatus: Transação: Histórico para substituto $substituteAssetId adicionado.");
  }
  // --- CASO 2: Ativo principal RETORNA DE ALUGADO_EM_MANUTENCAO (e o substituto precisa voltar para estoque) ---
  // Condicao: oldStatus era 'alugado_em_manutencao' E o newStatus NAO eh 'alugado_em_manutencao'
  else if (oldStatus == 'alugado_em_manutencao' && newStatus != 'alugado_em_manutencao' && oldSubstituteAssetIdInMainAsset != null && oldSubstituteAssetDocRef != null && oldSubstituteAssetDocumentSnapshot != null && oldSubstituteAssetDocumentSnapshot.exists) {
      transaction.update(oldSubstituteAssetDocRef, {
        'status': 'estoque', // Retorna para estoque
        'cliente_atual_id': null, // Desassocia do cliente
        'ultima_atualizacao_status': FieldValue.serverTimestamp(),
      });
      print("DEBUG updateAssetStatus: Transação: Ativo substituto (antigo) $oldSubstituteAssetIdInMainAsset retornou para 'estoque'.");

      // Registrar histórico para o substituto retornando
      final oldSubstituteHistoryRef = _firestore.collection('historico_movimentacoes').doc();
      transaction.set(oldSubstituteHistoryRef, {
        'ativo_id': oldSubstituteAssetIdInMainAsset,
        'tipo_movimentacao': 'retorno_substituto_para_estoque',
        'origem': oldClientId, // De onde ele estava (cliente)
        'destino': 'estoque',
        'data': FieldValue.serverTimestamp(),
        'tecnico_id': currentUserId,
        'observacao': "Ativo $oldSubstituteAssetIdInMainAsset retornou para estoque (era substituto de $assetId).",
      });
      print("DEBUG updateAssetStatus: Transação: Histórico para retorno de substituto $oldSubstituteAssetIdInMainAsset adicionado.");
  }

            // 2d. Remover do cliente antigo (se houver e for diferente do novo)
            // Declaracao e inicializacao fora do if para garantir que sempre esteja disponivel
            List<Map<String, dynamic>> oldAllocatedAssets = []; 

            if (oldClientId != null && oldClientId.isNotEmpty && oldClientId != newClient?.id && oldClientRef != null && oldClientDoc != null && oldClientDoc.exists) {
              print("DEBUG updateAssetStatus: Transação: Removendo ativo do cliente antigo ($oldClientId).");
              
              final Map<String, dynamic>? oldClientDataMap = oldClientDoc.data() as Map<String, dynamic>?;
              if (oldClientDataMap != null && oldClientDataMap.containsKey('ativos_alocados')) {
                final dynamic allocatedAssetsRaw = oldClientDataMap['ativos_alocados'];
                if (allocatedAssetsRaw is List) {
                  oldAllocatedAssets = (allocatedAssetsRaw as List)
                      .whereType<Map<String, dynamic>>()
                      .toList();
                }
              }

              final updatedOldAllocatedAssets = oldAllocatedAssets.where((item) => item['serial_ativo'] != assetId).toList();

              transaction.update(oldClientRef, {'ativos_alocados': updatedOldAllocatedAssets});
              print("DEBUG updateAssetStatus: Transação: Ativo $assetId removido do array do cliente antigo via filtro.");
            } else {
              print("DEBUG updateAssetStatus: Transação: Nenhuma remoção do cliente antigo necessária (oldClientId nulo/vazio, cliente nao mudou ou documento nao existe).");
            }

            // 2e. Adicionar ao novo cliente (se houver e o ativo for 'alugado' ou 'alugado_em_manutencao')
            // Declaracao e inicializacao fora do if para garantir que sempre esteja disponivel
            List<Map<String, dynamic>> newAllocatedAssets = []; 

            if ((newStatus == 'alugado' || newStatus == 'alugado_em_manutencao') && newClient != null && newClientRef != null && newClientDoc != null) {
              print("DEBUG updateAssetStatus: Transação: Adicionando/Atualizando ativo no cliente novo (${newClient.id}).");
              
              final Map<String, dynamic> newClientData = (newClientDoc.data() as Map<String, dynamic>?) ?? {};
              print("DEBUG updateAssetStatus: Transação: newClientData extraido: $newClientData");

              final dynamic allocatedAssetsRaw = newClientData['ativos_alocados'];
              print("DEBUG updateAssetStatus: Transação: allocatedAssetsRaw: $allocatedAssetsRaw (Type: ${allocatedAssetsRaw.runtimeType})");

              if (allocatedAssetsRaw is List) {
                newAllocatedAssets = (allocatedAssetsRaw as List)
                    .whereType<Map<String, dynamic>>()
                    .toList();
                print("DEBUG updateAssetStatus: Transação: newAllocatedAssets final (extraido): ${newAllocatedAssets.length} itens.");
              } else if (allocatedAssetsRaw != null) {
                  print("DEBUG updateAssetStatus: Transação: 'ativos_alocados' nao e uma List, mas e ${allocatedAssetsRaw.runtimeType}. Tratando como vazio.");
              } else {
                print("DEBUG updateAssetStatus: Transação: 'ativos_alocados' e null ou nao existe. newAllocatedAssets inicializado como vazio.");
              }
              
              final double valorAluguelParaCliente = newValorBase; 
              print("DEBUG updateAssetStatus: Transação: valorAluguelParaCliente preparado: $valorAluguelParaCliente");

              final newItemToAllocate = {
                'serial_ativo': assetId,
                'valor_aluguel': valorAluguelParaCliente,
                'data_inicio_aluguel': Timestamp.fromDate(DateTime.now()),
                'operacao': newOperacaoAllocated,
              };
              print("DEBUG updateAssetStatus: Transação: newItemToAllocate preparado: $newItemToAllocate");

              bool found = false;
              for (int i = 0; i < newAllocatedAssets.length; i++) {
                if (newAllocatedAssets[i]['serial_ativo'] == assetId) {
                  newAllocatedAssets[i] = newItemToAllocate;
                  found = true;
                  break;
                }
              }

              if (!found) {
                newAllocatedAssets.add(newItemToAllocate);
                print("DEBUG updateAssetStatus: Transação: Ativo $assetId adicionado como novo item ao array.");
              } else {
                print("DEBUG updateAssetStatus: Transação: Ativo $assetId atualizado no array existente.");
              }

              print("DEBUG updateAssetStatus: Transação: Final newAllocatedAssets para set: $newAllocatedAssets");
              transaction.set(
                newClientRef,
                {'ativos_alocados': newAllocatedAssets},
                SetOptions(merge: true),
              );
              print("DEBUG updateAssetStatus: Transação: Ativo $assetId adicionado/atualizado no array do cliente novo (${newClient.id}) via set(merge: true).");
            } else {
              print("DEBUG updateAssetStatus: Transação: Nenhuma adicao ao cliente novo necessaria (newClient nulo, newClientRef nulo, newClientDoc nulo ou status nao alugado).");
            }
    });
    print("DEBUG updateAssetStatus: Transação concluída com sucesso.");
    return null;
  } on FirebaseException catch (e) {
    print("DEBUG updateAssetStatus: Erro Firebase na transação: ${e.message}");
    return e.message;
  } catch (e, stackTrace) {
    print("DEBUG updateAssetStatus: Erro inesperado na transação: $e");
    print("DEBUG updateAssetStatus: Stack Trace: $stackTrace");
    rethrow;
  }
}

      Future<String?> deleteAsset({
        required String assetId,
        required String? clienteAtualId, // ID do cliente atual, se houver
        required String? tecnicoUid,      // UID do tecnico que está deletando o ativo
      }) async {
        if (tecnicoUid == null) {
          return "Usuário não autenticado.";
        }

        try {
          await _firestore.runTransaction((transaction) async {
            // 1. Ler o documento do ativo para confirmar que existe
            final assetRef = _firestore.collection('ativos').doc(assetId);
            final assetDoc = await transaction.get(assetRef);

            if (!assetDoc.exists) {
              throw FirebaseException(
                  plugin: 'firestore',
                  code: 'not-found',
                  message: 'Ativo a ser excluído não encontrado.');
            }

            // 2. Se o ativo está alocado a um cliente, remover do array 'ativos_alocados'
            if (clienteAtualId != null && clienteAtualId.isNotEmpty) {
              final clientRef = _firestore.collection('clientes').doc(clienteAtualId);
              final clientDoc = await transaction.get(clientRef);

              if (clientDoc.exists) {
                List<Map<String, dynamic>> allocatedAssets = [];
                final Map<String, dynamic>? clientDataMap = clientDoc.data() as Map<String, dynamic>?;
                if (clientDataMap != null && clientDataMap.containsKey('ativos_alocados')) {
                  final dynamic allocatedAssetsRaw = clientDataMap['ativos_alocados'];
                  if (allocatedAssetsRaw is List) {
                    allocatedAssets = (allocatedAssetsRaw as List)
                        .whereType<Map<String, dynamic>>()
                        .toList();
                  }
                }

                // Filtrar o ativo a ser removido
                final updatedAllocatedAssets = allocatedAssets.where((item) => item['serial_ativo'] != assetId).toList();

                transaction.update(clientRef, {'ativos_alocados': updatedAllocatedAssets});
              }
            }

            // 3. Excluir todos os históricos de movimentação relacionados a este ativo
            // NOTA: Transações do Firestore não suportam query deletes.
            // Para deletar múltiplos documentos, você precisará de um Cloud Function ou
            // deletar um por um no cliente (o que não é ideal para muitos).
            // Por simplicidade aqui, vamos apenas "marcar" o histórico como deletado ou
            // você pode fazer um delete em batch fora da transação principal.
            // Para o escopo do nosso app, vamos pular a exclusão em massa do histórico aqui
            // e focar em deletar o ativo principal e sua referencia no cliente.
            // A exclusao do historico pode ser feita offline ou via Cloud Function.
            // Se você quiser excluir, terá que buscar todos os documentos de histórico antes da transação
            // e depois deleta-los um por um dentro da transacao (o que é custoso e limitado a 500 documentos/transação).

            // 4. Excluir o documento do ativo
            transaction.delete(assetRef);
          });
          return null; // Sucesso
        } on FirebaseException catch (e) {
          return e.message;
        } catch (e) {
          return e.toString();
        }
      }
    
      
  
}

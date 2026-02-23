    import 'package:firebase_auth/firebase_auth.dart';
    import 'package:cloud_firestore/cloud_firestore.dart';

    class AuthService {
      final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
      final FirebaseFirestore _firestore = FirebaseFirestore.instance;

      // Stream para observar o estado de autenticação (se o usuário está logado ou não)
      Stream<User?> get authStateChanges => _firebaseAuth.authStateChanges();

      // --- Funções de Autenticação ---

      // 1. Registro de Usuário (com criação de perfil no Firestore)
      Future<String?> signUp(
        String email, 
        String password, 
        String name, 
        String contact, 
        String role // 'technician' ou 'admin'
      ) async {
        try {
          // Cria o usuário no Firebase Authentication
          UserCredential userCredential = await _firebaseAuth.createUserWithEmailAndPassword(
            email: email,
            password: password,
          );

          String uid = userCredential.user!.uid;

          // Cria o perfil do usuário na coleção 'usuario' do Firestore
          await _firestore.collection('usuario').doc(uid).set({
            'uid': uid,
            'nome': name,
            'email': email,
            'contato': contact,
            'role': role, // Define a role (ex: 'technician' por padrão para registros via app)
            'isactive': true,
            'data': FieldValue.serverTimestamp(), // data de criação
          });
          return null; // Sucesso, nenhum erro
        } on FirebaseAuthException catch (e) {
          return e.code; // <-- // Retorna a mensagem de erro do Firebase Auth
        } catch (e) {
          return e.toString(); // Retorna outros erros
        }
      }

      // 2. Login de Usuário
      Future<String?> signIn(String email, String password) async {
        try {
          await _firebaseAuth.signInWithEmailAndPassword(
            email: email,
            password: password,
          );
          return null; // Sucesso, nenhum erro
        } on FirebaseAuthException catch (e) {
          return e.code; // <-- // Retorna a mensagem de erro do Firebase Auth
        } catch (e) {
          return e.toString(); // Retorna outros erros
        }
      }

      // 3. Logout de Usuário
      Future<void> signOut() async {
        await _firebaseAuth.signOut();
      }

      // --- Funções para Perfil do Usuário ---

      // Obter o perfil do usuário logado (do Firestore)
      Future<Map<String, dynamic>?> getUserProfile(String uid) async {
        try {
          DocumentSnapshot doc = await _firestore.collection('usuario').doc(uid).get();
          if (doc.exists) {
            return doc.data() as Map<String, dynamic>?;
          }
          return null;
        } catch (e) {
          print("Erro ao obter perfil do usuário: $e");
          return null;
        }
      }

      // Obter o UID do usuário atualmente logado
      String? getCurrentUserUid() {
        return _firebaseAuth.currentUser?.uid;
      }
    }


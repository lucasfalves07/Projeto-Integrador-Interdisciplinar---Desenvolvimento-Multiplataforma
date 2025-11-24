import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// 🌗 Controlador global de tema claro/escuro
/// Sincroniza o modo de tema entre local (SharedPreferences)
/// e remoto (Firestore: users.theme)
class ThemeController extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.light;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  ThemeMode get themeMode => _themeMode;
  bool get isDarkMode => _themeMode == ThemeMode.dark;

  /// Inicializa o tema — busca local e remoto
  Future<void> loadTheme() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString('theme_mode');
      final user = _auth.currentUser;

      // 🔹 Prioriza preferências locais
      if (saved == 'dark') {
        _themeMode = ThemeMode.dark;
      } else if (saved == 'light') {
        _themeMode = ThemeMode.light;
      } else if (user != null) {
        // 🔹 Busca tema remoto se não houver local
        final doc = await _db.collection('users').doc(user.uid).get();
        final remote = doc.data()?['theme'];
        if (remote == 'dark') _themeMode = ThemeMode.dark;
      }
    } catch (e) {
      debugPrint('⚠️ Erro ao carregar tema: $e');
    }
    notifyListeners();
  }

  /// Alterna entre claro e escuro
  Future<void> toggleTheme() async {
    _themeMode =
        _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
    await _saveTheme();
  }

  /// Define o tema explicitamente
  Future<void> setTheme(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();
    await _saveTheme();
  }

  /// Salva o tema localmente e no Firestore
  Future<void> _saveTheme() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final user = _auth.currentUser;

      final themeString = _themeMode == ThemeMode.dark ? 'dark' : 'light';
      await prefs.setString('theme_mode', themeString);

      if (user != null) {
        await _db.collection('users').doc(user.uid).set(
          {
            'theme': themeString,
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      }
    } catch (e) {
      debugPrint('⚠️ Erro ao salvar tema: $e');
    }
  }
}
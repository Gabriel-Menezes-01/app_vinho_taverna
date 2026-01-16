import 'package:flutter/material.dart';
import '../services/user_service.dart';
import '../services/wine_service.dart';
import '../services/sync_service.dart';
import '../services/database_service.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  final UserService userService;
  final WineService wineService;
  final SyncService syncService;
  final DatabaseService databaseService;

  const LoginScreen({
    super.key, 
    required this.userService, 
    required this.wineService,
    required this.syncService,
    required this.databaseService,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _userController = TextEditingController();
  final _passController = TextEditingController();
  bool _loading = false;
  String? _error;
  bool _isRegisterMode = false;

  @override
  void dispose() {
    _userController.dispose();
    _passController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    bool success;
    if (_isRegisterMode) {
      success = await widget.userService.register(
        _userController.text.trim(),
        _passController.text,
      );
      if (!success) {
        if (!mounted) return;
        setState(() {
          _error = 'Usuário já existe. Tente outro nome.';
          _loading = false;
        });
        return;
      }
    } else {
      success = await widget.userService.login(
        _userController.text.trim(),
        _passController.text,
      );
      if (!success) {
        if (!mounted) return;
        setState(() {
          _error = 'Usuário ou senha inválidos';
          _loading = false;
        });
        return;
      }
    }

    if (!mounted) return;

    // Evitar que campos continuem interagindo após navegar
    FocusScope.of(context).unfocus();

    // Obter ID do usuário e configurar wine service
    final userId = await widget.userService.getCurrentUserId();
    if (userId != null) {
      widget.wineService.setCurrentUserId(userId);
      widget.syncService.setCurrentUserId(userId);
    }

    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => HomeScreen(
          wineService: widget.wineService,
          userService: widget.userService,
          syncService: widget.syncService,
          databaseService: widget.databaseService,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isRegisterMode ? 'Criar Conta' : 'Login'),
      ),
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final bottomInset = MediaQuery.of(context).viewInsets.bottom;
            return SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottomInset),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.wine_bar,
                          size: 80,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'Taverna dos Vinhos',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 32),
                        TextFormField(
                          controller: _userController,
                          decoration: const InputDecoration(
                            labelText: 'Usuário',
                            prefixIcon: Icon(Icons.person),
                            border: OutlineInputBorder(),
                          ),
                          textInputAction: TextInputAction.next,
                          validator: (v) {
                            if (v == null || v.isEmpty) return 'Informe o usuário';
                            if (v.length < 3) return 'Mínimo 3 caracteres';
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _passController,
                          decoration: const InputDecoration(
                            labelText: 'Senha',
                            prefixIcon: Icon(Icons.lock),
                            border: OutlineInputBorder(),
                          ),
                          obscureText: true,
                          onFieldSubmitted: (_) => _loading ? null : _submit(),
                          validator: (v) {
                            if (v == null || v.isEmpty) return 'Informe a senha';
                            if (v.length < 4) return 'Mínimo 4 caracteres';
                            return null;
                          },
                        ),
                        const SizedBox(height: 24),
                        if (_error != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: Text(
                              _error!,
                              style: const TextStyle(color: Colors.red),
                            ),
                          ),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _loading ? null : _submit,
                            child: _loading
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : Text(_isRegisterMode ? 'Criar Conta' : 'Entrar'),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _isRegisterMode = !_isRegisterMode;
                              _error = null;
                            });
                          },
                          child: Text(
                            _isRegisterMode
                                ? 'Já tem conta? Faça login'
                                : 'Não tem conta? Cadastre-se',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

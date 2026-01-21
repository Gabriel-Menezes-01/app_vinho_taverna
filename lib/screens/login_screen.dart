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
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passController = TextEditingController();
  bool _loading = false;
  String? _error;
  bool _isRegisterMode = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
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
        _nameController.text.trim(),
        _emailController.text.trim(),
        _passController.text,
      );
      if (!success) {
        if (!mounted) return;
        setState(() {
          _error = 'Nome ou email já existe. Tente outro.';
          _loading = false;
        });
        return;
      }
    } else {
      success = await widget.userService.login(
        _emailController.text.trim(),
        _passController.text,
      );
      if (!success) {
        if (!mounted) return;
        setState(() {
          _error = 'Username/email ou senha inválidos';
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
      
      // Tentar sincronizar dados após login
      try {
        await widget.syncService.syncAll();
        print('✓ Sincronização completa após login');
      } catch (e) {
        print('⚠️ Erro na sincronização: $e');
        // Continuar mesmo se falhar
      }
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
                        if (_isRegisterMode) ...[
                          TextFormField(
                            controller: _nameController,
                            decoration: const InputDecoration(
                              labelText: 'Nome',
                              prefixIcon: Icon(Icons.person),
                              border: OutlineInputBorder(),
                            ),
                            textInputAction: TextInputAction.next,
                            validator: (v) {
                              if (v == null || v.isEmpty) return 'Informe o nome';
                              if (v.length < 3) return 'Mínimo 3 caracteres';
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                        ],
                        TextFormField(
                          controller: _emailController,
                          decoration: InputDecoration(
                            labelText: _isRegisterMode ? 'Email' : 'Username ou Email',
                            prefixIcon: Icon(_isRegisterMode ? Icons.email : Icons.person),
                            border: const OutlineInputBorder(),
                            hintText: _isRegisterMode ? null : 'Digite seu username ou email',
                          ),
                          keyboardType: _isRegisterMode ? TextInputType.emailAddress : TextInputType.text,
                          textInputAction: TextInputAction.next,
                          validator: (v) {
                            if (v == null || v.isEmpty) {
                              return _isRegisterMode ? 'Informe o email' : 'Informe username ou email';
                            }
                            if (_isRegisterMode && !v.contains('@')) {
                              return 'Email inválido';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _passController,
                          decoration: InputDecoration(
                            labelText: 'Senha',
                            prefixIcon: const Icon(Icons.lock),
                            border: const OutlineInputBorder(),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword ? Icons.visibility_off : Icons.visibility,
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscurePassword = !_obscurePassword;
                                });
                              },
                            ),
                          ),
                          obscureText: _obscurePassword,
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

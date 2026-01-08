class AuthService {
  static final AuthService instance = AuthService._init();
  AuthService._init();

  // Simple authentication - in production, use secure storage
  bool _isAuthenticated = false;

  Future<bool> login(String username, String password) async {
    // Simple authentication - accept any credentials for demo
    // In production, implement proper authentication
    if (username.isNotEmpty && password.isNotEmpty) {
      _isAuthenticated = true;
      return true;
    }
    return false;
  }

  Future<void> logout() async {
    _isAuthenticated = false;
  }

  bool get isAuthenticated => _isAuthenticated;
}

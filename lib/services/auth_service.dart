import '../models/app_user.dart';
import 'database_service.dart';

// Initial EXP seeded for each demo account when the user document doesn't
// already exist in MongoDB. Residents start at 100; admins don't surface
// an EXP value in the UI but we still seed a high number so older code
// paths render sensibly.
const int _kSeedExpResident = kDefaultResidentExp;
const int _kSeedExpCityAdmin = 5000;

/// Lightweight in-memory auth state. The two demo accounts are hardcoded —
/// this is intentional for the prototype and not a real credential store.
/// EXP values, however, are persisted in the `users` collection so the chip
/// reads "live" from Mongo on each login and home-screen mount.
class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  AppUser? _currentUser;
  AppUser? get currentUser => _currentUser;

  /// Returns the resolved user on a credential match, or null when rejected.
  /// EXP is fetched from MongoDB (seeded on first login). After a successful
  /// match, kicks off a fire-and-forget warm-up fetch of all reports so the
  /// home screen's stream subscription sees pre-loaded data on its very
  /// first yield instead of an empty list.
  Future<AppUser?> login(String username, String password) async {
    final u = username.trim();
    final p = password.trim();

    if (u == 'Resident1' && p == '123') {
      final exp = await DatabaseService.instance
          .fetchOrSeedUserExp('Resident1', _kSeedExpResident);
      _currentUser = AppUser(
        username: 'Resident1',
        role: UserRole.resident,
        currentExp: exp,
      );
      _warmReportsCache();
      return _currentUser;
    }
    if (u == 'CityAdmin' && p == '12345') {
      final exp = await DatabaseService.instance
          .fetchOrSeedUserExp('CityAdmin', _kSeedExpCityAdmin);
      _currentUser = AppUser(
        username: 'CityAdmin',
        role: UserRole.cityAdmin,
        currentExp: exp,
      );
      _warmReportsCache();
      return _currentUser;
    }
    return null;
  }

  /// Fire-and-forget: pre-populate the reports cache while the user is
  /// transitioning from login → home. By the time `watchReports` is
  /// subscribed in `HomeScreen.initState`, this has often already finished
  /// and its synchronous first yield is non-empty.
  void _warmReportsCache() {
    // ignore: avoid_print
    print('[AUTH] login success — warming reports cache from MongoDB');
    DatabaseService.instance.fetchReports().then((reports) {
      // ignore: avoid_print
      print('[AUTH] reports cache warmed — ${reports.length} reports');
    }).catchError((e) {
      // ignore: avoid_print
      print('[AUTH] reports cache warm-up FAILED — $e');
    });
  }

  /// Replaces the in-memory currentUser with a copy holding the new EXP.
  /// The home screen calls this after re-pulling the value on mount so the
  /// header always reflects the latest Mongo document.
  void updateCurrentExp(int exp) {
    final u = _currentUser;
    if (u == null) return;
    _currentUser = u.copyWith(currentExp: exp);
  }

  void logout() {
    _currentUser = null;
  }
}

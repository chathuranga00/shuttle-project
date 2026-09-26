class ApiEndpoints {
  static const String baseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: 'http://localhost:8080');

  // Auth
  static const String login = '/api/auth/login';

  // Dashboard
  static const String dashboard = '/api/admin/dashboard';

  // Students
  static const String students = '/api/admin/students';
  static String studentById(int id) => '/api/admin/students/$id';
  static String studentStatus(int id) => '/api/admin/students/$id/status';
  static String suspendStudent(int id) => '/api/admin/students/$id/suspend';
  static String activateStudent(int id) => '/api/admin/students/$id/activate';

  // Drivers
  static const String drivers = '/api/admin/drivers';
  static String driverById(int id) => '/api/admin/drivers/$id';
  static String assignDriver(int id) => '/api/admin/drivers/$id/assign';

  // Buses
  static const String buses = '/api/admin/buses';
  static String busById(int id) => '/api/admin/buses/$id';

  // Routes & Stops
  static const String routes = '/api/admin/routes';
  static String routeById(int id) => '/api/admin/routes/$id';
  static const String stops = '/api/admin/stops';
  static String stopById(int id) => '/api/admin/stops/$id';
  static String stopQrPng(int id) => '/api/admin/stops/$id/qr';
  static String stopQrPayload(int id) => '/api/admin/stops/$id/qr/payload';

  // Fares
  static const String fares = '/api/admin/fares';
  static String fareById(int id) => '/api/admin/fares/$id';

  // Trips
  static const String trips = '/api/admin/trips';
  static String tripById(int id) => '/api/admin/trips/$id';
  static String startTrip(int id) => '/api/admin/trips/$id/start';
  static String completeTrip(int id) => '/api/admin/trips/$id/complete';
  static String cancelTrip(int id) => '/api/admin/trips/$id/cancel';

  // Payments
  static const String payments = '/api/admin/payments';

  // Reports
  static String report(String type) => '/api/admin/reports/$type';

  // Settings
  static const String settingsConfig = '/api/admin/settings/config';

  // Live Tracking
  static const String liveLocations = '/api/admin/trips/locations';
  static const String activeTrips = '/api/trips/active';
}

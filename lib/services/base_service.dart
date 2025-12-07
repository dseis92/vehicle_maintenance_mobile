import 'package:supabase_flutter/supabase_flutter.dart';

/// Base service class with common Supabase functionality
abstract class BaseService {
  /// Gets the Supabase client instance
  SupabaseClient get supabase => Supabase.instance.client;

  /// Gets the current authenticated user ID
  /// Returns null if no user is authenticated
  String? get currentUserId => supabase.auth.currentUser?.id;

  /// Validates that a user is authenticated
  /// Throws an exception if no user is authenticated
  void requireAuth() {
    if (currentUserId == null) {
      throw Exception('User not authenticated');
    }
  }

  /// Executes a database operation with error handling
  /// Returns the result on success, throws on error
  Future<T> execute<T>(Future<T> Function() operation) async {
    try {
      return await operation();
    } catch (e) {
      rethrow;
    }
  }

  /// Executes a database operation that returns a list
  /// Returns empty list on error instead of throwing
  Future<List<T>> executeList<T>(
    Future<List<T>> Function() operation,
  ) async {
    try {
      return await operation();
    } catch (e) {
      return [];
    }
  }
}

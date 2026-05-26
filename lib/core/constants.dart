class AppConstants {
  // TODO: Supabase 대시보드 Settings > API에서 복사
  static const supabaseUrl = 'https://YOUR_PROJECT_ID.supabase.co';
  static const supabaseAnonKey = 'YOUR_ANON_KEY';

  // Edge Function URL (Task 9에서 배포 후 업데이트)
  static const consentBaseUrl = '$supabaseUrl/functions/v1/consent';
}

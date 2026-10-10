import 'api_client.dart';

/// The text to show for a failed request.
///
/// The API's own refusals carry a Vietnamese title (for example "Mã voucher
/// đã tồn tại."), which `ApiClient` already uses as the message. Only the
/// authentication layer answers 401/403 with an empty body, which would show
/// as "Lỗi HTTP 401"; those get a sentence the user can act on.
String describeError(Object error) {
  if (error is ApiException && error.message.startsWith('Lỗi HTTP')) {
    switch (error.statusCode) {
      case 401:
        return 'Phiên đăng nhập đã hết hạn. Hãy đăng xuất rồi đăng nhập lại.';
      case 403:
        return 'Tài khoản hiện tại không có quyền thực hiện thao tác này.';
    }
  }
  return error.toString();
}

/// Runs a read and rewrites a 401/403 failure with [describeError], so error
/// panels that print the exception show the readable sentence.
Future<T> readable<T>(Future<T> request) async {
  try {
    return await request;
  } on ApiException catch (error) {
    throw ApiException(describeError(error), statusCode: error.statusCode);
  }
}

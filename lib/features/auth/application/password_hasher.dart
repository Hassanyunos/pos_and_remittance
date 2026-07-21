import 'dart:convert';

import 'package:crypto/crypto.dart';

class PasswordHasher {
  PasswordHasher._();

  static String hash(String password) => sha256.convert(utf8.encode(password)).toString();
}

import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../database/db_helper.dart';

class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  static const defaultPin = '1957';
  static const _pinKey = 'pin_hash';
  static const _initializedKey = 'pin_initialized';

  String _hashPin(String pin) {
    return sha256.convert(utf8.encode(pin)).toString();
  }

  Future<bool> isPinConfigured() async {
    final value = await DbHelper.instance.getConfig(_initializedKey);
    return value == '1';
  }

  Future<void> ensureDefaultPin() async {
    final configured = await isPinConfigured();
    if (!configured) {
      await DbHelper.instance.setConfig(_pinKey, _hashPin(defaultPin));
      await DbHelper.instance.setConfig(_initializedKey, '1');
    }
  }

  Future<bool> verifyPin(String pin) async {
    await ensureDefaultPin();
    final stored = await DbHelper.instance.getConfig(_pinKey);
    return stored == _hashPin(pin);
  }

  Future<void> changePin(String newPin) async {
    await DbHelper.instance.setConfig(_pinKey, _hashPin(newPin));
    await DbHelper.instance.setConfig(_initializedKey, '1');
  }
}

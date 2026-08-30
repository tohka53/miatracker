import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Borrado permanente de cuenta. Requerido por App Store Guideline 5.1.1(v).
class AccountDeletionService {
  static Future<void> deleteAccount() async {
    final client = Supabase.instance.client;
    if (client.auth.currentUser == null) {
      throw Exception('No hay una sesión activa.');
    }

    final response = await client.functions.invoke('delete-account');

    if (response.status != 200) {
      final data = response.data;
      final msg = (data is Map && data['error'] != null)
          ? data['error'].toString()
          : 'El servidor respondió ${response.status}.';
      throw Exception(msg);
    }

    try {
      await client.auth.signOut();
    } catch (_) {
      // La cuenta ya no existe; que falle signOut no importa.
    }
  }
}

/// Item para el drawer. Tiene que quedar visible para TODO usuario,
/// sin importar su rol: Apple rechaza si el revisor no lo encuentra.
class DeleteAccountTile extends StatelessWidget {
  final String loginRoute;
  const DeleteAccountTile({super.key, this.loginRoute = '/login'});

  Future<void> _confirmar(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar cuenta'),
        content: const Text(
          'Esta acción es permanente y no se puede deshacer.\n\n'
          'Se eliminarán tu perfil, todo tu inventario, tus ubicaciones, '
          'las fotos de productos y tus órdenes de reabastecimiento.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar mi cuenta'),
          ),
        ],
      ),
    );

    if (ok != true || !context.mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      await AccountDeletionService.deleteAccount();
      if (!context.mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      Navigator.of(context).pushNamedAndRemoveUntil(loginRoute, (r) => false);
    } catch (e) {
      if (!context.mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.delete_forever, color: Colors.red),
      title: const Text(
        'Eliminar cuenta',
        style: TextStyle(color: Colors.red, fontWeight: FontWeight.w500),
      ),
      onTap: () => _confirmar(context),
    );
  }
}

import 'package:flutter/material.dart';

enum AddProductMethod { camera, gallery, barcode, manual }

class AddProductChoiceSheet extends StatelessWidget {
  const AddProductChoiceSheet({super.key});

  static Future<AddProductMethod?> show(BuildContext context) {
    return showModalBottomSheet<AddProductMethod>(
      context: context,
      builder: (_) => const AddProductChoiceSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Wrap(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'Como deseja adicionar?',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.photo_camera, color: Colors.blue),
            title: const Text('Tirar fotos do produto'),
            subtitle: const Text('Frente, verso, código — pode tirar várias'),
            onTap: () => Navigator.pop(context, AddProductMethod.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library, color: Colors.purple),
            title: const Text('Escolher fotos da galeria'),
            subtitle: const Text('Selecione as partes já fotografadas'),
            onTap: () => Navigator.pop(context, AddProductMethod.gallery),
          ),
          ListTile(
            leading: const Icon(Icons.qr_code, color: Colors.green),
            title: const Text('Escanear código de barras'),
            subtitle: const Text('Consulta rápida na base Open Food Facts'),
            onTap: () => Navigator.pop(context, AddProductMethod.barcode),
          ),
          ListTile(
            leading: const Icon(Icons.edit, color: Colors.grey),
            title: const Text('Cadastrar manualmente'),
            subtitle: const Text('Preencher tudo do zero'),
            onTap: () => Navigator.pop(context, AddProductMethod.manual),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

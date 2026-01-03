import 'package:flutter/material.dart';
import '../models/manufacturer.dart';
import '../services/database_helper.dart';

class ManufacturerDetailScreen extends StatefulWidget {
  final Manufacturer manufacturer;

  const ManufacturerDetailScreen({
    super.key,
    required this.manufacturer,
  });

  @override
  State<ManufacturerDetailScreen> createState() =>
      _ManufacturerDetailScreenState();
}

class _ManufacturerDetailScreenState extends State<ManufacturerDetailScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _dbHelper = DatabaseHelper.instance;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.manufacturer.name;
    _descriptionController.text = widget.manufacturer.description ?? '';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isSaving = true;
      });

      final manufacturer = widget.manufacturer.copyWith(
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        updatedAt: DateTime.now().toUtc(),
      );

      if (widget.manufacturer.id == null) {
        await _dbHelper.insertManufacturer(manufacturer);
      } else {
        await _dbHelper.updateManufacturer(manufacturer);
      }

      setState(() {
        _isSaving = false;
      });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Manufacturer saved')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.manufacturer.id == null
            ? 'New Manufacturer'
            : 'Edit Manufacturer'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (widget.manufacturer.id != null)
              TextFormField(
                initialValue: widget.manufacturer.id.toString(),
                decoration: const InputDecoration(
                  labelText: 'ID',
                  border: OutlineInputBorder(),
                ),
                readOnly: true,
                enabled: false,
              ),
            if (widget.manufacturer.id != null) const SizedBox(height: 16),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Name *',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter name';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isSaving ? null : _save,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _isSaving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}

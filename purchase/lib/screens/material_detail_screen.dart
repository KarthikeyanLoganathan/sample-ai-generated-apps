import 'package:flutter/material.dart';
import '../models/material.dart' as models;
import '../services/database_helper.dart';

class MaterialDetailScreen extends StatefulWidget {
  final models.Material material;

  const MaterialDetailScreen({
    super.key,
    required this.material,
  });

  @override
  State<MaterialDetailScreen> createState() => _MaterialDetailScreenState();
}

class _MaterialDetailScreenState extends State<MaterialDetailScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _unitOfMeasureController = TextEditingController();
  final _dbHelper = DatabaseHelper.instance;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.material.name;
    _descriptionController.text = widget.material.description ?? '';
    _unitOfMeasureController.text = widget.material.unitOfMeasure.isEmpty
        ? 'PC'
        : widget.material.unitOfMeasure;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _unitOfMeasureController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isSaving = true;
      });

      final material = widget.material.copyWith(
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        unitOfMeasure: _unitOfMeasureController.text.trim().isEmpty
            ? 'pcs'
            : _unitOfMeasureController.text.trim(),
        updatedAt: DateTime.now().toUtc(),
      );

      if (widget.material.id == null) {
        await _dbHelper.insertMaterial(material);
      } else {
        await _dbHelper.updateMaterial(material);
      }

      setState(() {
        _isSaving = false;
      });

      if (mounted) {
        Navigator.pop(context, material);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Material saved')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title:
            Text(widget.material.id == null ? 'New Material' : 'Edit Material'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (widget.material.id != null)
              TextFormField(
                initialValue: widget.material.id.toString(),
                decoration: const InputDecoration(
                  labelText: 'ID',
                  border: OutlineInputBorder(),
                ),
                readOnly: true,
                enabled: false,
              ),
            if (widget.material.id != null) const SizedBox(height: 16),
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
            const SizedBox(height: 16),
            TextFormField(
              controller: _unitOfMeasureController,
              decoration: const InputDecoration(
                labelText: 'Unit of Measure *',
                border: OutlineInputBorder(),
                hintText: 'e.g., kg, pcs, liters',
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter unit of measure';
                }
                return null;
              },
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

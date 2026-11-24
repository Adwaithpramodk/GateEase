import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gateeaseapp/api_config.dart';
import 'package:gateeaseapp/private_image.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

const _studentsPath = '/api/mentor/students/';
const _profilePath = '/api/mentor/profile/';
const _passesPath = '/api/mentor/approved-passes/';

String _errorText(Object error) {
  if (error is DioException) {
    final data = error.response?.data;
    if (data case {'error': final String message}) return message;
  }
  return 'Could not complete the request. Try again.';
}

void _showMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}

Future<XFile?> _pickPhoto() => ImagePicker().pickImage(
  source: ImageSource.gallery,
  maxWidth: 1600,
  maxHeight: 1600,
  imageQuality: 90,
);

Future<MultipartFile> _photoPart(XFile photo) async =>
    MultipartFile.fromBytes(await photo.readAsBytes(), filename: photo.name);

String _value(Map<String, dynamic> row, String key) =>
    row[key]?.toString() ?? '';

Widget _photo(String url, {XFile? selected}) {
  const placeholder = Icon(Icons.person_outline);
  return CircleAvatar(
    radius: 25,
    child: ClipOval(
      child: selected != null
          ? Image.file(
              File(selected.path),
              width: 50,
              height: 50,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => placeholder,
            )
          : url.isEmpty
          ? placeholder
          : PrivateImage(
              url,
              width: 50,
              height: 50,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => placeholder,
            ),
    ),
  );
}

class ManageMentorStudentsPage extends StatelessWidget {
  const ManageMentorStudentsPage({super.key});

  @override
  Widget build(BuildContext context) =>
      const _MentorRecordsPage(students: true);
}

class MentorApprovedPassesPage extends StatelessWidget {
  const MentorApprovedPassesPage({super.key});

  @override
  Widget build(BuildContext context) =>
      const _MentorRecordsPage(students: false);
}

class _MentorRecordsPage extends StatefulWidget {
  const _MentorRecordsPage({required this.students});

  final bool students;

  @override
  State<_MentorRecordsPage> createState() => _MentorRecordsPageState();
}

class _MentorRecordsPageState extends State<_MentorRecordsPage> {
  final _search = TextEditingController();
  List<Map<String, dynamic>> _records = [];
  String _filter = '';
  String _query = '';
  String? _error;
  int _page = 1;
  int _pages = 1;
  int _request = 0;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load({int? page}) async {
    final request = ++_request;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response = await dio.get<Map<String, dynamic>>(
        widget.students ? _studentsPath : _passesPath,
        queryParameters: {
          'page': page ?? _page,
          if (widget.students) 'q': _query,
          if (widget.students) 'status': _filter,
        },
      );
      if (!mounted || request != _request) return;
      final data = response.data!;
      setState(() {
        _records = List<Map<String, dynamic>>.from(
          data[widget.students ? 'students' : 'passes'] as List,
        );
        _page = data['page'] as int;
        _pages = data['pages'] as int;
        _loading = false;
      });
    } catch (error) {
      if (!mounted || request != _request) return;
      setState(() {
        _error = _errorText(error);
        _loading = false;
      });
    }
  }

  Future<void> _save(Future<void> Function() operation, String message) async {
    setState(() => _saving = true);
    try {
      await operation();
      if (!mounted) return;
      _showMessage(context, message);
      await _load();
    } catch (error) {
      if (mounted) _showMessage(context, _errorText(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _studentAction(
    Map<String, dynamic> record,
    String action,
  ) async {
    final path = '$_studentsPath${record['id']}/';
    if (action == 'edit') {
      final values = await _studentEditDialog(context, record);
      if (values == null || !mounted) return;
      await _save(() async {
        await dio.patch<void>(path, data: {'action': action, ...values});
      }, 'Student details updated.');
      return;
    }
    if (action == 'photo') {
      try {
        final photo = await _pickPhoto();
        if (photo == null || !mounted) return;
        await _save(() async {
          await dio.patch<void>(
            path,
            data: FormData.fromMap({
              'action': action,
              'image': await _photoPart(photo),
            }),
          );
        }, 'Student photo updated.');
      } catch (error) {
        if (mounted) _showMessage(context, _errorText(error));
      }
      return;
    }
    final verify = action == 'verify';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(verify ? 'Verify student?' : 'Reject student?'),
        content: Text(_value(record, 'name')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialog, true),
            child: Text(verify ? 'Verify' : 'Reject'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _save(() async {
      await dio.patch<void>(path, data: {'action': action});
    }, verify ? 'Student verified.' : 'Student rejected.');
  }

  Future<void> _revoke(Map<String, dynamic> record) async {
    final form = GlobalKey<FormState>();
    String reason = '';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        scrollable: true,
        title: const Text('Revoke pass?'),
        content: Form(
          key: form,
          child: TextFormField(
            decoration: const InputDecoration(
              labelText: 'Reason for revocation',
            ),
            maxLength: 500,
            maxLines: 3,
            onChanged: (value) => reason = value.trim(),
            validator: (_) => reason.isEmpty ? 'Enter a reason.' : null,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (form.currentState!.validate()) Navigator.pop(dialog, true);
            },
            child: const Text('Revoke pass'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _save(() async {
      await dio.post<void>(
        '$_passesPath${record['id']}/revoke/',
        data: {'reason': reason},
      );
    }, 'Pass revoked.');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.students ? 'Manage students' : 'Approved passes'),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => _load(),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: [
              if (widget.students) ...[
                TextField(
                  controller: _search,
                  maxLength: 100,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    labelText: 'Search name, email, admission number or class',
                    counterText: '',
                    suffixIcon: IconButton(
                      tooltip: 'Search students',
                      onPressed: _searchStudents,
                      icon: const Icon(Icons.search),
                    ),
                  ),
                  onSubmitted: (_) => _searchStudents(),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _filter,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Verification status',
                  ),
                  items: const [
                    DropdownMenuItem(value: '', child: Text('All students')),
                    DropdownMenuItem(value: 'pending', child: Text('Pending')),
                    DropdownMenuItem(
                      value: 'verified',
                      child: Text('Verified'),
                    ),
                    DropdownMenuItem(
                      value: 'rejected',
                      child: Text('Rejected'),
                    ),
                    DropdownMenuItem(
                      value: 'no_image',
                      child: Text('No photo'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    _filter = value;
                    _searchStudents();
                  },
                ),
                const SizedBox(height: 12),
              ],
              if (_loading || _saving) const LinearProgressIndicator(),
              if (_error case final message?)
                ListTile(
                  title: Text(message),
                  trailing: TextButton(
                    onPressed: _load,
                    child: const Text('Retry'),
                  ),
                )
              else if (!_loading && _records.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  child: Text(
                    widget.students
                        ? 'No students match this view.'
                        : 'No approved passes awaiting gate action.',
                    textAlign: TextAlign.center,
                  ),
                )
              else if (!_loading) ...[
                for (final record in _records)
                  widget.students ? _studentCard(record) : _passCard(record),
                if (_pages > 1)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Wrap(
                      alignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 12,
                      children: [
                        IconButton(
                          tooltip: 'Previous page',
                          onPressed: _page > 1 && !_saving
                              ? () => _load(page: _page - 1)
                              : null,
                          icon: const Icon(Icons.chevron_left),
                        ),
                        Text('Page $_page of $_pages'),
                        IconButton(
                          tooltip: 'Next page',
                          onPressed: _page < _pages && !_saving
                              ? () => _load(page: _page + 1)
                              : null,
                          icon: const Icon(Icons.chevron_right),
                        ),
                      ],
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _searchStudents() {
    _query = _search.text.trim();
    _load(page: 1);
  }

  Widget _studentCard(Map<String, dynamic> record) {
    final status = _value(record, 'status');
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            leading: _photo(_value(record, 'photo')),
            title: Text(_value(record, 'name')),
            subtitle: Text(
              [
                _value(record, 'class'),
                _value(record, 'admn_no'),
                switch (status) {
                  'Student' => 'Verified',
                  'Rejected' => 'Rejected',
                  _ => 'Pending verification',
                },
              ].where((part) => part.isNotEmpty).join(' · '),
            ),
            trailing: PopupMenuButton<String>(
              tooltip: 'Student actions',
              enabled: !_saving,
              onSelected: (action) => _studentAction(record, action),
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'edit', child: Text('Edit details')),
                if (status == 'Student')
                  const PopupMenuItem(
                    value: 'photo',
                    child: Text('Update photo'),
                  ),
                if (status == 'pending' || status == 'Rejected')
                  const PopupMenuItem(value: 'verify', child: Text('Verify')),
                if (status == 'Student' || status == 'pending')
                  const PopupMenuItem(value: 'reject', child: Text('Reject')),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _passCard(Map<String, dynamic> record) {
    final date = DateTime.tryParse(_value(record, 'date'));
    final reason = _value(record, 'reason');
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            leading: const Icon(Icons.assignment_turned_in_outlined),
            title: Text(_value(record, 'name')),
            subtitle: Text(
              [
                _value(record, 'class'),
                if (date != null) DateFormat.yMMMd().format(date),
                _value(record, 'time'),
                if (record['is_group_pass'] == true) 'Group pass',
              ].where((part) => part.isNotEmpty).join(' · '),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (reason.isNotEmpty) Text(reason),
                TextButton(
                  onPressed: _saving ? null : () => _revoke(record),
                  child: const Text('Revoke pass'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

Future<Map<String, String>?> _studentEditDialog(
  BuildContext context,
  Map<String, dynamic> student,
) {
  final form = GlobalKey<FormState>();
  final changes = <String, String>{};
  return showDialog<Map<String, String>>(
    context: context,
    builder: (dialog) => AlertDialog(
      scrollable: true,
      title: const Text('Edit student details'),
      content: Form(
        key: form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_value(student, 'email')),
            Text(_value(student, 'class')),
            TextFormField(
              initialValue: _value(student, 'name'),
              decoration: const InputDecoration(labelText: 'Name'),
              maxLength: 100,
              validator: (value) => (value?.trim().length ?? 0) < 3
                  ? 'Enter at least 3 characters.'
                  : null,
              onSaved: (value) => changes['name'] = value!.trim(),
            ),
            _digitsField(
              'Phone number',
              _value(student, 'phone'),
              10,
              (value) => changes['phone'] = value,
            ),
            _digitsField(
              'Admission number',
              _value(student, 'admn_no'),
              4,
              (value) => changes['admn_no'] = value,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialog),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (!form.currentState!.validate()) return;
            form.currentState!.save();
            Navigator.pop(dialog, changes);
          },
          child: const Text('Save'),
        ),
      ],
    ),
  );
}

Widget _digitsField(
  String label,
  String initial,
  int length,
  ValueChanged<String> save,
) => TextFormField(
  initialValue: initial,
  decoration: InputDecoration(labelText: label),
  keyboardType: TextInputType.number,
  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
  maxLength: length,
  validator: (value) {
    final text = value ?? '';
    return text.length == length && RegExp(r'^[0-9]+$').hasMatch(text)
        ? null
        : 'Enter $length digits.';
  },
  onSaved: (value) => save(value ?? ''),
);

class MentorEditProfilePage extends StatefulWidget {
  const MentorEditProfilePage({super.key});

  @override
  State<MentorEditProfilePage> createState() => _MentorEditProfilePageState();
}

class _MentorEditProfilePageState extends State<MentorEditProfilePage> {
  final _form = GlobalKey<FormState>();
  Map<String, dynamic>? _profile;
  XFile? _selectedPhoto;
  String? _error;
  bool _saving = false;
  String _name = '';
  String _phone = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final response = await dio.get<Map<String, dynamic>>(_profilePath);
      if (mounted) setState(() => _profile = response.data!);
    } catch (error) {
      if (mounted) setState(() => _error = _errorText(error));
    }
  }

  Future<void> _selectPhoto() async {
    try {
      final photo = await _pickPhoto();
      if (photo != null && mounted) setState(() => _selectedPhoto = photo);
    } catch (error) {
      if (mounted) _showMessage(context, _errorText(error));
    }
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    _form.currentState!.save();
    setState(() => _saving = true);
    try {
      final photo = _selectedPhoto;
      await dio.patch<void>(
        _profilePath,
        data: FormData.fromMap({
          'name': _name,
          'phone': _phone,
          if (photo != null) 'image': await _photoPart(photo),
        }),
      );
      if (!mounted) return;
      _showMessage(context, 'Profile updated.');
      Navigator.pop(context, true);
    } catch (error) {
      if (mounted) _showMessage(context, _errorText(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = _profile;
    return Scaffold(
      appBar: AppBar(title: const Text('Edit profile')),
      body: SafeArea(
        child: profile == null
            ? Center(
                child: _error == null
                    ? const CircularProgressIndicator()
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_error!, textAlign: TextAlign.center),
                          TextButton(
                            onPressed: _load,
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
              )
            : Form(
                key: _form,
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    Center(
                      child: _photo(
                        _value(profile, 'image'),
                        selected: _selectedPhoto,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _saving ? null : _selectPhoto,
                      icon: const Icon(Icons.photo_outlined),
                      label: Text(
                        _selectedPhoto == null
                            ? 'Choose profile photo'
                            : 'Change selected photo',
                      ),
                    ),
                    if (_selectedPhoto case final photo?)
                      Text(photo.name, textAlign: TextAlign.center),
                    Text(_value(profile, 'email')),
                    Text(_value(profile, 'departmentname')),
                    const SizedBox(height: 16),
                    TextFormField(
                      initialValue: _value(profile, 'name'),
                      decoration: const InputDecoration(labelText: 'Name'),
                      maxLength: 100,
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? 'Enter your name.'
                          : null,
                      onSaved: (value) => _name = value!.trim(),
                    ),
                    _digitsField(
                      'Phone number',
                      _value(profile, 'phone'),
                      10,
                      (value) => _phone = value,
                    ),
                    FilledButton(
                      onPressed: _saving ? null : _save,
                      child: Text(_saving ? 'Saving…' : 'Save profile'),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

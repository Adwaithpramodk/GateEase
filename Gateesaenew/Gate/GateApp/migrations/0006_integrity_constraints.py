from django.db import migrations, models
import django.db.models.functions


def remove_duplicate_rows(apps, schema_editor):
    models_to_clean = (
        ('logintable', ('username',), False),
        ('studenttable', ('email',), False),
        ('studenttable', ('admn_no',), False),
        ('mentortable', ('email',), False),
        ('securitytable', ('email',), False),
        ('departmenttable', ('name',), True),
        ('classstable', ('class_name',), True),
        ('class_assigntable', ('class_id_id', 'mentor_id_id'), False),
        ('dept_assigntable', ('department_id_id', 'mentor_id_id'), False),
    )

    for model_name, fields, case_insensitive in models_to_clean:
        model = apps.get_model('GateApp', model_name)
        seen = set()
        duplicate_ids = []

        for row in model.objects.order_by('pk').values('pk', *fields):
            values = tuple(row[field] for field in fields)
            if any(value is None for value in values):
                continue
            key = tuple(
                value.casefold() if case_insensitive and isinstance(value, str) else value
                for value in values
            )
            if key in seen:
                duplicate_ids.append(row['pk'])
            else:
                seen.add(key)

        if duplicate_ids:
            model.objects.filter(pk__in=duplicate_ids).delete()


def preserve_data(apps, schema_editor):
    pass


def ensure_unique_fields(apps, schema_editor):
    fields_to_make_unique = (
        ('logintable', 'username'),
        ('studenttable', 'email'),
        ('studenttable', 'admn_no'),
        ('mentortable', 'email'),
        ('securitytable', 'email'),
    )
    connection = schema_editor.connection

    with connection.cursor() as cursor:
        for model_name, field_name in fields_to_make_unique:
            model = apps.get_model('GateApp', model_name)
            field = model._meta.get_field(field_name)
            constraints = connection.introspection.get_constraints(
                cursor, model._meta.db_table
            )
            already_unique = any(
                constraint['unique']
                and constraint['columns'] == [field.column]
                for constraint in constraints.values()
            )
            if not already_unique:
                schema_editor.execute(
                    schema_editor._create_unique_sql(model, [field])
                )


def ensure_model_constraints(apps, schema_editor):
    constraint_definitions = (
        (
            'departmenttable',
            models.UniqueConstraint(
                django.db.models.functions.Lower('name'),
                name='department_name_ci_unique',
            ),
        ),
        (
            'classstable',
            models.UniqueConstraint(
                django.db.models.functions.Lower('class_name'),
                name='class_name_ci_unique',
            ),
        ),
        (
            'class_assigntable',
            models.UniqueConstraint(
                fields=('class_id', 'mentor_id'),
                name='class_mentor_assignment_unique',
            ),
        ),
        (
            'dept_assigntable',
            models.UniqueConstraint(
                fields=('department_id', 'mentor_id'),
                name='department_mentor_assignment_unique',
            ),
        ),
    )
    connection = schema_editor.connection

    with connection.cursor() as cursor:
        for model_name, constraint in constraint_definitions:
            model = apps.get_model('GateApp', model_name)
            constraints = connection.introspection.get_constraints(
                cursor, model._meta.db_table
            )
            if constraint.name not in constraints:
                schema_editor.add_constraint(model, constraint)


class Migration(migrations.Migration):

    dependencies = [
        ('GateApp', '0005_announcementtable'),
    ]

    operations = [
        migrations.RunPython(remove_duplicate_rows, preserve_data),
        migrations.SeparateDatabaseAndState(
            database_operations=[
                migrations.RunPython(ensure_unique_fields, preserve_data),
            ],
            state_operations=[
                migrations.AlterField(
                    model_name='logintable',
                    name='username',
                    field=models.CharField(
                        blank=True,
                        db_index=True,
                        max_length=100,
                        null=True,
                        unique=True,
                    ),
                ),
                migrations.AlterField(
                    model_name='studenttable',
                    name='email',
                    field=models.CharField(
                        blank=True,
                        db_index=True,
                        max_length=100,
                        null=True,
                        unique=True,
                    ),
                ),
                migrations.AlterField(
                    model_name='studenttable',
                    name='admn_no',
                    field=models.IntegerField(
                        blank=True,
                        db_index=True,
                        null=True,
                        unique=True,
                    ),
                ),
                migrations.AlterField(
                    model_name='mentortable',
                    name='email',
                    field=models.CharField(
                        blank=True,
                        max_length=100,
                        null=True,
                        unique=True,
                    ),
                ),
                migrations.AlterField(
                    model_name='securitytable',
                    name='email',
                    field=models.CharField(
                        blank=True,
                        max_length=100,
                        null=True,
                        unique=True,
                    ),
                ),
            ],
        ),
        migrations.SeparateDatabaseAndState(
            database_operations=[
                migrations.RunPython(ensure_model_constraints, preserve_data),
            ],
            state_operations=[
                migrations.AddConstraint(
                    model_name='departmenttable',
                    constraint=models.UniqueConstraint(
                        django.db.models.functions.Lower('name'),
                        name='department_name_ci_unique',
                    ),
                ),
                migrations.AddConstraint(
                    model_name='classstable',
                    constraint=models.UniqueConstraint(
                        django.db.models.functions.Lower('class_name'),
                        name='class_name_ci_unique',
                    ),
                ),
                migrations.AddConstraint(
                    model_name='class_assigntable',
                    constraint=models.UniqueConstraint(
                        fields=('class_id', 'mentor_id'),
                        name='class_mentor_assignment_unique',
                    ),
                ),
                migrations.AddConstraint(
                    model_name='dept_assigntable',
                    constraint=models.UniqueConstraint(
                        fields=('department_id', 'mentor_id'),
                        name='department_mentor_assignment_unique',
                    ),
                ),
            ],
        ),
    ]

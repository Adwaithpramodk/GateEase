from django.db import migrations, models
import django.db.models.functions


class Migration(migrations.Migration):

    dependencies = [
        ('GateApp', '0005_announcementtable'),
    ]

    operations = [
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
    ]

from django.db import migrations, models


class Migration(migrations.Migration):
    dependencies = [
        ('GateApp', '0006_integrity_constraints'),
    ]

    operations = [
        migrations.CreateModel(
            name='RateLimitCounter',
            fields=[
                (
                    'id',
                    models.BigAutoField(
                        auto_created=True,
                        primary_key=True,
                        serialize=False,
                        verbose_name='ID',
                    ),
                ),
                ('key', models.CharField(max_length=255, unique=True)),
                ('count', models.PositiveIntegerField(default=0)),
                ('expires_at', models.DateTimeField(db_index=True)),
            ],
            options={
                'indexes': [
                    models.Index(fields=['expires_at'], name='GateApp_rat_expires_7f6e5c_idx'),
                ],
            },
        ),
    ]

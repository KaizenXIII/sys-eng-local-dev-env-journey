import os

DATABASES = {
    'default': {
        'ATOMIC_REQUESTS': True,
        'ENGINE': 'django.db.backends.postgresql',
        'NAME': os.getenv('DATABASE_NAME', 'awx'),
        'USER': os.getenv('DATABASE_USER', 'awx'),
        'PASSWORD': os.getenv('DATABASE_PASSWORD', 'awxpass123'),
        'HOST': os.getenv('DATABASE_HOST', 'awx-postgres'),
        'PORT': os.getenv('DATABASE_PORT', '5432'),
    }
}

CLUSTER_HOST_ID = os.getenv('HOSTNAME', 'awx-web')
BROADCAST_WEBSOCKET_PORT = 8052
BROADCAST_WEBSOCKET_PROTOCOL = 'http'

CACHES = {
    'default': {
        'BACKEND': 'awx.main.cache.AWXRedisCache',
        'LOCATION': 'redis://awx-redis:6379/1',
    }
}

BROKER_URL = 'redis://awx-redis:6379/0'

CHANNEL_LAYERS = {
    'default': {
        'BACKEND': 'channels_redis.core.RedisChannelLayer',
        'CONFIG': {
            'hosts': [BROKER_URL],
            'capacity': 10000,
            'group_expiry': 157784760,
        },
    },
}

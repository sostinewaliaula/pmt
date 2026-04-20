# Copyright (c) 2023-present Plane Software, Inc. and contributors
# SPDX-License-Identifier: AGPL-3.0-only
# See the LICENSE file for details.

# Python imports
import ldap
import os

# Django imports
from django.conf import settings
from django.contrib.auth import get_user_model

# Third Party imports
try:
    import ldap
    from django_auth_ldap.backend import LDAPBackend
    from django_auth_ldap.config import LDAPSearch
except ImportError:
    ldap = None
    LDAPBackend = object  # Fallback to avoid inheritance crash
    LDAPSearch = None

# Module imports
from plane.license.utils.instance_value import get_configuration_value

User = get_user_model()

class DynamicLDAPBackend(LDAPBackend):
    """
    A custom LDAP backend that loads configuration dynamically from the InstanceConfiguration model.
    """

    def authenticate(self, request, username=None, password=None, **kwargs):
        # 0. Safety Check for library availability
        if ldap is None or LDAPBackend is object:
            return None

        # 1. Fetch LDAP configurations from DB/Env
        try:
            (
                ENABLE_LDAP,
                SERVER_URI,
                BIND_DN,
                BIND_PASSWORD,
                USER_SEARCH_BASE,
                USER_SEARCH_FILTER,
                FULL_NAME_ATTR,
                EMAIL_ATTR,
            ) = get_configuration_value([
                {"key": "ENABLE_LDAP", "default": os.environ.get("ENABLE_LDAP", "0")},
                {"key": "LDAP_SERVER_URI", "default": os.environ.get("LDAP_SERVER_URI", "")},
                {"key": "LDAP_BIND_DN", "default": os.environ.get("LDAP_BIND_DN", "")},
                {"key": "LDAP_BIND_PASSWORD", "default": os.environ.get("LDAP_BIND_PASSWORD", "")},
                {"key": "LDAP_USER_SEARCH_BASE", "default": os.environ.get("LDAP_USER_SEARCH_BASE", "")},
                {"key": "LDAP_USER_SEARCH_FILTER", "default": os.environ.get("LDAP_USER_SEARCH_FILTER", "(sAMAccountName=%(user)s)")},
                {"key": "LDAP_FULL_NAME_ATTRIBUTE", "default": os.environ.get("LDAP_FULL_NAME_ATTRIBUTE", "displayName")},
                {"key": "LDAP_EMAIL_ATTRIBUTE", "default": os.environ.get("LDAP_EMAIL_ATTRIBUTE", "mail")},
            ])
        except Exception:
            # Fallback to defaults if DB is not ready
            ENABLE_LDAP = os.environ.get("ENABLE_LDAP", "0")
            SERVER_URI = os.environ.get("LDAP_SERVER_URI", "")
            BIND_DN = os.environ.get("LDAP_BIND_DN", "")
            BIND_PASSWORD = os.environ.get("LDAP_BIND_PASSWORD", "")
            USER_SEARCH_BASE = os.environ.get("LDAP_USER_SEARCH_BASE", "")
            USER_SEARCH_FILTER = os.environ.get("LDAP_USER_SEARCH_FILTER", "(sAMAccountName=%(user)s)")
            FULL_NAME_ATTR = os.environ.get("LDAP_FULL_NAME_ATTRIBUTE", "displayName")
            EMAIL_ATTR = os.environ.get("LDAP_EMAIL_ATTRIBUTE", "mail")

        if ENABLE_LDAP != "1" or not SERVER_URI:
            return None

        # 2. Configure django-auth-ldap settings for this request
        # We override the settings object that LDAPBackend uses internally
        self.settings.SERVER_URI = SERVER_URI
        self.settings.BIND_DN = BIND_DN
        self.settings.BIND_PASSWORD = BIND_PASSWORD
        self.settings.USER_SEARCH = LDAPSearch(
            USER_SEARCH_BASE,
            ldap.SCOPE_SUBTREE,
            USER_SEARCH_FILTER
        )
        
        # User Attribute Mapping
        # We map LDAP attributes to Django User fields
        self.settings.USER_ATTR_MAP = {
            "first_name": FULL_NAME_ATTR,
            "email": EMAIL_ATTR,
        }
        
        # Ensure user creation is allowed
        self.settings.ALWAYS_UPDATE_USER = True

        # 3. Perform standard LDAP authentication
        try:
            return super().authenticate(request, username, password, **kwargs)
        except Exception:
            # Silently fail to allow other backends to proceed
            return None

    def get_or_create_user(self, username, ldap_user):
        """
        Custom logic to ensure email matching and linking.
        """
        # Get the email from LDAP attributes
        email_attr = self.settings.USER_ATTR_MAP.get("email", "mail")
        email = ldap_user.attrs.get(email_attr, [None])[0]
        
        if email:
            email = email.lower().strip()
            # Try to find existing user by email (Account Linking)
            user = User.objects.filter(email=email).first()
            if user:
                return user, False
        
        # Default behavior (create new user by username)
        return super().get_or_create_user(username, ldap_user)

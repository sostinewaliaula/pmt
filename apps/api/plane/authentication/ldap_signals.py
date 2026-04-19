# Copyright (c) 2023-present Plane Software, Inc. and contributors
# SPDX-License-Identifier: AGPL-3.0-only
# See the LICENSE file for details.

from django.dispatch import receiver
from django_auth_ldap.backend import populate_user

# Module imports
from plane.db.models import Profile, UserNotificationPreference

@receiver(populate_user)
def handle_ldap_user_provisioning(sender, user, ldap_user, **kwargs):
    """
    Ensure a Plane Profile and Notification Preferences exist for LDAP users.
    This mimics the logic in plane/authentication/adapter/base.py
    """
    
    # 1. Create Profile if it doesn't exist
    if not Profile.objects.filter(user=user).exists():
        Profile.objects.create(user=user)
    
    # 2. Create UserNotificationPreference if it doesn't exist
    if not UserNotificationPreference.objects.filter(user=user).exists():
        UserNotificationPreference.objects.create(
            user=user,
            property_change=True,
            state_change=True,
            comment=True,
            mention=True,
            issue_completed=True,
        )
    
    # 3. Ensure user is active and email verified
    user.is_active = True
    user.is_email_verified = True
    # We don't save(user) here as django-auth-ldap handles the save

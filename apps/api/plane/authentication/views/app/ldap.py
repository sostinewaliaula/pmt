# Copyright (c) 2023-present Plane Software, Inc. and contributors
# SPDX-License-Identifier: AGPL-3.0-only
# See the LICENSE file for details.

# Django imports
from django.contrib.auth import authenticate
from django.http import HttpResponseRedirect
from django.views import View

# Module imports
from plane.authentication.utils.login import user_login
from plane.license.models import Instance
from plane.authentication.utils.host import base_host
from plane.authentication.utils.redirection_path import get_redirection_path
from plane.authentication.utils.user_auth_workflow import post_user_auth_workflow
from plane.authentication.adapter.error import (
    AuthenticationException,
    AUTHENTICATION_ERROR_CODES,
)
from plane.utils.path_validator import get_safe_redirect_url


class LDAPSignInEndpoint(View):
    def post(self, request):
        next_path = request.POST.get("next_path")
        # Check instance configuration
        instance = Instance.objects.first()
        if instance is None or not instance.is_setup_done:
            # Redirection params
            exc = AuthenticationException(
                error_code=AUTHENTICATION_ERROR_CODES["INSTANCE_NOT_CONFIGURED"],
                error_message="INSTANCE_NOT_CONFIGURED",
            )
            params = exc.get_error_dict()
            # Base URL join
            url = get_safe_redirect_url(
                base_url=base_host(request=request, is_app=True),
                next_path=next_path,
                params=params,
            )
            return HttpResponseRedirect(url)

        # Get credentials
        username = request.POST.get("username", False)
        password = request.POST.get("password", False)

        ## Raise exception if any of the above are missing
        if not username or not password:
            # Redirection params
            exc = AuthenticationException(
                error_code=AUTHENTICATION_ERROR_CODES["REQUIRED_EMAIL_PASSWORD_SIGN_IN"],
                error_message="REQUIRED_USERNAME_PASSWORD_SIGN_IN",
                payload={"username": str(username)},
            )
            params = exc.get_error_dict()
            url = get_safe_redirect_url(
                base_url=base_host(request=request, is_app=True),
                next_path=next_path,
                params=params,
            )
            return HttpResponseRedirect(url)

        # 3. Authenticate via LDAP
        try:
            # This calls DynamicLDAPBackend
            user = authenticate(request, username=username, password=password)
            
            if user is None:
                # Authentication failed
                exc = AuthenticationException(
                    error_code=AUTHENTICATION_ERROR_CODES["INVALID_CREDENTIALS"],
                    error_message="Invalid LDAP credentials",
                    payload={"username": str(username)},
                )
                params = exc.get_error_dict()
                url = get_safe_redirect_url(
                    base_url=base_host(request=request, is_app=True),
                    next_path=next_path,
                    params=params,
                )
                return HttpResponseRedirect(url)

            # Workflow
            post_user_auth_workflow(user, is_signup=False, request=request)

            # Login the user and record his device info
            user_login(request=request, user=user, is_app=True)
            
            # Get the redirection path
            if next_path:
                path = next_path
            else:
                path = get_redirection_path(user=user)

            # Get the safe redirect URL
            url = get_safe_redirect_url(
                base_url=base_host(request=request, is_app=True),
                next_path=path,
                params={},
            )
            return HttpResponseRedirect(url)
            
        except AuthenticationException as e:
            params = e.get_error_dict()
            url = get_safe_redirect_url(
                base_url=base_host(request=request, is_app=True),
                next_path=next_path,
                params=params,
            )
            return HttpResponseRedirect(url)
        except Exception as e:
            # Catch all other exceptions
            print(f"LDAP Auth Error: {str(e)}")
            exc = AuthenticationException(
                error_code=AUTHENTICATION_ERROR_CODES["GOOGLE_OAUTH_PROVIDER_ERROR"],
                error_message="INTERNAL_SERVER_ERROR",
            )
            params = exc.get_error_dict()
            url = get_safe_redirect_url(
                base_url=base_host(request=request, is_app=True),
                next_path=next_path,
                params=params,
            )
            return HttpResponseRedirect(url)

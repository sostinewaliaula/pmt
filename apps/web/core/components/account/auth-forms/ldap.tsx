/**
 * Copyright (c) 2023-present Plane Software, Inc. and contributors
 * SPDX-License-Identifier: AGPL-3.0-only
 * See the LICENSE file for details.
 */

import { useEffect, useRef, useState } from "react";
import { observer } from "mobx-react";
// icons
import { Eye, EyeOff, XCircle, ShieldCheck } from "lucide-react";
// plane imports
import { API_BASE_URL } from "@plane/constants";
import { useTranslation } from "@plane/i18n";
import { Button } from "@plane/propel/button";
import { Input, Spinner } from "@plane/ui";
// services
import { AuthService } from "@/services/auth.service";

type Props = {
  handleEmailClear: () => void;
  nextPath: string | undefined;
};

const authService = new AuthService();

export const AuthLDAPForm = observer(function AuthLDAPForm(props: Props) {
  const { handleEmailClear, nextPath } = props;
  // plane imports
  const { t } = useTranslation();
  // ref
  const formRef = useRef<HTMLFormElement>(null);
  // states
  const [csrfPromise, setCsrfPromise] = useState<Promise<{ csrf_token: string }> | undefined>(undefined);
  const [formData, setFormData] = useState({
    username: "",
    password: "",
  });
  const [showPassword, setShowPassword] = useState(false);
  const [isSubmitting, setIsSubmitting] = useState(false);

  useEffect(() => {
    if (csrfPromise === undefined) {
      const promise = authService.requestCSRFToken();
      setCsrfPromise(promise);
    }
  }, [csrfPromise]);

  const handleFormChange = (key: string, value: string) =>
    setFormData((prev) => ({ ...prev, [key]: value }));

  const handleCSRFToken = async () => {
    if (!formRef || !formRef.current) return;
    const token = await csrfPromise;
    if (!token?.csrf_token) return;
    const csrfElement = formRef.current.querySelector("input[name=csrfmiddlewaretoken]");
    csrfElement?.setAttribute("value", token?.csrf_token);
  };

  const isButtonDisabled = formData.username.length === 0 || formData.password.length === 0 || isSubmitting;

  return (
    <form
      ref={formRef}
      className="space-y-4"
      method="POST"
      action={`${API_BASE_URL}/auth/ldap/`}
      onSubmit={async (event) => {
        event.preventDefault();
        await handleCSRFToken();
        setIsSubmitting(true);
        if (formRef.current) formRef.current.submit();
      }}
    >
      <input type="hidden" name="csrfmiddlewaretoken" />
      {nextPath && <input type="hidden" value={nextPath} name="next_path" />}
      
      <div className="space-y-1">
        <label htmlFor="username" className="text-13 font-medium text-tertiary">
          LDAP Username
        </label>
        <div className={`relative flex items-center rounded-md border border-strong bg-surface-1`}>
          <Input
            id="username"
            name="username"
            type="text"
            value={formData.username}
            onChange={(e) => handleFormChange("username", e.target.value)}
            placeholder="Enter your LDAP username"
            className={`h-10 w-full border-0 disable-autofill-style placeholder:text-placeholder`}
            autoComplete="off"
            autoFocus
          />
        </div>
      </div>

      <div className="space-y-1">
        <label htmlFor="password" className="text-13 font-medium text-tertiary">
          Password
        </label>
        <div className="relative flex items-center rounded-md bg-surface-1">
          <Input
            type={showPassword ? "text" : "password"}
            id="password"
            name="password"
            value={formData.password}
            onChange={(e) => handleFormChange("password", e.target.value)}
            placeholder="Enter your LDAP password"
            className="h-10 w-full border border-strong !bg-surface-1 pr-12 disable-autofill-style placeholder:text-placeholder"
            autoComplete="off"
          />
          <button
            type="button"
            onClick={() => setShowPassword(!showPassword)}
            className="absolute right-3 grid size-5 place-items-center"
          >
            {showPassword ? (
              <EyeOff className="size-5 stroke-placeholder" />
            ) : (
              <Eye className="size-5 stroke-placeholder" />
            )}
          </button>
        </div>
      </div>

      <div className="space-y-2.5">
        <Button type="submit" variant="primary" className="w-full" size="xl" disabled={isButtonDisabled}>
          {isSubmitting ? (
            <Spinner height="20px" width="20px" />
          ) : (
            "Sign in with LDAP"
          )}
        </Button>
        <Button
          type="button"
          onClick={handleEmailClear}
          variant="secondary"
          className="w-full text-tertiary"
          size="xl"
        >
          Cancel and go back
        </Button>
      </div>
    </form>
  );
});

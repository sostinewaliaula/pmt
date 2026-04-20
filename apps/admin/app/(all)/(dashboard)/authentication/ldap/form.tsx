/**
 * Copyright (c) 2023-present Plane Software, Inc. and contributors
 * SPDX-License-Identifier: AGPL-3.0-only
 * See the LICENSE file for details.
 */

import { useState } from "react";
import { useForm } from "react-hook-form";
// plane internal packages
import { Button, getButtonStyling } from "@plane/propel/button";
import { TOAST_TYPE, setToast } from "@plane/propel/toast";
import type { IFormattedInstanceConfiguration, TInstanceLdapAuthenticationConfigurationKeys } from "@plane/types";
// components
import { ConfirmDiscardModal } from "@/components/common/confirm-discard-modal";
import type { TControllerInputFormField } from "@/components/common/controller-input";
import { ControllerInput } from "@/components/common/controller-input";
// hooks
import { useInstance } from "@/hooks/store";
import Link from "next/link";

type Props = {
  config: IFormattedInstanceConfiguration;
};

type LDAPConfigFormValues = Record<TInstanceLdapAuthenticationConfigurationKeys, string>;

export function InstanceLDAPConfigForm(props: Props) {
  const { config } = props;
  // states
  const [isDiscardChangesModalOpen, setIsDiscardChangesModalOpen] = useState(false);
  // store hooks
  const { updateInstanceConfigurations } = useInstance();
  // form data
  const {
    handleSubmit,
    control,
    reset,
    formState: { errors, isDirty, isSubmitting },
  } = useForm<LDAPConfigFormValues>({
    defaultValues: {
      LDAP_SERVER_URI: config["LDAP_SERVER_URI"] || "",
      LDAP_BIND_DN: config["LDAP_BIND_DN"] || "",
      LDAP_BIND_PASSWORD: config["LDAP_BIND_PASSWORD"] || "",
      LDAP_USER_SEARCH_BASE: config["LDAP_USER_SEARCH_BASE"] || "",
      LDAP_USER_SEARCH_FILTER: config["LDAP_USER_SEARCH_FILTER"] || "(sAMAccountName=%(user)s)",
      LDAP_FULL_NAME_ATTRIBUTE: config["LDAP_FULL_NAME_ATTRIBUTE"] || "displayName",
      LDAP_EMAIL_ATTRIBUTE: config["LDAP_EMAIL_ATTRIBUTE"] || "mail",
    },
  });

  const LDAP_FORM_FIELDS: TControllerInputFormField[] = [
    {
      key: "LDAP_SERVER_URI",
      type: "text",
      label: "Server URI",
      description: "Example: ldap://ldap.company.com or ldaps://ldap.company.com:636",
      placeholder: "ldap://example.com",
      error: Boolean(errors.LDAP_SERVER_URI),
      required: true,
    },
    {
      key: "LDAP_BIND_DN",
      type: "text",
      label: "Bind DN",
      description: "The distinguished name for the account used to search the directory.",
      placeholder: "cn=admin,dc=example,dc=com",
      error: Boolean(errors.LDAP_BIND_DN),
      required: true,
    },
    {
      key: "LDAP_BIND_PASSWORD",
      type: "password",
      label: "Bind Password",
      description: "The password for the Bind DN account.",
      placeholder: "••••••••",
      error: Boolean(errors.LDAP_BIND_PASSWORD),
      required: true,
    },
    {
      key: "LDAP_USER_SEARCH_BASE",
      type: "text",
      label: "User Search Base",
      description: "The base DN where users are located.",
      placeholder: "ou=users,dc=example,dc=com",
      error: Boolean(errors.LDAP_USER_SEARCH_BASE),
      required: true,
    },
    {
      key: "LDAP_USER_SEARCH_FILTER",
      type: "text",
      label: "User Search Filter",
      description: "The filter used to find the user. Use %(user)s as a placeholder.",
      placeholder: "(sAMAccountName=%(user)s)",
      error: Boolean(errors.LDAP_USER_SEARCH_FILTER),
      required: true,
    },
    {
      key: "LDAP_FULL_NAME_ATTRIBUTE",
      type: "text",
      label: "Full Name Attribute",
      description: "Attribute that contains the user's full name.",
      placeholder: "displayName",
      error: Boolean(errors.LDAP_FULL_NAME_ATTRIBUTE),
      required: true,
    },
    {
      key: "LDAP_EMAIL_ATTRIBUTE",
      type: "text",
      label: "Email Attribute",
      description: "Attribute that contains the user's email address.",
      placeholder: "mail",
      error: Boolean(errors.LDAP_EMAIL_ATTRIBUTE),
      required: true,
    },
  ];

  const onSubmit = async (formData: LDAPConfigFormValues) => {
    try {
      const response = await updateInstanceConfigurations(formData);
      setToast({
        type: TOAST_TYPE.SUCCESS,
        title: "Success",
        message: "LDAP configuration updated successfully.",
      });
      // Update form default values to latest
      const newDefaults: Partial<LDAPConfigFormValues> = {};
      response.forEach((item) => {
        if (item.key in formData) {
          newDefaults[item.key as keyof LDAPConfigFormValues] = item.value;
        }
      });
      reset(newDefaults as LDAPConfigFormValues);
    } catch (err) {
      console.error(err);
      setToast({
        type: TOAST_TYPE.ERROR,
        title: "Error",
        message: "Failed to update LDAP configuration.",
      });
    }
  };

  const handleGoBack = (e: React.MouseEvent<HTMLAnchorElement, MouseEvent>) => {
    if (isDirty) {
      e.preventDefault();
      setIsDiscardChangesModalOpen(true);
    }
  };

  return (
    <>
      <ConfirmDiscardModal
        isOpen={isDiscardChangesModalOpen}
        onDiscardHref="/authentication"
        handleClose={() => setIsDiscardChangesModalOpen(false)}
      />
      <div className="flex flex-col gap-8">
        <div className="grid w-full grid-cols-2 gap-x-12 gap-y-8">
          <div className="col-span-2 flex flex-col gap-y-4 pt-1 md:col-span-1">
            <div className="pt-2.5 text-18 font-medium">LDAP Server Details</div>
            {LDAP_FORM_FIELDS.map((field) => (
              <ControllerInput
                key={field.key}
                control={control}
                type={field.type}
                name={field.key}
                label={field.label}
                description={field.description}
                placeholder={field.placeholder}
                error={field.error}
                required={field.required}
              />
            ))}
            <div className="flex flex-col gap-1 pt-4">
              <div className="flex items-center gap-4">
                <Button
                  variant="primary"
                  size="lg"
                  onClick={(e) => void handleSubmit(onSubmit)(e)}
                  loading={isSubmitting}
                  disabled={!isDirty}
                >
                  {isSubmitting ? "Saving" : "Save changes"}
                </Button>
                <Link href="/authentication" className={getButtonStyling("secondary", "lg")} onClick={handleGoBack}>
                  Go back
                </Link>
              </div>
            </div>
          </div>
          <div className="col-span-2 flex flex-col gap-y-6 md:col-span-1">
            <div className="pt-2 text-18 font-medium">LDAP Integration Guide</div>
            <div className="flex flex-col gap-y-4 rounded-lg bg-layer-1 px-6 py-4 text-sm text-secondary leading-6">
              <p>
                To enable LDAP authentication, you must provide your server details and a service account (Bind DN) that
                has permission to search your directory.
              </p>
              <ul className="list-disc pl-5 space-y-2">
                <li>
                  <strong>Server URI:</strong> Use <code>ldaps://</code> for secure connections.
                </li>
                <li>
                  <strong>Search Filter:</strong> Plane uses this to find the user object. For Active Directory,{" "}
                  <code>(sAMAccountName=%(user)s)</code> is standard.
                </li>
                <li>
                  <strong>Attribute Mapping:</strong> Ensure your LDAP server has attributes for full name and email.
                </li>
              </ul>
            </div>
          </div>
        </div>
      </div>
    </>
  );
}

/**
 * Copyright (c) 2023-present Plane Software, Inc. and contributors
 * SPDX-License-Identifier: AGPL-3.0-only
 * See the LICENSE file for details.
 */

import { useState } from "react";
import { observer } from "mobx-react";
import useSWR from "swr";
import { setPromiseToast } from "@plane/propel/toast";
import { Loader, ToggleSwitch } from "@plane/ui";
// components
import { AuthenticationMethodCard } from "@/components/authentication/authentication-method-card";
import { PageWrapper } from "@/components/common/page-wrapper";
// hooks
import { useInstance } from "@/hooks/store";
import { ShieldCheck } from "lucide-react";
// types
import type { Route } from "./+types/page";
// local
import { InstanceLDAPConfigForm } from "./form";

const InstanceLDAPAuthenticationPage = observer(function InstanceLDAPAuthenticationPage(
  _props: Route.ComponentProps
) {
  // store
  const { fetchInstanceConfigurations, formattedConfig, updateInstanceConfigurations } = useInstance();
  // state
  const [isSubmitting, setIsSubmitting] = useState<boolean>(false);
  // config
  const enableLDAPConfig = formattedConfig?.ENABLE_LDAP ?? "";

  useSWR("INSTANCE_CONFIGURATIONS", () => fetchInstanceConfigurations());

  const updateConfig = async (key: "ENABLE_LDAP", value: string) => {
    setIsSubmitting(true);

    const payload = {
      [key]: value,
    };

    const updateConfigPromise = updateInstanceConfigurations(payload);

    setPromiseToast(updateConfigPromise, {
      loading: "Saving Configuration",
      success: {
        title: "Configuration saved",
        message: () => `LDAP authentication is now ${value === "1" ? "active" : "disabled"}.`,
      },
      error: {
        title: "Error",
        message: () => "Failed to save configuration",
      },
    });

    await updateConfigPromise
      .then(() => {
        setIsSubmitting(false);
      })
      .catch((err) => {
        console.error(err);
        setIsSubmitting(false);
      });
  };

  return (
    <PageWrapper
      customHeader={
        <AuthenticationMethodCard
          name="LDAP / Active Directory"
          description="Allow members to login to plane with their LDAP or Active Directory credentials."
          icon={<ShieldCheck className="h-6 w-6 p-0.5 text-tertiary" />}
          config={
            <ToggleSwitch
              value={Boolean(parseInt(enableLDAPConfig))}
              onChange={() => {
                const newValue = Boolean(parseInt(enableLDAPConfig)) === true ? "0" : "1";
                updateConfig("ENABLE_LDAP", newValue);
              }}
              size="sm"
              disabled={isSubmitting || !formattedConfig}
            />
          }
          disabled={isSubmitting || !formattedConfig}
          withBorder={false}
        />
      }
    >
      {formattedConfig ? (
        <InstanceLDAPConfigForm config={formattedConfig} />
      ) : (
        <Loader className="space-y-8">
          <Loader.Item height="50px" width="25%" />
          <Loader.Item height="50px" />
          <Loader.Item height="50px" />
          <Loader.Item height="50px" />
          <Loader.Item height="50px" width="50%" />
        </Loader>
      )}
    </PageWrapper>
  );
});

export const meta: Route.MetaFunction = () => [{ title: "LDAP Authentication - God Mode" }];

export default InstanceLDAPAuthenticationPage;

import type { ComponentType } from 'react';
import { loadRouteNamespaces } from '@/shared/i18n/catalogs';
import { routeModules } from './routeModules.gen';

type RouteModules = typeof routeModules;
type ModuleOf<S extends keyof RouteModules> = Awaited<ReturnType<RouteModules[S]['load']>>;

/**
 * A code-split route: loads the module and the message namespaces it uses
 * (in the current interface language) in parallel, so the page renders
 * translated on its first paint. Add a route by calling `page()` in
 * routes.tsx and running `pnpm i18n:gen`.
 */
export function page<S extends keyof RouteModules>(spec: S, exportName: keyof ModuleOf<S>) {
  return async () => {
    const entry = routeModules[spec];
    const [module] = await Promise.all([entry.load(), loadRouteNamespaces(entry.messages)]);
    return { Component: (module as ModuleOf<S>)[exportName] as ComponentType };
  };
}

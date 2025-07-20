import { InjectionToken } from '@angular/core';
import { ContentSecurityPolicyFeature } from './features';
export type NgIconPreProcessor = (icon: string) => string;
export type NgIconPostProcessor = (element: HTMLElement | SVGElement) => void;
export declare const NgIconPreProcessorToken: InjectionToken<NgIconPreProcessor>;
export declare const NgIconPostProcessorToken: InjectionToken<NgIconPostProcessor>;
export declare function injectNgIconPreProcessor(): NgIconPreProcessor;
export declare function injectNgIconPostProcessor(): NgIconPostProcessor;
/**
 * Process icons in a way that is compliant with the content security policy
 */
export declare function withContentSecurityPolicy(): ContentSecurityPolicyFeature;

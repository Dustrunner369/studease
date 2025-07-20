import { InjectionToken } from '@angular/core';
import { ExceptionLoggerFeature } from './features';
interface Logger {
    log(message: string): void;
    warn(message: string): void;
    error(message: string): void;
}
export declare const LoggerToken: InjectionToken<Logger>;
/**
 * The default logger implementation that logs to the console
 */
export declare class DefaultLogger implements Logger {
    log(message: string): void;
    warn(message: string): void;
    error(message: string): void;
}
/**
 * A logger implementation that throws an error on warnings and errors
 */
export declare class ExceptionLogger implements Logger {
    log(message: string): void;
    warn(message: string): void;
    error(message: string): void;
}
export declare function injectLogger(): Logger;
/**
 * Throw exceptions on warnings and errors
 */
export declare function withExceptionLogger(): ExceptionLoggerFeature;
export {};

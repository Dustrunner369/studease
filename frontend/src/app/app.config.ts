import { ApplicationConfig, provideZoneChangeDetection } from '@angular/core';
import { provideRouter } from '@angular/router';
import { provideClientHydration, withEventReplay } from '@angular/platform-browser';
import { provideHttpClient } from '@angular/common/http';
import { routes } from './app.routes';
import { provideIcons } from '@ng-icons/core';
import {
  lucideMapPin,
  lucideClock,
  lucideZap,
  lucideCoffee,
  lucidePlus,
  lucideX
} from '@ng-icons/lucide';

export const appConfig: ApplicationConfig = {
  providers: [
    provideZoneChangeDetection({ eventCoalescing: true }),
    provideRouter(routes),
    provideClientHydration(withEventReplay()),
    provideHttpClient(),
    provideIcons({
      lucideMapPin,
      lucideClock,
      lucideZap,
      lucideCoffee,
      lucidePlus,
      lucideX
    })
  ]
};

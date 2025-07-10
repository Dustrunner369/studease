import { Component } from '@angular/core';
import { RouterOutlet } from '@angular/router';
import { SpotCardComponent } from './spot-card/spot-card.component';

@Component({  
  selector: 'app-root',
  imports: [RouterOutlet, SpotCardComponent],
  templateUrl: './app.component.html',  
})
export class AppComponent {
  title = 'study-spot-app';
}

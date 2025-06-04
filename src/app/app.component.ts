import { Component } from '@angular/core';
import { RouterOutlet } from '@angular/router';
import { CardComponent } from "./card.component";
import { SpotCardComponent } from './spot-card/spot-card.component';

@Component({
  selector: 'app-root',
  imports: [RouterOutlet, CardComponent, SpotCardComponent],
  templateUrl: './app.component.html',  
})
export class AppComponent {
  title = 'study-spot-app';
}

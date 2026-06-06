import { Component, Input } from '@angular/core';
import { RouterOutlet } from '@angular/router';
import { SpotCardComponent } from './spot-card/spot-card.component';
import { SpotListComponent } from './spot-list/spot-list.component';
import { StudySpot } from '../services/study-spot.service';

@Component({  
  selector: 'app-root',
  imports: [RouterOutlet, SpotCardComponent, SpotListComponent],
  templateUrl: './app.component.html',  
})
export class AppComponent {
  title = 'study-spot-app';
}

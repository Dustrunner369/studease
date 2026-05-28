import { Component } from '@angular/core';
import { FormsModule, NgForm } from '@angular/forms';
import { lucideMapPin } from '@ng-icons/lucide';
import { StudySpotService, StudySpot } from '../../services/study-spot.service';
import { NgIcon } from "@ng-icons/core";

@Component({ 
  selector: 'app-spot-card',
  imports: [FormsModule, NgIcon],
  templateUrl: './spot-card.component.html',
  styleUrl: './spot-card.component.css'
})
export class SpotCardComponent {
  constructor(private studySpotService: StudySpotService) {}

  // Gets the currently selected object from study-spot.service
  get selectedSpot(): StudySpot | null {
    return this.studySpotService.selectedStudySpot;
  }

  // Format the closing time to display only the hour
  formatTime = (date: Date) => {
    return date.toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" });
  }

  //TODO: Display 10 coffee icons that are highlighted depending on the coffee quality.
  // formatCoffeeQualiy = (quality: number) => {
  //   return
  // };
  formatCharging = (hasCharging: Boolean) => {
    return hasCharging ? "Available" : "Unavailable";
  }
}

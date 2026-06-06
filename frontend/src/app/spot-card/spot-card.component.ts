import { Component } from '@angular/core';
import { StudySpotService, StudySpot } from '../../services/study-spot.service';
import { NgIcon } from "@ng-icons/core";

@Component({
  selector: 'app-spot-card',
  imports: [NgIcon],
  templateUrl: './spot-card.component.html',
  styleUrl: './spot-card.component.css'
})
export class SpotCardComponent {
  constructor(private studySpotService: StudySpotService) {}

  get selectedSpot(): StudySpot | null {
    return this.studySpotService.selectedStudySpot;
  }

  formatTime(date: Date): string {
    return date.toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" });
  }

  barWidth(value: number, max: number = 10): number {
    return Math.min(value, max) / max * 100;
  }
}

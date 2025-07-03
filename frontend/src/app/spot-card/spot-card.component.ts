import { Component, OnInit } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { StudySpotService, StudySpot } from '../../services/study-spot.service';

@Component({
  selector: 'app-spot-card',
  imports: [FormsModule],
  templateUrl: './spot-card.component.html',
  styleUrl: './spot-card.component.css'
})
export class SpotCardComponent implements OnInit {
  studySpots: StudySpot[] = [];

  constructor(private studySpotService: StudySpotService) {}

  // This function is called when the component is loaded into the DOM
  ngOnInit(): void {
    this.studySpotService.getStudySpots().subscribe(data => {
      console.log("Fetching study spots...");
      this.studySpots = data;
      console.log(data);      
    });
  }
  createStudySpot() {
    
  }
}

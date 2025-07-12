import { Component, OnInit } from '@angular/core';
import { StudySpotService, StudySpot } from '../../services/study-spot.service';

@Component({
  selector: 'app-spot-list',
  imports: [],
  templateUrl: './spot-list.component.html',
  styleUrl: './spot-list.component.css'
})
export class SpotListComponent implements OnInit {
  studySpots: StudySpot[] = [];
  
  constructor(private studySpotService: StudySpotService) {}

  // This function is called when the component is loaded into the DOM
  ngOnInit(): void {
      this.studySpotService.getStudySpots().subscribe(data => {
      console.log("Fetching study spots... in new component");
      this.studySpots = data;
      console.log(data);      
    });
  }
}

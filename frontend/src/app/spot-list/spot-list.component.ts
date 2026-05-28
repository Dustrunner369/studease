import { Component, OnInit } from '@angular/core';
import { StudySpotService, StudySpot } from '../../services/study-spot.service';

@Component({
  selector: 'app-spot-list',
  imports: [],
  templateUrl: './spot-list.component.html',
  styleUrl: './spot-list.component.css'
})
export class SpotListComponent implements OnInit {
  constructor(private studySpotService: StudySpotService) {}

  get studySpots(): StudySpot[] {
    return this.studySpotService.tempStudySpotList;
  }

  // This function is called when the component is loaded into the DOM
  ngOnInit(): void {
    //   this.studySpotService.getStudySpots().subscribe(data => {
    //   console.log("Fetching study spots... in new component");
    //   this.studySpots = data;
    //   console.log(data);      
    // });
  }
  changeSelectedSpot(spot: StudySpot): void {
    this.studySpotService.selectedStudySpot = spot;
  }
}

import { Component, OnInit } from '@angular/core';
import { StudySpotService, StudySpot } from '../../services/study-spot.service';
import { CreateSpotFormComponent } from "../create-spot-form/create-spot-form.component";

@Component({
  selector: 'app-spot-list',
  imports: [CreateSpotFormComponent],
  templateUrl: './spot-list.component.html',
  styleUrl: './spot-list.component.css'
})
export class SpotListComponent implements OnInit {
  isModalVisible = false;
  
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
  showModal(): void {
    console.log("show modal");
    this.isModalVisible = true;
  }
  hideModal(): void {
    console.log("hide Modal");
    this.isModalVisible = false;
  }
}

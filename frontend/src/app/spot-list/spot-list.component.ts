import { Component, OnInit } from '@angular/core';
import { StudySpotService, StudySpot } from '../../services/study-spot.service';
import { CreateSpotFormComponent } from "../create-spot-form/create-spot-form.component";
import { NgIcon } from '@ng-icons/core';

@Component({
  selector: 'app-spot-list',
  imports: [CreateSpotFormComponent, NgIcon],
  templateUrl: './spot-list.component.html',
  styleUrl: './spot-list.component.css'
})
export class SpotListComponent implements OnInit {
  isModalVisible = false;

  constructor(private studySpotService: StudySpotService) {}

  get studySpots(): StudySpot[] {
    return this.studySpotService.tempStudySpotList;
  }

  get selectedSpot(): StudySpot | null {
    return this.studySpotService.selectedStudySpot;
  }

  ngOnInit(): void {}

  changeSelectedSpot(spot: StudySpot): void {
    this.studySpotService.selectedStudySpot = spot;
  }

  showModal(): void {
    this.isModalVisible = true;
  }

  hideModal(): void {
    this.isModalVisible = false;
  }
}

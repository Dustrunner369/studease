import { Component } from '@angular/core';
import { FormsModule, NgForm } from '@angular/forms';
import { StudySpotService } from '../../services/study-spot.service';

@Component({ 
  selector: 'app-spot-card',
  imports: [FormsModule],
  templateUrl: './spot-card.component.html',
  styleUrl: './spot-card.component.css'
})
export class SpotCardComponent {
  
  constructor(private studySpotService: StudySpotService) {}

  onSubmit(f: NgForm) {    
    console.log(f.value);  
    
    const formData = {
      ...f.value,
      openUntil: new Date(f.value.openUntil).toISOString(), // Convert to ISO 8601
    };

    this.studySpotService.createStudySpot(formData).subscribe({
      next: (result) => {
        console.log('Success:', result);
      },
      error: (error) => {
        console.log('There was a failure creating a study spot.', error);
      }      
    });
  }
}

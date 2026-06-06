import { Component, EventEmitter, Output } from '@angular/core';
import { FormsModule, NgForm } from '@angular/forms';
import { StudySpotService } from '../../services/study-spot.service';
import { NgIcon } from '@ng-icons/core';

@Component({
  selector: 'app-create-spot-form',
  imports: [FormsModule, NgIcon],
  templateUrl: './create-spot-form.component.html',
  styleUrl: './create-spot-form.component.css'
})
export class CreateSpotFormComponent {
  @Output() close = new EventEmitter<void>();

  constructor(private studySpotService: StudySpotService) {}

  onSubmit(f: NgForm) {
    this.studySpotService.createStudySpot(f.value).subscribe({
      next: (result) => {
        console.log('Success:', result);
        this.closeModal();
      },
      error: (error) => {
        console.log('There was a failure creating a study spot.', error);
      }
    });
  }

  closeModal(): void {
    this.close.emit();
  }
}

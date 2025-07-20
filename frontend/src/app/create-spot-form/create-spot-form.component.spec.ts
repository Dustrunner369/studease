import { ComponentFixture, TestBed } from '@angular/core/testing';

import { CreateSpotFormComponent } from './create-spot-form.component';

describe('CreateSpotFormComponent', () => {
  let component: CreateSpotFormComponent;
  let fixture: ComponentFixture<CreateSpotFormComponent>;

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [CreateSpotFormComponent]
    })
    .compileComponents();

    fixture = TestBed.createComponent(CreateSpotFormComponent);
    component = fixture.componentInstance;
    fixture.detectChanges();
  });

  it('should create', () => {
    expect(component).toBeTruthy();
  });
});
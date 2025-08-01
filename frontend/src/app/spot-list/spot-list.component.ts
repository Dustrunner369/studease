import { Component, OnInit } from '@angular/core';
import { StudySpotService, StudySpot } from '../../services/study-spot.service';

@Component({
  selector: 'app-spot-list',
  imports: [],
  templateUrl: './spot-list.component.html',
  styleUrl: './spot-list.component.css'
})
export class SpotListComponent implements OnInit {
  studySpots: StudySpot[] = [
  {
    id: 1,
    name: "Brew & Books",
    address: "123 Library Lane, Booktown",
    hasCharging: true,
    seating: 25,
    coffeeQuality: 8,
    generalPrice: "$$",
    openUntil: new Date("2025-07-19T22:00:00"),
    drinkOrder: "Vanilla latte",
    extraNotes: "Quiet back room with good lighting."
  },
  {
    id: 2,
    name: "Caffeine Corner",
    address: "456 Java Street, Beanville",
    hasCharging: false,
    seating: 15,
    coffeeQuality: 7,
    generalPrice: "$",
    openUntil: new Date("2025-07-19T20:00:00"),
    drinkOrder: "Iced americano"
  },
  {
    id: 3,
    name: "Study Grounds",
    address: "789 Focus Blvd, Studytown",
    hasCharging: true,
    seating: 40,
    coffeeQuality: 9,
    generalPrice: "$$$",
    openUntil: new Date("2025-07-19T23:00:00"),
    drinkOrder: "Flat white",
    extraNotes: "Fast WiFi and great ambient music."
  },
  {
    id: 4,
    name: "The Thinking Cup",
    address: "321 Idea Ave, Brain City",
    hasCharging: true,
    seating: 30,
    coffeeQuality: 6,
    generalPrice: "$$",
    openUntil: new Date("2025-07-19T21:30:00"),
    drinkOrder: "Chai latte"
  },
  {
    id: 5,
    name: "Notes & Nibbles",
    address: "654 Memoir Rd, Notetown",
    hasCharging: false,
    seating: 20,
    coffeeQuality: 7,
    generalPrice: "$$",
    openUntil: new Date("2025-07-19T19:00:00"),
    drinkOrder: "Cappuccino",
    extraNotes: "Limited outlets, but cozy atmosphere."
  }
];

  
  constructor(private studySpotService: StudySpotService) {}

  // This function is called when the component is loaded into the DOM
  ngOnInit(): void {
    //   this.studySpotService.getStudySpots().subscribe(data => {
    //   console.log("Fetching study spots... in new component");
    //   this.studySpots = data;
    //   console.log(data);      
    // });
  }
  changeSelectedSpot(event: MouseEvent): void {
    console.log(event);
  }
}

import { Component } from '@angular/core';
import { FormsModule, NgForm } from '@angular/forms';
import { lucideMapPin } from '@ng-icons/lucide';
import { StudySpot } from '../../services/study-spot.service';
import { NgIcon } from "@ng-icons/core";

@Component({ 
  selector: 'app-spot-card',
  imports: [FormsModule, NgIcon],
  templateUrl: './spot-card.component.html',
  styleUrl: './spot-card.component.css'
})
export class SpotCardComponent {
  selectedSpot: StudySpot = 
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
    };
  // Format the closing time to display only the hour
  formatTime = (date: Date) => {
    return date.toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" });
  }
  formatCoffeeQualiy = (quality: number) => {
    return
  };
}

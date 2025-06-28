import { Component } from '@angular/core';
import { RouterOutlet } from '@angular/router';

@Component({
  selector: 'card-component',   
  imports: [RouterOutlet],
  templateUrl: './s-card.component.html',  
  styleUrl: '../styles.css'
})    
export class CardComponent { 
    handleEvent() {
        console.log("Button has been clicked");
    };
}
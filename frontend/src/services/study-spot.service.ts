import { HttpClient } from "@angular/common/http";
import { Injectable } from "@angular/core";
import { Observable } from "rxjs";

export interface StudySpot {
    id?: number; // Id is nullable because when we are creating a study spot in the frontend, we don't yet know what the Id will be.
    name: string; // Displayed in form
    address: string; // Displayed in form
    hasCharging: boolean; // Displayed in form
    seating: number; // Displayed in form
    coffeeQuality: number; // Displayed in form
    generalPrice: string; // Displayed in form
    openUntil: Date; // Displayed in form
    drinkOrder: string;
    extraNotes?: string;
}


@Injectable({
    providedIn: "root"
})
export class StudySpotService {
    private baseUrl = "http://localhost:5001/studyspots";

    constructor(private http: HttpClient) {}

    // Basic GET request which return all study spots
    getStudySpots(): Observable<StudySpot[]> {
        return this.http.get<StudySpot[]>(this.baseUrl);
    }

    // Basic POST request which creates a new study spot
    createStudySpot(spot: StudySpot): Observable<StudySpot> {
        return this.http.post<StudySpot>(this.baseUrl, spot);
    }

    // Fetch study spot by Id
    getStudySpot(id: number): Observable<StudySpot> {
        return this.http.get<StudySpot>(`${this.baseUrl}/${id}`);
    }

    // TEMP
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

    selectedSpot: StudySpot | null = this.studySpots[0]; 

    get selectedStudySpot() {
        return this.selectedSpot;
    }
    set selectedStudySpot(spot: StudySpot | null) {
        this.selectedSpot = spot;
    }

    get tempStudySpotList() {
        return this.studySpots;
    }
}
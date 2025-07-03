import { HttpClient } from "@angular/common/http";
import { Injectable } from "@angular/core";
import { Observable } from "rxjs";

export interface StudySpot {
    id?: number; // Id is nullable because when we are creating a study spot in the frontend, we don't yet know what the Id will be.
    name: string;
    address: string;
    hasCharging: boolean;
    seating: number;
    coffeeQuality: number;
    generalPrice: string;
    openUntil: Date;
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
}
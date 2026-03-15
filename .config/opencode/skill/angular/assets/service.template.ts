import { Injectable } from '@angular/core';
import { HttpClient, HttpHeaders, HttpParams } from '@angular/common/http';
import { Observable, throwError } from 'rxjs';
import { catchError, map, retry } from 'rxjs/operators';

@Injectable({
  providedIn: 'root'  // Singleton service
})
export class DataService {
  private apiUrl = 'https://api.example.com';
  
  constructor(private http: HttpClient) { }
  
  getItems(): Observable<any[]> {
    return this.http.get<any[]>(`${this.apiUrl}/items`).pipe(
      retry(3),
      catchError(this.handleError)
    );
  }
  
  getItemById(id: string): Observable<any> {
    return this.http.get<any>(`${this.apiUrl}/items/${id}`).pipe(
      catchError(this.handleError)
    );
  }
  
  createItem(item: any): Observable<any> {
    const headers = new HttpHeaders({ 'Content-Type': 'application/json' });
    return this.http.post<any>(`${this.apiUrl}/items`, item, { headers }).pipe(
      catchError(this.handleError)
    );
  }
  
  updateItem(id: string, item: any): Observable<any> {
    return this.http.put<any>(`${this.apiUrl}/items/${id}`, item).pipe(
      catchError(this.handleError)
    );
  }
  
  deleteItem(id: string): Observable<void> {
    return this.http.delete<void>(`${this.apiUrl}/items/${id}`).pipe(
      catchError(this.handleError)
    );
  }
  
  private handleError(error: any): Observable<never> {
    console.error('An error occurred:', error);
    return throwError(() => new Error('Something went wrong; please try again later.'));
  }
}

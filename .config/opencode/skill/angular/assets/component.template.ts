import { Component, OnInit, Input, Output, EventEmitter } from '@angular/core';

@Component({
  selector: 'app-example',
  templateUrl: './example.component.html',
  styleUrls: ['./example.component.css']
})
export class ExampleComponent implements OnInit {
  // Input properties
  @Input() data: any;
  
  // Output events
  @Output() actionPerformed = new EventEmitter<any>();
  
  // Component state
  isLoading = false;
  items: any[] = [];
  
  constructor(
    // Inject services here
  ) { }
  
  ngOnInit(): void {
    // Initialization logic
    this.loadData();
  }
  
  loadData(): void {
    this.isLoading = true;
    // Load data logic
  }
  
  onAction(data: any): void {
    this.actionPerformed.emit(data);
  }
}

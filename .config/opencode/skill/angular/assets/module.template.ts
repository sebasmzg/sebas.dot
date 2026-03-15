import { NgModule } from '@angular/core';
import { CommonModule } from '@angular/common';
import { ReactiveFormsModule } from '@angular/forms';

// Routing
import { FeatureRoutingModule } from './feature-routing.module';

// Components
import { FeatureComponent } from './feature.component';
import { FeatureListComponent } from './feature-list/feature-list.component';
import { FeatureDetailComponent } from './feature-detail/feature-detail.component';

// Services
import { FeatureService } from './services/feature.service';

@NgModule({
  declarations: [
    FeatureComponent,
    FeatureListComponent,
    FeatureDetailComponent
  ],
  imports: [
    CommonModule,
    ReactiveFormsModule,
    FeatureRoutingModule
  ],
  providers: [
    FeatureService
  ],
  exports: [
    // Export components that other modules need
    FeatureComponent
  ]
})
export class FeatureModule { }

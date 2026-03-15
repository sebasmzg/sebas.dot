---
name: angular
description: >
  Angular NgModule patterns for non-standalone components.
  Trigger: When working with Angular components, modules, services - NgModule architecture, declarations, providers.
license: Apache-2.0
metadata:
  author: gentleman-programming
  version: "1.0"
---

## When to Use

- Building Angular applications with NgModule architecture (non-standalone)
- Creating components that need to be declared in modules
- Organizing services, pipes, and directives within modules
- Managing dependency injection with providers at module level
- Implementing lazy-loaded feature modules

## Critical Patterns

### Component Declaration

**ALWAYS declare components in NgModule:**

```typescript
// feature.module.ts
import { NgModule } from '@angular/core';
import { CommonModule } from '@angular/common';
import { MyComponent } from './my.component';

@NgModule({
  declarations: [MyComponent],  // Components, directives, pipes
  imports: [CommonModule],      // Other modules
  exports: [MyComponent]        // What other modules can use
})
export class FeatureModule { }
```

**Component structure:**

```typescript
// my.component.ts
import { Component, OnInit } from '@angular/core';

@Component({
  selector: 'app-my-component',
  templateUrl: './my.component.html',
  styleUrls: ['./my.component.css']
})
export class MyComponent implements OnInit {
  constructor() { }
  
  ngOnInit(): void {
    // Initialization logic
  }
}
```

### Service Injection

**Singleton services - providedIn root:**

```typescript
import { Injectable } from '@angular/core';

@Injectable({
  providedIn: 'root'  // Single instance app-wide
})
export class DataService {
  constructor() { }
}
```

**Module-level services:**

```typescript
// feature.module.ts
@NgModule({
  declarations: [MyComponent],
  providers: [FeatureService]  // Instance per module
})
export class FeatureModule { }
```

### Module Organization

| Module Type | Purpose | Example |
|-------------|---------|---------|
| **Root Module** | Bootstrap app | `AppModule` with `BrowserModule` |
| **Feature Module** | Group related features | `UserModule`, `ProductModule` |
| **Shared Module** | Reusable components | `SharedModule` with common pipes/directives |
| **Core Module** | Singleton services | `CoreModule` with auth, logging |

### Lazy Loading

```typescript
// app-routing.module.ts
const routes: Routes = [
  {
    path: 'feature',
    loadChildren: () => import('./feature/feature.module')
      .then(m => m.FeatureModule)
  }
];

@NgModule({
  imports: [RouterModule.forRoot(routes)],
  exports: [RouterModule]
})
export class AppRoutingModule { }
```

### Common Imports

| Import | When to Use |
|--------|-------------|
| `BrowserModule` | ONLY in `AppModule` (root) |
| `CommonModule` | In ALL feature modules |
| `FormsModule` | Template-driven forms |
| `ReactiveFormsModule` | Reactive forms |
| `HttpClientModule` | HTTP requests (usually in `AppModule`) |
| `RouterModule` | Routing (forRoot in app, forChild in features) |

## Code Examples

### Complete Feature Module

```typescript
// user/user.module.ts
import { NgModule } from '@angular/core';
import { CommonModule } from '@angular/common';
import { ReactiveFormsModule } from '@angular/forms';
import { UserRoutingModule } from './user-routing.module';

import { UserListComponent } from './user-list/user-list.component';
import { UserDetailComponent } from './user-detail/user-detail.component';
import { UserService } from './user.service';

@NgModule({
  declarations: [
    UserListComponent,
    UserDetailComponent
  ],
  imports: [
    CommonModule,
    ReactiveFormsModule,
    UserRoutingModule
  ],
  providers: [UserService]
})
export class UserModule { }
```

### Shared Module Pattern

```typescript
// shared/shared.module.ts
import { NgModule } from '@angular/core';
import { CommonModule } from '@angular/common';

import { HighlightDirective } from './directives/highlight.directive';
import { TruncatePipe } from './pipes/truncate.pipe';
import { LoadingComponent } from './components/loading/loading.component';

@NgModule({
  declarations: [
    HighlightDirective,
    TruncatePipe,
    LoadingComponent
  ],
  imports: [CommonModule],
  exports: [
    CommonModule,           // Re-export for convenience
    HighlightDirective,
    TruncatePipe,
    LoadingComponent
  ]
})
export class SharedModule { }
```

### Core Module with Guards

```typescript
// core/core.module.ts
import { NgModule, Optional, SkipSelf } from '@angular/core';
import { CommonModule } from '@angular/common';
import { HTTP_INTERCEPTORS, HttpClientModule } from '@angular/common/http';

import { AuthService } from './services/auth.service';
import { AuthInterceptor } from './interceptors/auth.interceptor';

@NgModule({
  imports: [CommonModule, HttpClientModule],
  providers: [
    AuthService,
    {
      provide: HTTP_INTERCEPTORS,
      useClass: AuthInterceptor,
      multi: true
    }
  ]
})
export class CoreModule {
  // Prevent multiple imports
  constructor(@Optional() @SkipSelf() parentModule: CoreModule) {
    if (parentModule) {
      throw new Error('CoreModule is already loaded. Import only in AppModule');
    }
  }
}
```

## Commands

```bash
# Generate component in module
ng generate component feature/my-component

# Generate module with routing
ng generate module feature --routing

# Generate service
ng generate service feature/feature

# Generate directive
ng generate directive shared/highlight

# Generate pipe
ng generate pipe shared/truncate

# Generate guard
ng generate guard core/auth

# Build production
ng build --configuration production

# Run tests
ng test

# Run e2e tests
ng e2e
```

## Key Rules

1. **BrowserModule ONLY in AppModule** - Use `CommonModule` everywhere else
2. **Declare once** - Component/Directive/Pipe in ONE module only
3. **Export what you share** - Only export what other modules need
4. **CoreModule pattern** - Import once in AppModule, throw error if re-imported
5. **SharedModule pattern** - Import in every feature that needs it
6. **Services in root** - Use `providedIn: 'root'` unless you need module-level instances
7. **Lazy load features** - Use `loadChildren` for better performance

## Decision Tree

```
Need to share across features?
  ├─ Component/Directive/Pipe → SharedModule
  └─ Service → providedIn: 'root'

New feature area?
  → Create FeatureModule with routing

Singleton service?
  ├─ Used app-wide → providedIn: 'root'
  └─ Feature-specific → providers in FeatureModule

HTTP/Router/Forms?
  ├─ HttpClientModule → AppModule
  ├─ RouterModule.forRoot() → AppRoutingModule
  ├─ RouterModule.forChild() → FeatureRoutingModule
  └─ FormsModule/ReactiveFormsModule → Where needed
```

## Resources

- **Templates**: See [assets/](assets/) for component and module templates

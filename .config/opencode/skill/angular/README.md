# Angular Skill

Angular NgModule patterns for non-standalone components.

## Description

This skill provides guidance for building Angular applications using the traditional NgModule architecture (non-standalone components). It covers component declarations, module organization, service injection, and lazy loading patterns.

## When to Use

- Building Angular applications with NgModule architecture
- Creating components that need to be declared in modules
- Organizing services, pipes, and directives within modules
- Managing dependency injection with providers at module level
- Implementing lazy-loaded feature modules

## Trigger Keywords

The skill is automatically loaded when working with:
- Angular components
- Angular modules
- Angular services
- NgModule architecture
- declarations
- providers

## Assets

The `assets/` directory contains templates for:

- **component.template.ts**: Template for creating Angular components with best practices
- **module.template.ts**: Template for feature modules with routing
- **service.template.ts**: Template for services with HTTP client integration

## Quick Reference

### Generate Commands

```bash
ng generate component feature/my-component
ng generate module feature --routing
ng generate service feature/feature
ng generate directive shared/highlight
ng generate pipe shared/truncate
ng generate guard core/auth
```

### Module Types

- **Root Module** (AppModule): Bootstrap the app
- **Feature Module**: Group related features
- **Shared Module**: Reusable components/pipes/directives
- **Core Module**: Singleton services (auth, logging, etc.)

### Key Rules

1. `BrowserModule` ONLY in AppModule - Use `CommonModule` everywhere else
2. Declare components/directives/pipes in ONE module only
3. Export what other modules need to use
4. Use `providedIn: 'root'` for singleton services
5. Lazy load feature modules for better performance

## Version

1.0

## Author

gentleman-programming

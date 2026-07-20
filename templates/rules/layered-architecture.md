---
description: Layered architecture — dependency direction and per-layer responsibilities for controllers, services, repos, views
paths:
  - "src/**"
---

# Layered architecture

Four layers. Dependencies point one way: **controllers → services → repos**; controllers use **views** to shape output. A layer never imports one above it.

- **controllers/** — entry points (HTTP routes, CLI, queue/event handlers). Parse and validate input, call exactly one service, map the result through a view. No business logic, no direct data access.
- **services/** — business logic and orchestration. Transport- and storage-agnostic. Depend on repos through their interfaces; never import controllers or views.
- **repos/** — data access (DB, external APIs, files). Return domain types. No business logic; never import services.
- **views/** — output shaping (DTOs, serializers, templates, UI components). Pure functions of their input; no business logic, no data access.

Rules:
- Shared types/entities live in `domain/` (or equivalent), imported by any layer.
- Compose across services inside the service layer, not the controller.
- Keep each file to one layer.

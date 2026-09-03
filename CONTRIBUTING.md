# Contributing to Nudgy

Thank you for your interest in contributing to Nudgy! This guide will help you get started.

## Getting Started

1. Fork the repository
2. Clone your fork:
   ```bash
   git clone https://github.com/YOUR_USERNAME/nudge.git
   cd nudge
   ```
3. Build and run the tests to make sure everything works:
   ```bash
   make test
   ```

## Development Setup

- **macOS 14.0+** (Sonoma or later)
- **Swift 5.9+** (included with Xcode 15+)
- No external dependencies required

Build the project:

```bash
make debug    # Debug build
make run      # Build and run
```

## Making Changes

1. Create a branch for your change:
   ```bash
   git checkout -b your-feature-name
   ```
2. Make your changes
3. Run the tests:
   ```bash
   make test
   ```
4. Commit your changes with a clear commit message
5. Push to your fork and open a pull request

## Pull Request Guidelines

- Keep PRs focused — one feature or fix per PR
- Include tests for new functionality
- Make sure all existing tests pass
- Update documentation if your change affects user-facing behavior
- Write a clear PR description explaining what and why

Merged PRs are automatically collected into the next draft release. See
[Releasing Nudgy](RELEASING.md) for version labels, publishing, and reusing the
draft-release setup in another repository.

## Code Style

- Follow existing code conventions in the project
- Use Swift's standard naming conventions (camelCase for functions/variables, PascalCase for types)
- Keep functions focused and reasonably short
- Use Swift concurrency (async/await, actors) for concurrent code

## Project Structure

```
Sources/Nudge/
├── App/          # Application lifecycle
├── Models/       # Data models and state
├── Server/       # HTTP server
├── Services/     # Business logic (sessions, suppression, sounds, etc.)
├── UI/           # SwiftUI views and window controllers
└── Resources/    # Assets and sounds

Tests/NudgeTests/ # All tests
```

## Reporting Bugs

Open an issue with:
- macOS version
- Steps to reproduce
- Expected vs actual behavior
- Any relevant logs or screenshots

## Feature Requests

Open an issue describing:
- The problem you're trying to solve
- Your proposed solution
- Any alternatives you've considered

## Questions?

Open a discussion or issue — happy to help.

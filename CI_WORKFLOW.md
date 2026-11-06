# CI/CD Workflow Documentation

## Overview

Release versioning and store-release policy are documented in [RELEASING.md](RELEASING.md).

This project includes a comprehensive CI/CD workflow that automatically runs tests whenever code is pushed to GitHub. The workflow is configured in `.github/workflows/ci.yml` and provides automated testing, code analysis, and build verification.

## Workflow Triggers

The CI workflow runs automatically on:
- **Push** to `main`, `master`, or `develop` branches
- **Pull requests** to `main`, `master`, or `develop` branches
- **Manual dispatch** (can be triggered manually from GitHub Actions tab)

> **Keep in sync**: this document mirrors `.github/workflows/ci.yml` and `android_release.yml`. Any `flutter-version` or `java-version` bump in the workflow must update this doc in the same commit.

## Workflow Jobs

### 1. Test Job (`test`)
This is the primary job that runs all Flutter unit tests and performs code quality checks:

**Steps:**
- ✅ Checkout repository
- ✅ Setup Java 17 (Oracle distribution)
- ✅ Setup Flutter 3.38.x (stable channel)
- ✅ Cache Flutter dependencies for faster builds
- ✅ Create environment file (`.env`) with test configuration
- ✅ Install Flutter dependencies
- ✅ Verify Flutter installation
- ✅ Analyze code with `flutter analyze --fatal-infos --fatal-warnings` *(non-blocking: `continue-on-error: true`)*
- ✅ Check code formatting with `dart format --set-exit-if-changed` *(non-blocking: `continue-on-error: true`)*
- ✅ Run tests with coverage using `flutter test --coverage --reporter expanded`
- ✅ Upload test results and coverage reports as artifacts

### 2. Build Test Job (`build-test`)
Verifies that the application builds correctly for Android:

**Steps:**
- ✅ Build Android APK (debug)
- ✅ Build Android App Bundle (debug)
- ✅ Runs only after tests pass successfully

### 3. Integration Test Job (`integration-test`)
Runs integration tests (if present):

**Conditions:**
- Only runs on pull requests or pushes to main/master branches
- Checks for `integration_test` directory and runs tests if found
- Skips gracefully if no integration tests exist

### 4. Summary Job (`summary`)
Provides a consolidated summary of all test results:

**Features:**
- ✅ Shows overall status of unit tests and build tests
- ✅ Displays success/failure status in GitHub Actions summary
- ✅ Runs regardless of previous job outcomes

## Features

### Code Quality Checks
- **Static Analysis**: Uses `flutter analyze` with strict settings
- **Code Formatting**: Enforces consistent code formatting with `dart format`
- **Test Coverage**: Generates coverage reports for all tests

### Performance Optimizations
- **Dependency Caching**: Caches Flutter pub dependencies to reduce build times
- **Parallel Jobs**: Runs build tests in parallel with integration tests
- **Conditional Execution**: Integration tests only run when necessary

### Artifacts and Reporting
- **Test Results**: Uploaded as artifacts when tests fail (30-day retention)
- **Coverage Reports**: Generated and uploaded for every run (30-day retention)
- **Summary Reports**: Visible in GitHub Actions summary page

## Environment Configuration

The workflow automatically handles environment configuration:

1. **Tries to copy `.env.example` to `.env`**
2. **Creates a basic `.env` file if example doesn't exist**
3. **Uses test-appropriate configuration values**

Required environment variables for testing:
```bash
# Test environment
API_BASE_URL=https://api.test.example.com
SEQ_API_KEY=test-key
```

## Coverage Reports

The workflow generates comprehensive test coverage reports:
- **LCOV format**: `coverage/lcov.info`
- **HTML reports**: Available in `coverage/` directory
- **Artifacts**: Uploaded to GitHub Actions for download

## Failure Handling

### When Tests Fail
- ✅ Detailed test output is shown in the job logs
- ✅ Test files are uploaded as artifacts for investigation
- ✅ Build and integration tests are skipped to save resources
- ✅ Summary job still runs to provide consolidated status

### When Code Quality Checks Run With Issues
Note: `flutter analyze` and `dart format` run with `continue-on-error: true` — they report findings but do **not** fail the CI job.
- ✅ **Analysis warnings**: Shown in logs and the GitHub step summary
- ✅ **Formatting issues**: Listed in logs; run `dart format --page-width=120 .` locally to fix
- ✅ **Build failures**: Full build logs available for debugging

## Local Testing

To run the same checks locally before pushing:

```bash
# Run all tests with coverage
flutter test --coverage --reporter expanded

# Run code analysis
flutter analyze --fatal-infos --fatal-warnings

# Check code formatting (120 column width)
dart format --set-exit-if-changed --page-width=120 .

# Build for Android
flutter build apk --debug
flutter build appbundle --debug
```

## Monitoring and Maintenance

### GitHub Actions Dashboard
- View workflow runs in the **Actions** tab of your repository
- Monitor success/failure rates over time
- Download artifacts (test results, coverage reports)

### Workflow Updates
The workflow file is located at `.github/workflows/ci.yml`. Key maintenance tasks:

- **Flutter Version Updates**: Update `flutter-version` in the workflow
- **Java Version Updates**: Modify `java-version` if needed
- **New Test Types**: Add additional jobs for different test categories
- **Environment Variables**: Update environment file creation logic

## Troubleshooting

### Common Issues

1. **Tests fail locally but pass on CI** (or vice versa):
   - Check environment file differences
   - Verify Flutter and Dart versions match
   - Ensure all dependencies are properly declared

2. **Build failures**:
   - Check Java version compatibility
   - Verify Android configuration
   - Review dependency versions

3. **Coverage issues**:
   - Ensure test files have proper imports
   - Check that all source files are being tested
   - Verify coverage path configuration

### Getting Help

- Check the **Actions** tab for detailed logs
- Review failed job steps for specific error messages
- Compare successful runs with failed ones to identify changes
- Use `flutter doctor -v` locally to verify your environment matches CI

## Benefits

This CI/CD setup provides:

✅ **Automated Quality Assurance**: Catches issues before they reach production  
✅ **Consistent Environment**: Same Flutter/Java versions across all builds  
✅ **Fast Feedback**: Developers get immediate notification of test failures  
✅ **Code Coverage Tracking**: Monitor test coverage trends over time  
✅ **Build Verification**: Ensures app builds successfully on every change  
✅ **Professional Development**: Industry-standard CI/CD practices

<div align="center">
	<h1>Async Processor</h1>
	<p>Performant job selection and execution utilities for Apex with governor limit safety.</p>
</div>

This project provides simple, maintainable building blocks to select eligible jobs and execute them asynchronously while staying within governor limits. It uses a clean architecture with a simple DTO for limits and a service for limit computations.

<!-- TABLE OF CONTENTS -->
<details>
  <summary>Table of Contents</summary>

- [Principles](#principles)
  - [Why you should use this library](#why-you-should-use-this-library)
- [Installation](#installation)
- [Usage](#usage)
  - [Selecting eligible jobs](#selecting-eligible-jobs)
  - [Computing available limits](#computing-available-limits)
  - [Executing as Queueable](#executing-as-queueable)
- [Library architecture](#library-architecture)
- [How to migrate my codebase?](#how-to-migrate-my-codebase)
- [Authors](#authors)
- [Contributing](#contributing)
- [License](#license)
</details>

## Principles

The library aims to be:

- Simple to read and extend
- Safe regarding governor limits
- Testable via dependency injection and Apex Mockery

### Why you should use this library

- Database-level filtering of job candidates against available limits with configurable buffer
- Accurate timing by computing limits as late as possible
- Clear separation between data (`LimitsUsage`) and logic (`LimitServiceImpl`)

## Installation

Requirements: `Node.js 18+`, `npm 9+`, `Salesforce CLI`.

```bash
npm install
sf org create scratch -f config/project-scratch-def.json -a dev -d 1
npm run build
```

## Usage

The library provides two main components: Job Descriptions (templates for job types) and Job Requests (individual job instances). Here's how to use them:

### Scheduling the job processor

Start the async job processor to begin executing queued jobs:

```apex
ApexJobWatcher.schedule();
```

### Job Description Management

Job Descriptions define the template and configuration for a specific type of job, including governor limit consumption patterns and execution constraints.

#### Creating and configuring job descriptions

```apex
// Create a new job description
ApexJobManager.defineJobDescription()
    .withName('DataCleanupJob')
    .withProcessorName('DataCleanupExecutor')
    .withMaxChunkSize(100)
    .withAllowedStartTime(Time.newInstance(9, 0, 0, 0))
    .withAllowedEndTime(Time.newInstance(17, 0, 0, 0))
    .build();
```

#### Managing job description state

```apex
// Enable a job description
JobDescriptionService.enable(jobDescriptionId);

// Disable a job description (prevents new executions)
JobDescriptionService.disable(jobDescriptionId);

// Reset governor limit learning data
JobDescriptionService.resetConsumptionModel(jobDescriptionId);
```

### Job Request Management

Job Requests represent individual job instances that will be executed by the processor.

#### Creating job requests

```apex
// Create a new job request
ApexJobManager.createJobRequest()
    .withName('Cleanup-2024-01')
    .withJobDescription(jobDescriptionId)
    .withArgument('{"startDate": "2024-01-01", "endDate": "2024-01-31"}')
    .withNextExecutionDateTime(Datetime.now())
    .build();
```

#### Managing job request state

```apex
// Enable a job request for execution
JobRequestService.enable(jobRequestId);

// Disable a job request (pauses execution)
JobRequestService.disable(jobRequestId);
```

## Authors

- scolladon and contributors

## Contributing

See `CONTRIBUTING.md` for setup, coding standards, and testing guidance.

## License

MIT — see `LICENSE`.

# Idea2Strategy

Idea2Strategy lets users build trading strategies with visual blocks, test them on historical data and run them against live prices with virtual funds. Kyoungcheul Min led the six-person team, designed the initial PostgreSQL schema and service architecture, and contributed to the Java backend.

The web API needs to stay online around the clock. Paper trading follows a US market schedule, while backtests only need compute when a user requests one. We split these workloads so the web API could run on a smaller instance. In our project estimate, the savings from running compute-intensive workers only when needed outweighed the extra messaging costs. [AWS architecture](docs/infrastructure/architecture.md) · [Development cost model](infra/terraform/COST-ESTIMATE.md)

[Korean README, screenshots and diagrams](README.md)

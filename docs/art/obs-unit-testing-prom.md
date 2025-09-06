---
title: "Observability Unit Testing 1/4"
description: "observability data is also an API that should be tested."
---

# Observability Exporter Unit Testing 1/4: Prometheus

This is the first installment in a series of posts about unit testing
observability data from exporters, such as metrics, logs, and traces, in certain
situations.

In case you happen to _develop_ [Prometheus
exporters](https://prometheus.io/docs/introduction/glossary/#exporter) or
OpenTelemetry exporters/[instrumentation
libraries](https://opentelemetry.io/docs/concepts/glossary/#instrumentation-library)
then the observability signals you emit are forming an API on top of a
particular observability API/protocol: the consumers, such as dashboards and
monitoring systems, of your provided observability data are in a contract with
your exporter, because they rely on certain signal names and attributes, as well
as specific signal semantics.

In this post, we'll focus on Prometheus and its metrics model only; further
installments will then over time address testing different signal types of
OpenTelemetry, namely, metrics, logs, and traces (not necessarily in this
order).

## Prometheus `testutil` and `promlint`

Writing specific exporters for metrics where there is unfortunately no
readily-made exporter already available typically has a "custom collector"
somewhere at its exporter heart. That is, _something_ satisfying the SDK's
[`prometheus.Collector`
interface](https://pkg.go.dev/github.com/prometheus/client_golang@v1.23.2/prometheus#Collector).

The Prometheus client Go SDK thankfully provides a [`testutil`
package](https://pkg.go.dev/github.com/prometheus/client_golang/prometheus/testutil)
that...

> [!QUOTE] [...] provides helpers to test code using the prometheus package of
> client_golang. [...] The most appropriate use is [...] testing custom
> prometheus.Collector implementations.

(Please keep in mind that any distorting omissions in the above quote are on us.)

There's an accompanying [`promlint`
package](https://pkg.go.dev/github.com/prometheus/client_golang@v1.23.2/prometheus/testutil/promlint)
that lints metrics such as produced[^otel] by a custom collector. In what is
probably the simplest form, metrics can be collected into a "pedantic" (metrics)
registry and then linted using just
[`testutil.CollectAndLint`](https://pkg.go.dev/github.com/prometheus/client_golang/prometheus/testutil#CollectAndLint),
returning errors as well any linting problems found.

## Asserting Metrics

Unfortunately, this still leaves us with the puzzle of unit testing the metrics
data itself, from the perspective of an exporter data contract. The most
bare-bones way probably is to simply assert what your collector sends down its
passed metrics channel when told to "collect its metrics". Since we're linting
anyway, [pick up a more refined metrics
representation](https://pkg.go.dev/github.com/prometheus/client_golang@v1.23.2/prometheus#Gatherer)
from the "pedantic" registry that we need anyway.

The important point now is that the Prometheus SDK actually organizes our
metrics (data) into ["_metric
families_"](https://pkg.go.dev/github.com/prometheus/client_model/go#MetricFamily):
all metrics of the same family share their...

- name,
- type,
- unit,
- help.

Inside the family are the (individual) metrics with:

- labels,
- "value" and timestamp (note that "value" can be quite a convoluted thing
  especially when it comes to histograms).

---

[^otel]: ...sneaking in some OpenTelemetry terminology here.

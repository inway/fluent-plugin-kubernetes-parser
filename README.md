# fluent-plugin-kubernetes-parser

[Fluentd](https://fluentd.org/) parser plugin to parse some Kubernetes and containerd specific log file formats.

## Installation

### Fluent

```
$ fluent-gem install fluent-plugin-kubernetes-parser
```

### RubyGems

```
$ gem install fluent-plugin-kubernetes-parser
```

### Bundler

Add following line to your Gemfile:

```ruby
gem "fluent-plugin-kubernetes-parser"
```

And then execute:

```
$ bundle
```

## Configuration

- See also: [TimeParameters Plugin Overview](https://docs.fluentd.org/v/1.0/timeparameters#overview)

- See also: [Parser Plugin Overview](https://docs.fluentd.org/v/1.0/parser#overview)

## Fluent::Plugin::KubernetesParser

### delimiter (string) (optional)

Default value: ` `.

### default_tz (string) (optional)

Default value: `+00:00`.

### force_year (string) (optional)

### keep_time_key (bool) (optional)

### time_format (string) (optional)

### time_key (string) (optional)

Default value: `time`.

## Copyright

- Copyright(c) 2022- Sebastian Podjasek
- License
  - Apache License, Version 2.0

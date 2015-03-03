# Enscalator

Enscalator is based on [bazaarvoice/cloudformation-ruby-dsl](https://github.com/bazaarvoice/cloudformation-ruby-dsl) and helps cloudforming en-japan applications

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'enscalator'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install enscalator

## Usage

```ruby
require 'enscalator'

en_app(vpc: 'vpc-1234', start_ip_idx: 4,
    private_route_tables: {'a' => 'rtb-1234', 'c' => 'rtb-5678'},
    private_security_group: 'sg-1234') do

  # Whatever extra parameter/mappings/resources/output you need
  # cf https://github.com/bazaarvoice/cloudformation-ruby-dsl

end.exec!
```

```bash
$> ruby jobposting_service_elasticsearch_enscalator.rb create-stack --region us-west-1  --stack-name jobposting-elasticsearch --parameters 'KeyName=test;MyKey=MyValue'
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release` to create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

1. Fork it ( https://github.com/en-japan/enscalator/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

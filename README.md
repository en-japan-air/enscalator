# Enscalator

[![Build Status](https://magnum.travis-ci.com/en-japan/enscalator.svg?token=hzDTonLsrtFjB1EvbfNy&branch=master)](https://magnum.travis-ci.com/en-japan/enscalator)
[![Coverage Status](***REMOVED***c)](***REMOVED***)

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

### CLI

```bash
$> enscalator -h
Usage: enscalator [arguments]
  -l, --list-templates             List all available templates
  -t, --template=<s>               Template name
  -r, --region=<s>                 AWS Region (default: us-east-1)
  -p, --parameters=<s>             Parameters 'Key1=Value1;Key2=Value2'
  -s, --stack-name=<s>             Stack name
  -z, --hosted-zone=<s>            Hosted zone (e.x. 'enjapan.prod.')
  -c, --create-stack               Create the stack
  -u, --update-stack               Update already deployed stack
  -e, --pre-run, --no-pre-run      Use pre-run hooks (default: true)
  -o, --post-run, --no-post-run    Use post-run hooks (default: true)
  -x, --expand                     Print generated JSON template
  -a, --capabilities=<s>           AWS capabilities (default: CAPABILITY_IAM)
  -n, --vpc-stack-name=<s>         VPC stack name
  -h, --help                       Show this message
```

Example:
```bash
$> enscalator -t Interaction -r us-west-1 -s Interaction -c -p 'CouchbaseInteractionKeyName=test;WebServerPort=9000'
```

### How to write a template
Templates are stored in lib/enscalator/templates/.  
When your template is done you need to `require` it in lib/enscalator.rb.  
You'll find the list of helpers you can use in lib/richtemplate.rb and lib/enapp.rb.  
For each template you write you'll automatically get a ResourceSecurityGroup, an ApplicationSecurityGroup, a ResourceSubnetA/ResourceSubnetB, ApplicationSubnetA/ApplicationSubnetB, and a loadBalancer. Everything attached to a VPC, that was created using enjapan_vpc template.
That's why you always need to precise the start_ip_idx as a parameter of basic_setup, it's the starting ip address in the subnet.
Check [lib/enscalator/templates/jobposting.rb](lib/enscalator/templates/jobposting.rb) for an example.


### How to write a plugin and include it?
Plugins are modules and stored in `lib/enscalator/plugins/`.  
Right now you have a [couchbase plugin](lib/enscalator/plugins/couchbase.rb) available.  
When you want to use your plugin you just have to `include PluginName` inside your template. See `lib/enscalator/template/jobposting.rb` for an example.  
Don't forget to `require_relative` your new plugin in `lib/enscalator/plugins.rb`.

```bash
$> ruby jobposting_service_elasticsearch_enscalator.rb create-stack --region us-west-1 --stack-name jobposting-elasticsearch --parameters 'KeyName=test;WebServerPort=9000'
```

#### What's pre_run and post_run?
**pre_run** is a method called **BEFORE** the template generation. It's a good place to make some calls to the AWS SDK for instance.  
**post_run** is a method called **AFTER** the stack is created. It's a good place to create some DNS records in route53 for instance.

## Notes

There are number of plugins with pure magic:

* Ubuntu plugin in [lib/enscalator/plugins/ubuntu.rb](lib/enscalator/plugins/ubuntu.rb). It'll automatically get the AMIs ID from the ubuntu website.
* CoreOS plugin in [lib/enscalator/plugins/core_os.rb](lib/enscalator/plugins/core_os.rb). It would not only fetch AMI IDs, but also can do that from multiple release channels.

## Development

To install this gem onto your local machine, run `bundle && bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release` to create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Documentation

To generate documentation run `rake doc` ( or `bundle exec rake doc` )

## Contributing

1. Fork it ( https://github.com/en-japan/enscalator/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Check if tests failing (`rake spec` or `bundle exec rake spec`)
6. Create a new Pull Request
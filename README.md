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

### CLI
```bash
MAC0002-2140350% enscalator -h
Options:
  -l, --list-templates    List all available templates
  -t, --template=<s>      Template name
  -r, --region=<s>        AWS Region (default: us-east-1)
  -p, --parameters=<s>    Parameters 'Key1=Value1;Key2=Value2'
  -s, --stack-name=<s>    Stack name
  -c, --create-stack      Create the stack
  -e, --expand            Print template's JSON
  -h, --help              Show this message
```

Example:
```bash
$> enscalator -t Interaction -r us-west-1 -s Interaction -c -p 'CouchbaseInteractionKeyName=test;WebServerPort=9000'
```

### How to write a template
Templates are stored in lib/enscalator/templates/.  
When your template is done you need to `require` it in lib/enscalator.rb.  
You'll find the list of helpers you can use in lib/richtemplate.rb and lib/enapp.rb

### How to write a plugin and include it?
Plugins are stored in lib/enscalator/plugins/.  
Right now you have a couchbase plugin available.  
When you want to use your plugin you just have to `include PluginName` inside your template. See lib/enscalator/template/jobposting.rb for an example.  
Don't forget to `require` your new plugin in lib/enscalator.rb.


#### What's pre_run and post_run?
**pre_run** is a method called **BEFORE** the template generation. It's a good place to make some calls to the AWS SDK for instance.  
**post_run** is a method called **AFTER** the stack is created. It's a good place to create some DNS records in route53 for instance.

## Development

To install this gem onto your local machine, run `bundle && bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release` to create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

1. Fork it ( https://github.com/en-japan/enscalator/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request
